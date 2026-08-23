import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/db/mochi_repository.dart';
import 'package:mochi/models/mood.dart';

void main() {
  group('clamp', () {
    test('returns value within range', () {
      expect(_clampValue(50, 0, 100), 50);
    });

    test('clamps below min', () {
      expect(_clampValue(-10, 0, 100), 0);
    });

    test('clamps above max', () {
      expect(_clampValue(200, 0, 100), 100);
    });

    test('handles equal bounds', () {
      expect(_clampValue(50, 50, 50), 50);
      expect(_clampValue(0, 50, 50), 50);
    });
  });

  group('dominantCount', () {
    test('counts occurrences', () {
      expect(_dominantCount(<String>['happy', 'sad', 'happy'], 'happy'), 2);
    });

    test('returns 0 for no matches', () {
      expect(_dominantCount(<String>['happy', 'sad'], 'angry'), 0);
    });

    test('works with empty array', () {
      expect(_dominantCount(<String>[], 'happy'), 0);
    });
  });

  group('pickMood', () {
    test('severe inactivity -> hungry', () {
      expect(
        MochiRepository.pickMood(80, <String>[], 0, 24),
        MochiMood.hungry,
      );
    });

    test('moderate inactivity -> tired', () {
      expect(
        MochiRepository.pickMood(80, <String>[], 0, 12),
        MochiMood.tired,
      );
    });

    test('high score -> laughing', () {
      expect(
        MochiRepository.pickMood(90, <String>[], 0, 0),
        MochiMood.laughing,
      );
    });

    test('recent chats -> laughing', () {
      expect(
        MochiRepository.pickMood(70, <String>[], 4, 0),
        MochiMood.laughing,
      );
    });

    test('good score -> happy', () {
      expect(
        MochiRepository.pickMood(78, <String>[], 0, 0),
        MochiMood.happy,
      );
    });

    test('multiple scared -> scared', () {
      expect(
        MochiRepository.pickMood(
          50,
          <String>['scared', 'scared'],
          0,
          0,
        ),
        MochiMood.scared,
      );
    });

    test('very low score -> scared', () {
      expect(
        MochiRepository.pickMood(10, <String>[], 0, 0),
        MochiMood.scared,
      );
    });

    test('multiple angry -> angry', () {
      expect(
        MochiRepository.pickMood(
          30,
          <String>['angry', 'angry'],
          0,
          0,
        ),
        MochiMood.angry,
      );
    });

    test('moderate score -> angry', () {
      expect(
        MochiRepository.pickMood(25, <String>[], 0, 0),
        MochiMood.angry,
      );
    });

    test('multiple sad -> sad', () {
      expect(
        MochiRepository.pickMood(50, <String>['sad', 'sad'], 0, 0),
        MochiMood.sad,
      );
    });

    test('moderate-low score -> sad', () {
      expect(MochiRepository.pickMood(45, <String>[], 0, 0), MochiMood.sad);
    });

    test('defaults to normal', () {
      expect(
        MochiRepository.pickMood(60, <String>['happy'], 0, 0),
        MochiMood.normal,
      );
    });

    test('varied moods -> confused', () {
      expect(
        MochiRepository.pickMood(
          55,
          <String>['happy', 'sad', 'normal'],
          0,
          0,
        ),
        MochiMood.confused,
      );
    });

    test('tired overrides confused when both apply', () {
      expect(
        MochiRepository.pickMood(
          55,
          <String>['happy', 'sad', 'normal'],
          0,
          12,
        ),
        MochiMood.tired,
      );
    });
  });
}

int _clampValue(int value, int min, int max) =>
    value > max ? max : (value < min ? min : value);

int _dominantCount(List<String> moods, String target) =>
    moods.where((String mood) => mood == target).length;
