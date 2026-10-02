import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/config/game_config.dart';
import 'package:mochi/db/mochi_db.dart';
import 'package:mochi/db/mochi_repository.dart';
import 'package:mochi/models/food.dart';
import 'package:mochi/models/member.dart';

void main() {
  late MochiDb db;
  late MochiRepository repo;
  late Member profile;
  late int sessionId;

  setUp(() {
    db = MochiDb.openInMemory();
    repo = MochiRepository(db, random: math.Random(7));
    repo.createPet('Mochi');
    profile = repo.createProfile('Sam', '#1D9E75');
    sessionId = repo.resolveSession(memberId: profile.id);
    db.db.execute('UPDATE pets SET stage = 2');
  });

  tearDown(() {
    db.db.close();
  });

  int pantryTotal() => repo
      .foodInventory(memberId: profile.id)
      .values
      .fold<int>(0, (int sum, int count) => sum + count);

  void sendRewardedChats(int count) {
    for (int i = 0; i < count; i++) {
      repo.insertInteraction(
        memberId: profile.id,
        sessionId: sessionId,
        inputText: 'hello',
        responseText: 'hi',
        inputType: 'text',
        xpAwarded: GameConfig.xpPerChat,
      );
    }
  }

  group('chat drops', () {
    test('grants a treat every second rewarded chat', () {
      sendRewardedChats(GameConfig.chatFoodEveryN - 1);

      expect(repo.claimChatFoodDrop(memberId: profile.id), isNull);
      expect(pantryTotal(), 0);

      sendRewardedChats(1);

      final Food? drop = repo.claimChatFoodDrop(memberId: profile.id);
      expect(drop, isNotNull);
      expect(repo.foodInventory(memberId: profile.id)[drop!], 1);
    });

    test('unrewarded chats do not advance food progress', () {
      sendRewardedChats(1);
      for (int i = 0; i < 4; i++) {
        repo.insertInteraction(
          memberId: profile.id,
          sessionId: sessionId,
          inputText: 'deflected',
          responseText: 'lets chat about us',
          inputType: 'text',
          xpAwarded: 0,
        );
      }
      expect(repo.claimChatFoodDrop(memberId: profile.id), isNull);
      sendRewardedChats(1);
      expect(repo.claimChatFoodDrop(memberId: profile.id), isNotNull);
    });

    test('chat progress carries over the UTC day boundary', () {
      sendRewardedChats(1);
      db.db.execute('UPDATE interactions SET created_at = ?', <Object?>[
        DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
      ]);
      sendRewardedChats(1);
      expect(repo.claimChatFoodDrop(memberId: profile.id), isNotNull);
    });

    test('stops after the daily chat cap', () {
      for (int i = 0; i < GameConfig.chatFoodDailyCap; i++) {
        sendRewardedChats(GameConfig.chatFoodEveryN);
        expect(repo.claimChatFoodDrop(memberId: profile.id), isNotNull);
      }

      sendRewardedChats(GameConfig.chatFoodEveryN);
      expect(repo.claimChatFoodDrop(memberId: profile.id), isNull);
      expect(pantryTotal(), GameConfig.chatFoodDailyCap);
    });
  });

  group('rollFoodDrop', () {
    test('skips foods already at the pantry cap', () {
      for (final Food food in Food.values) {
        if (food == Food.matchaTea) {
          continue;
        }
        repo.addFood(
          memberId: profile.id,
          food: food,
          amount: GameConfig.foodInventoryCap,
        );
      }

      expect(
        repo.rollFoodDrop(memberId: profile.id, source: FoodSource.game),
        Food.matchaTea,
      );
    });

    test('returns null when every unlocked food is capped', () {
      for (final Food food in Food.values) {
        repo.addFood(
          memberId: profile.id,
          food: food,
          amount: GameConfig.foodInventoryCap,
        );
      }

      expect(
        repo.rollFoodDrop(memberId: profile.id, source: FoodSource.game),
        isNull,
      );
    });
  });

  group('check-in drop', () {
    test('grants both staples once per day with item-level history', () {
      expect(repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'), <Food>[
        Food.mochiBite,
        Food.onigiri,
      ]);
      expect(
        repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'),
        isEmpty,
      );
      expect(pantryTotal(), GameConfig.checkInFoodDailyCap);
      expect(db.db.select('SELECT * FROM mood_log'), hasLength(1));
      expect(
        db.db.select("SELECT * FROM food_grants WHERE source = 'checkIn'"),
        hasLength(2),
      );
      expect(
        repo.feed().map((entry) => entry.title),
        containsAll(<String>[
          'Sam found ${Food.mochiBite.label}',
          'Sam found ${Food.onigiri.label}',
        ]),
      );
    });

    test('a capped staple is replaced with an available unlocked food', () {
      repo.addFood(
        memberId: profile.id,
        food: Food.mochiBite,
        amount: GameConfig.foodInventoryCap,
      );
      final List<Food> rewards = repo.recordMoodCheckIn(
        memberId: profile.id,
        mood: 'good',
      );
      expect(rewards, hasLength(2));
      expect(rewards, isNot(contains(Food.mochiBite)));
      expect(rewards.last, Food.onigiri);
      expect(rewards, isNot(contains(Food.ramen)));
    });

    test(
      'a full pantry or egg cannot receive check-in food or retry later',
      () {
        db.db.execute('UPDATE pets SET stage = 1');
        expect(
          repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'),
          isEmpty,
        );
        db.db.execute('UPDATE pets SET stage = 2');
        expect(
          repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'),
          isEmpty,
        );
        expect(pantryTotal(), 0);

        db.db.execute('DELETE FROM mood_log');
        for (final Food food in Food.values) {
          repo.addFood(
            memberId: profile.id,
            food: food,
            amount: GameConfig.foodInventoryCap,
          );
        }
        expect(
          repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'),
          isEmpty,
        );
        db.db.execute('UPDATE food_inventory SET count = 0');
        expect(
          repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'),
          isEmpty,
        );
      },
    );

    test('one free slot grants one item and never exceeds capacity', () {
      for (final Food food in Food.values) {
        repo.addFood(
          memberId: profile.id,
          food: food,
          amount: GameConfig.foodInventoryCap,
        );
      }
      db.db.execute(
        "UPDATE food_inventory SET count = count - 1 WHERE food = 'onigiri'",
      );
      expect(repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'), <Food>[
        Food.onigiri,
      ]);
      expect(
        repo.foodInventory(memberId: profile.id)[Food.onigiri],
        GameConfig.foodInventoryCap,
      );
    });

    test('a new UTC day permits another check-in bundle', () {
      repo.recordMoodCheckIn(memberId: profile.id, mood: 'good');
      final String yesterday = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      db.db.execute('UPDATE mood_log SET created_at = ?', <Object?>[yesterday]);
      db.db.execute('UPDATE food_grants SET created_at = ?', <Object?>[
        yesterday,
      ]);
      expect(repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'), <Food>[
        Food.mochiBite,
        Food.onigiri,
      ]);
      expect(pantryTotal(), 4);
    });
  });

  group('starter pack', () {
    test('existing starter packs are not topped up', () {
      repo.addFood(
        memberId: profile.id,
        food: Food.mochiBite,
        amount: 5,
        source: FoodSource.starter,
      );
      repo.addFood(
        memberId: profile.id,
        food: Food.onigiri,
        amount: 2,
        source: FoodSource.starter,
      );
      repo.grantStarterPack(memberId: profile.id);
      expect(pantryTotal(), 7);
    });
    test('grants the first pantry and never grants twice', () {
      repo.grantStarterPack(memberId: profile.id);

      final Map<Food, int> pantry = repo.foodInventory(memberId: profile.id);
      expect(pantry[Food.mochiBite], GameConfig.starterMochiBites);
      expect(pantry[Food.onigiri], GameConfig.starterOnigiri);

      repo.grantStarterPack(memberId: profile.id);

      final Map<Food, int> again = repo.foodInventory(memberId: profile.id);
      expect(again[Food.mochiBite], GameConfig.starterMochiBites);
      expect(again[Food.onigiri], GameConfig.starterOnigiri);
    });
  });
}
