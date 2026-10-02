import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/config/game_config.dart';
import 'package:mochi/db/mochi_db.dart';
import 'package:mochi/db/mochi_repository.dart';
import 'package:mochi/games/mini_game.dart';
import 'package:mochi/models/member.dart';
import 'package:mochi/models/food.dart';
import 'package:mochi/models/pet.dart';

void main() {
  late MochiDb db;
  late MochiRepository repo;
  late Member profile;

  setUp(() {
    db = MochiDb.openInMemory();
    repo = MochiRepository(db);
    repo.createPet('Mochi');
    profile = repo.createProfile('Sam', '#1D9E75');
    db.db.execute('UPDATE pets SET stage = 2');
  });

  tearDown(() {
    db.db.close();
  });

  /// Backdates every recorded play so the 90s inter-play cooldown is clear.
  void clearCooldown() {
    db.db.execute('UPDATE mini_game_plays SET created_at = ?', <Object?>[
      DateTime.now().toUtc().subtract(Duration(minutes: 10)).toIso8601String(),
    ]);
  }

  test('records a scored run, awards XP, and updates best score', () {
    final MiniGameResult result = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.snackCatch,
      score: 100,
    );

    expect(result.outcome, MiniGameOutcome.rewarded);
    expect(result.xpAwarded, 6);
    expect(result.satietyAfter, isNotNull);
    expect(result.foodAwarded, isNotNull);
    expect(repo.foodInventory(memberId: profile.id)[result.foodAwarded!], 1);
    expect(repo.getPet()!.xp, 6);
    expect(
      repo.miniGameBestScores(memberId: profile.id)[MiniGame.snackCatch],
      100,
    );
    expect(repo.dailyMiniGamePlays(memberId: profile.id), 1);
  });

  test('treats only drop once Mochi can eat them', () {
    db.db.execute('UPDATE pets SET stage = 1');

    final MiniGameResult result = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.snackCatch,
      score: 100,
    );

    expect(result.outcome, MiniGameOutcome.rewarded);
    expect(result.foodAwarded, isNull);
    expect(
      repo
          .foodInventory(memberId: profile.id)
          .values
          .fold<int>(0, (int sum, int count) => sum + count),
      0,
    );
  });

  test('a second run hits the XP cooldown but still earns food', () {
    repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.ticklePop,
      score: 20,
      bestCombo: 4,
    );

    final MiniGameResult second = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.ticklePop,
      score: 40,
      bestCombo: 8,
    );

    expect(second.outcome, MiniGameOutcome.cooldown);
    expect(second.xpAwarded, 0);
    expect(second.foodAwarded, isNotNull);
    expect(
      repo.gameFoodRemaining(memberId: profile.id),
      GameConfig.gameFoodDailyCap - 2,
    );
    expect(repo.dailyMiniGamePlays(memberId: profile.id), 1);
  });

  test('daily cap stops scored rewards after the limit', () {
    for (int i = 0; i < GameConfig.miniGameDailyCap; i++) {
      clearCooldown();
      final MiniGameResult result = repo.recordMiniGamePlay(
        memberId: profile.id,
        game: MiniGame.snackCatch,
        score: 100,
      );
      expect(result.outcome, MiniGameOutcome.rewarded);
      expect(result.foodAwarded, isNotNull);
    }
    clearCooldown();

    final MiniGameResult capped = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.snackCatch,
      score: 100,
    );

    expect(capped.outcome, MiniGameOutcome.dailyCapReached);
    expect(capped.xpAwarded, 0);
    expect(capped.foodAwarded, isNotNull);
    expect(
      repo
          .foodInventory(memberId: profile.id)
          .values
          .fold<int>(0, (int sum, int count) => sum + count),
      GameConfig.miniGameDailyCap + 1,
    );
    expect(
      repo.dailyMiniGamePlays(memberId: profile.id),
      GameConfig.miniGameDailyCap,
    );
  });

  test('game food has its own daily cap and resets the next UTC day', () {
    for (int i = 0; i < GameConfig.gameFoodDailyCap; i++) {
      final MiniGameResult result = repo.recordMiniGamePlay(
        memberId: profile.id,
        game: MiniGame.ticklePop,
        score: 0,
      );
      expect(result.foodAwarded, isNotNull);
    }
    expect(repo.gameFoodRemaining(memberId: profile.id), 0);
    expect(repo.dailyMiniGamePlays(memberId: profile.id), 1);
    expect(
      repo
          .recordMiniGamePlay(memberId: profile.id, game: MiniGame.ticklePop)
          .foodAwarded,
      isNull,
    );
    db.db.execute('UPDATE food_grants SET created_at = ?', <Object?>[
      DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String(),
    ]);
    expect(
      repo.gameFoodRemaining(memberId: profile.id),
      GameConfig.gameFoodDailyCap,
    );
    expect(
      repo
          .recordMiniGamePlay(memberId: profile.id, game: MiniGame.ticklePop)
          .foodAwarded,
      isNotNull,
    );
  });

  test('naturally ended low-score and lost runs receive food', () {
    for (final MiniGame game in MiniGame.values) {
      final MiniGameResult result = repo.recordMiniGamePlay(
        memberId: profile.id,
        game: game,
        score: 0,
        finished: false,
      );
      expect(result.foodAwarded, isNotNull);
    }
  });

  test('a full pantry does not spend the game food allowance', () {
    for (final Food food in Food.values) {
      repo.addFood(
        memberId: profile.id,
        food: food,
        amount: GameConfig.foodInventoryCap,
      );
    }
    final MiniGameResult full = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.ticklePop,
    );
    expect(full.foodAwarded, isNull);
    expect(
      repo.gameFoodRemaining(memberId: profile.id),
      GameConfig.gameFoodDailyCap,
    );
    db.db.execute('UPDATE food_inventory SET count = 0');
    final MiniGameResult replay = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.ticklePop,
    );
    expect(replay.foodAwarded, isNotNull);
    expect(replay.xpAwarded, 0);
  });

  test('snack catch raises satiety while tickle pop raises mood', () {
    db.db.execute(
      "UPDATE pets SET satiety = 50, mood = 'sad', mood_score = 60",
    );

    final MiniGameResult catchResult = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.snackCatch,
      score: 120,
    );
    expect(catchResult.satietyAfter, 60);

    clearCooldown();
    db.db.execute(
      "UPDATE pets SET satiety = 50, mood = 'sad', mood_score = 60",
    );

    repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.ticklePop,
      score: 20,
      bestCombo: 6,
    );
    expect(repo.getPet()!.moodScore, 66);
    expect(repo.getPet()!.mood.name, 'happy');
  });

  test('mini-game play lands in the activity feed', () {
    repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.moodMatch,
      moves: 8,
    );

    expect(
      repo.feed().map((ActivityEntry entry) => entry.title),
      contains('Sam played Mood Match'),
    );
  });
}
