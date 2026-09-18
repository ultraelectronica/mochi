import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/config/game_config.dart';
import 'package:mochi/games/mini_game.dart';
import 'package:mochi/games/mini_game_scoring.dart';

void main() {
  group('snackCatch', () {
    test('scales with score but never passes the cap', () {
      expect(miniGameXpForScore(MiniGame.snackCatch, score: 0), 2);
      expect(miniGameXpForScore(MiniGame.snackCatch, score: 50), 4);
      expect(
        miniGameXpForScore(MiniGame.snackCatch, score: 9999),
        GameConfig.xpPerMiniGameMax,
      );
    });

    test('negative scores never go below zero', () {
      expect(miniGameXpForScore(MiniGame.snackCatch, score: -40), 2);
    });
  });

  group('ticklePop', () {
    test('scales with best combo', () {
      expect(miniGameXpForScore(MiniGame.ticklePop, score: 99, bestCombo: 0), 2);
      expect(
        miniGameXpForScore(MiniGame.ticklePop, score: 99, bestCombo: 4),
        4,
      );
      expect(
        miniGameXpForScore(MiniGame.ticklePop, score: 99, bestCombo: 100),
        GameConfig.xpPerMiniGameMax,
      );
    });
  });

  group('moodMatch', () {
    test('par or better hits the cap', () {
      expect(
        miniGameXpForScore(MiniGame.moodMatch, moves: 10, finished: true),
        GameConfig.xpPerMiniGameMax,
      );
      expect(
        miniGameXpForScore(MiniGame.moodMatch, moves: 6, finished: true),
        GameConfig.xpPerMiniGameMax,
      );
    });

    test('over par lowers rewards but floors at three', () {
      expect(miniGameXpForScore(MiniGame.moodMatch, moves: 14, finished: true), 6);
      expect(miniGameXpForScore(MiniGame.moodMatch, moves: 60, finished: true), 3);
    });

    test('unfinished run only pays the consolation point', () {
      expect(miniGameXpForScore(MiniGame.moodMatch, moves: 3, finished: false), 1);
    });
  });
}
