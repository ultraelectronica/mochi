import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/db/mochi_db.dart';
import 'package:mochi/db/mochi_repository.dart';
import 'package:mochi/models/food.dart';
import 'package:mochi/models/member.dart';
import 'package:mochi/models/mood.dart';
import 'package:mochi/models/pet.dart';
import 'package:mochi/services/local_llm/prompt_builder.dart';

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

  void stock(Food food, [int amount = 1]) {
    repo.addFood(memberId: profile.id, food: food, amount: amount);
  }

  void setPet({
    int? stage,
    int? satiety,
    String? mood,
    Duration? satietyAge,
  }) {
    db.db.execute(
      'UPDATE pets SET '
      'stage = COALESCE(?, stage), '
      'satiety = COALESCE(?, satiety), '
      'mood = COALESCE(?, mood), '
      'satiety_updated_at = ?',
      <Object?>[
        stage,
        satiety,
        mood,
        DateTime.now()
            .toUtc()
            .subtract(satietyAge ?? Duration.zero)
            .toIso8601String(),
      ],
    );
  }

  group('feedPet', () {
    test('locked while the pet is an egg', () {
      final FeedResult result = repo.feedPet(
        memberId: profile.id,
        food: Food.mochiBite,
      );

      expect(result.outcome, FeedOutcome.locked);
    });

    test('success raises satiety, awards XP, and records the meal', () {
      setPet(stage: 2);
      stock(Food.mochiBite);

      final FeedResult result = repo.feedPet(
        memberId: profile.id,
        food: Food.mochiBite,
      );

      expect(result.outcome, FeedOutcome.success);
      expect(result.satietyAfter, 90);
      expect(result.xpAwarded, 3);
      expect(result.foodRemaining, 0);
      expect(repo.getPet()!.satiety, 90);
      expect(repo.lastMeal()!.food, Food.mochiBite);
    });

    test('refuses softly when the pantry has none left', () {
      setPet(stage: 2);

      final FeedResult result = repo.feedPet(
        memberId: profile.id,
        food: Food.mochiBite,
      );

      expect(result.outcome, FeedOutcome.noFood);
      expect(repo.getPet()!.satiety, 70);
      expect(repo.getPet()!.xp, 0);
      expect(repo.lastMeal(), isNull);
    });

    test('feeding consumes the item and reports what is left', () {
      setPet(stage: 2);
      stock(Food.matchaTea, 2);

      final FeedResult first = repo.feedPet(
        memberId: profile.id,
        food: Food.matchaTea,
      );
      expect(first.outcome, FeedOutcome.success);
      expect(first.foodRemaining, 1);
      expect(repo.foodInventory(memberId: profile.id)[Food.matchaTea], 1);

      final FeedResult second = repo.feedPet(
        memberId: profile.id,
        food: Food.matchaTea,
      );
      expect(second.outcome, FeedOutcome.success);
      expect(second.foodRemaining, 0);

      final FeedResult third = repo.feedPet(
        memberId: profile.id,
        food: Food.matchaTea,
      );
      expect(third.outcome, FeedOutcome.noFood);
    });

    test('refuses softly when full', () {
      setPet(stage: 2, satiety: 95);

      final FeedResult result = repo.feedPet(
        memberId: profile.id,
        food: Food.mochiBite,
      );

      expect(result.outcome, FeedOutcome.full);
      expect(repo.getPet()!.satiety, 95);
    });

    test('ramen stays locked until Pup', () {
      setPet(stage: 2);

      expect(
        repo.feedPet(memberId: profile.id, food: Food.ramen).outcome,
        FeedOutcome.locked,
      );

      setPet(stage: 3);
      stock(Food.ramen);

      expect(
        repo.feedPet(memberId: profile.id, food: Food.ramen).outcome,
        FeedOutcome.success,
      );
    });

    test('satiety clamps at the max', () {
      setPet(stage: 2, satiety: 80);
      stock(Food.onigiri);

      final FeedResult result = repo.feedPet(
        memberId: profile.id,
        food: Food.onigiri,
      );

      expect(result.satietyAfter, 100);
    });

    test('feeding clears a hungry mood', () {
      setPet(stage: 2, satiety: 20, mood: 'hungry');
      stock(Food.strawberryDaifuku);

      repo.feedPet(memberId: profile.id, food: Food.strawberryDaifuku);

      expect(repo.getPet()!.mood, MochiMood.happy);
    });

    test('feed event lands in the activity feed', () {
      setPet(stage: 2);
      stock(Food.mochiBite);
      repo.feedPet(memberId: profile.id, food: Food.mochiBite);

      expect(
        repo.feed().map((ActivityEntry entry) => entry.title),
        contains('Sam fed Mochi Mochi bite'),
      );
    });
  });

  group('satiety decay', () {
    test('decays over time since the last satiety stamp', () {
      setPet(satiety: 80, satietyAge: const Duration(hours: 10));

      expect(repo.getPet()!.satiety, 40);
    });

    test('floors at zero after long hunger', () {
      setPet(satiety: 80, satietyAge: const Duration(days: 7));

      expect(repo.getPet()!.satiety, 0);
    });

    test('fresh stamp keeps the stored value', () {
      setPet(satiety: 75);

      expect(repo.getPet()!.satiety, 75);
    });
  });

  group('mood coupling', () {
    test('low satiety forces the hungry mood', () {
      expect(
        MochiRepository.pickMood(80, <String>[], 0, 0, satiety: 10),
        MochiMood.hungry,
      );
    });

    test('recalculateMood reports hungry when starving', () {
      setPet(satiety: 5);

      expect(repo.recalculateMood(), 'hungry');
      expect(repo.getPet()!.mood, MochiMood.hungry);
    });
  });

  group('prompt hunger line', () {
    test('injects the hunger line into the system prompt', () {
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hello',
        mood: MochiMood.normal,
        memories: const <String>[],
        hungerLine: 'Hunger: very hungry. Last meal: Onigiri 2h ago.',
      );

      final String system = messages.first.content;
      expect(system, contains('Hunger: very hungry.'));
      expect(system, contains('Mood note:'));
    });

    test('omits the hunger block when no line is passed', () {
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hello',
        mood: MochiMood.normal,
        memories: const <String>[],
      );

      expect(messages.first.content, isNot(contains('Hunger:')));
    });
  });
}
