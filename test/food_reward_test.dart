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
    test('grants a treat every fourth rewarded chat', () {
      sendRewardedChats(GameConfig.chatFoodEveryN - 1);

      expect(repo.claimChatFoodDrop(memberId: profile.id), isNull);
      expect(pantryTotal(), 0);

      sendRewardedChats(1);

      final Food? drop = repo.claimChatFoodDrop(memberId: profile.id);
      expect(drop, isNotNull);
      expect(repo.foodInventory(memberId: profile.id)[drop!], 1);
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
        repo.addFood(memberId: profile.id, food: food, amount: 9);
      }

      expect(
        repo.rollFoodDrop(memberId: profile.id, source: FoodSource.game),
        Food.matchaTea,
      );
    });

    test('returns null when every unlocked food is capped', () {
      for (final Food food in Food.values) {
        repo.addFood(memberId: profile.id, food: food, amount: 9);
      }

      expect(repo.rollFoodDrop(memberId: profile.id, source: FoodSource.game), isNull);
    });
  });

  group('check-in drop', () {
    test('grants once per day', () {
      expect(
        repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'),
        isNotNull,
      );
      expect(repo.recordMoodCheckIn(memberId: profile.id, mood: 'good'), isNull);
      expect(pantryTotal(), GameConfig.checkInFoodDailyCap);
    });
  });

  group('starter pack', () {
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
