import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/games/game_shell.dart';
import 'package:mochi/games/mini_game.dart';
import 'package:mochi/games/mood_match_game.dart';
import 'package:mochi/games/snack_catch_game.dart';
import 'package:mochi/games/tickle_pop_game.dart';
import 'package:mochi/providers/pet_provider.dart';

class _TestProvider extends PetProvider {
  @override
  Future<MiniGameResult> playMiniGame({
    required MiniGame game,
    int score = 0,
    int bestCombo = 0,
    int moves = 0,
    bool finished = true,
  }) async {
    return const MiniGameResult(
      outcome: MiniGameOutcome.rewarded,
      xpAwarded: 3,
      playsRemaining: 4,
    );
  }
}

Future<void> _pumpGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: game));
  await tester.pump();
}

int _circleCount(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .where(
        (Container c) =>
            c.decoration is BoxDecoration &&
            (c.decoration! as BoxDecoration).shape == BoxShape.circle,
      )
      .length;
}

void main() {
  testWidgets('snack catch keeps falling items on screen', (tester) async {
    await _pumpGame(tester, SnackCatchGame(petProvider: _TestProvider()));
    await tester.pump(const Duration(seconds: 2));

    final Iterable<Text> items = tester
        .widgetList<Text>(find.byType(Text))
        .where((Text t) => t.style?.fontSize == 42);
    expect(items, isNotEmpty, reason: 'snacks and trash should be falling');
  });

  testWidgets('snack catch keeps the paddle at the left edge', (tester) async {
    await _pumpGame(tester, SnackCatchGame(petProvider: _TestProvider()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(find.byType(MochiGameBlob), const Offset(-600, 0));
    await tester.pump();
    final double leftBefore = tester.getTopLeft(find.byType(MochiGameBlob)).dx;

    await tester.pump(const Duration(milliseconds: 200));
    final double leftAfter = tester.getTopLeft(find.byType(MochiGameBlob)).dx;

    expect(leftAfter, closeTo(leftBefore, 0.5));
    expect(leftAfter, lessThan(100));
  });

  testWidgets('tickle pop keeps bubbles on screen', (tester) async {
    await _pumpGame(tester, TicklePopGame(petProvider: _TestProvider()));
    await tester.pump(const Duration(seconds: 2));

    expect(
      _circleCount(tester),
      greaterThan(1),
      reason: 'the blob plus spawned bubbles',
    );
  });

  testWidgets('mood match cards stretch to fill the board', (tester) async {
    await _pumpGame(tester, MoodMatchGame(petProvider: _TestProvider()));
    await tester.pump(const Duration(milliseconds: 300));

    final Size card = tester.getSize(find.byType(AnimatedContainer).first);
    expect(card.height, greaterThan(card.width));
  });
}
