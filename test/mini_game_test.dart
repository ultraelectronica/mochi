import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/config/game_config.dart';
import 'package:mochi/db/mochi_db.dart';
import 'package:mochi/db/mochi_repository.dart';
import 'package:mochi/games/mini_game.dart';
import 'package:mochi/models/member.dart';
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
  });

  tearDown(() {
    db.db.close();
  });

  /// Backdates every recorded play so the 90s inter-play cooldown is clear.
  void clearCooldown() {
    db.db.execute(
      'UPDATE mini_game_plays SET created_at = ?',
      <Object?>[
        DateTime.now()
            .toUtc()
            .subtract(Duration(minutes: 10))
            .toIso8601String(),
      ],
    );
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
    expect(repo.getPet()!.xp, 6);
    expect(repo.miniGameBestScores(memberId: profile.id)[MiniGame.snackCatch], 100);
    expect(repo.dailyMiniGamePlays(memberId: profile.id), 1);
  });

  test('a second run hits the cooldown and earns nothing', () {
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
    }
    clearCooldown();

    final MiniGameResult capped = repo.recordMiniGamePlay(
      memberId: profile.id,
      game: MiniGame.snackCatch,
      score: 100,
    );

    expect(capped.outcome, MiniGameOutcome.dailyCapReached);
    expect(capped.xpAwarded, 0);
    expect(repo.dailyMiniGamePlays(memberId: profile.id), GameConfig.miniGameDailyCap);
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
    db.db.execute("UPDATE pets SET satiety = 50, mood = 'sad', mood_score = 60");

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
