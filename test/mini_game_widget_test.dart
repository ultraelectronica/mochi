import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/games/game_shell.dart';
import 'package:mochi/games/mini_game.dart';
import 'package:mochi/games/mood_match_game.dart';
import 'package:mochi/games/snack_catch_game.dart';
import 'package:mochi/games/tickle_pop_game.dart';
import 'package:mochi/providers/pet_provider.dart';
import 'package:mochi/models/food.dart';
import 'package:mochi/models/pet.dart';
import 'package:mochi/models/mood.dart';
import 'package:mochi/config/app_config.dart';

class _TestProvider extends PetProvider {
  _TestProvider({this.outcome = MiniGameOutcome.rewarded});

  final MiniGameOutcome outcome;
  int submissions = 0;

  @override
  Pet get pet => const Pet(
    id: 1,
    name: 'Mochi',
    stageNumber: 3,
    xp: 800,
    mood: MochiMood.normal,
    moodScore: 60,
  );

  @override
  Future<MiniGameResult> playMiniGame({
    required MiniGame game,
    int score = 0,
    int bestCombo = 0,
    int moves = 0,
    bool finished = true,
  }) async {
    submissions++;
    return MiniGameResult(
      outcome: outcome,
      xpAwarded: outcome == MiniGameOutcome.rewarded ? 3 : 0,
      playsRemaining: 4,
      foodAwarded: Food.onigiri,
    );
  }
}

Future<void> _pumpGame(WidgetTester tester, Widget game) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildMochiTheme(), home: game));
  await tester.pump();
  await tester.tap(find.text('Start'));
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
  for (final MiniGameOutcome outcome in <MiniGameOutcome>[
    MiniGameOutcome.cooldown,
    MiniGameOutcome.dailyCapReached,
  ]) {
    testWidgets('game results show food when XP outcome is $outcome', (
      tester,
    ) async {
      final _TestProvider provider = _TestProvider(outcome: outcome);
      await _pumpGame(tester, TicklePopGame(petProvider: provider));
      for (int i = 0; i < 31; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();
      expect(provider.submissions, 1);
      expect(
        find.textContaining('+1 ${Food.onigiri.emoji} ${Food.onigiri.label}'),
        findsOneWidget,
      );
      expect(find.textContaining('+3 XP'), findsNothing);
    });
  }

  testWidgets('leaving a game early does not submit a food reward', (
    tester,
  ) async {
    final _TestProvider provider = _TestProvider();
    await _pumpGame(tester, TicklePopGame(petProvider: provider));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 35));
    expect(provider.submissions, 0);
  });

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

    await tester.drag(find.byType(MochiGameSprite), const Offset(-600, 0));
    await tester.pump();
    final double leftBefore = tester
        .getTopLeft(find.byType(MochiGameSprite))
        .dx;

    await tester.pump(const Duration(milliseconds: 200));
    final double leftAfter = tester.getTopLeft(find.byType(MochiGameSprite)).dx;

    expect(leftAfter, closeTo(leftBefore, 0.5));
    expect(leftAfter, lessThan(100));
  });

  testWidgets('tickle pop keeps bubbles on screen', (tester) async {
    await _pumpGame(tester, TicklePopGame(petProvider: _TestProvider()));
    await tester.pump(const Duration(seconds: 2));

    expect(
      _circleCount(tester),
      greaterThan(0),
      reason: 'spawned bubbles remain visible',
    );
  });

  testWidgets('mood match cards stretch to fill the board', (tester) async {
    await _pumpGame(tester, MoodMatchGame(petProvider: _TestProvider()));
    await tester.pump(const Duration(milliseconds: 300));

    final Size card = tester.getSize(find.byType(AnimatedContainer).first);
    expect(card.height, greaterThan(card.width));
  });

  testWidgets('instructions wait for Start and pause freezes the clock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final provider = _TestProvider();
    await tester.pumpWidget(
      MaterialApp(home: TicklePopGame(petProvider: provider)),
    );
    await tester.pump(const Duration(seconds: 35));
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
    expect(provider.submissions, 0);
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byTooltip('Pause game'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:28'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:27'), findsOneWidget);
  });

  testWidgets('dragging Mochi into a bubble pops it', (tester) async {
    await _pumpGame(
      tester,
      TicklePopGame(petProvider: _TestProvider(), random: Random(7)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final bubbles = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
    );
    expect(bubbles, findsWidgets);
    final target = tester.getCenter(bubbles.first);
    final start = tester.getCenter(find.byType(MochiGameSprite));
    await tester.dragFrom(start, target - start);
    await tester.pump();
    expect(find.textContaining('✦ x'), findsWidgets);
    expect(
      (tester.getCenter(find.byType(MochiGameSprite)) - target).distance,
      lessThan(12),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('background pause waits for an explicit resume', (tester) async {
    await _pumpGame(tester, MoodMatchGame(petProvider: _TestProvider()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 5));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1:29'), findsOneWidget);
  });

  testWidgets('replay resets the clock and submits only completed runs', (
    tester,
  ) async {
    final provider = _TestProvider();
    await _pumpGame(
      tester,
      TicklePopGame(petProvider: provider, random: Random(7)),
    );
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(provider.submissions, 1);
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byType(GameResultCard), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:29'), findsOneWidget);
    expect(provider.submissions, 1);
  });

  for (final game in MiniGame.values) {
    testWidgets('${game.label} fits a compact screen with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = _TestProvider();
      final screen = switch (game) {
        MiniGame.snackCatch => SnackCatchGame(petProvider: provider),
        MiniGame.ticklePop => TicklePopGame(
          petProvider: provider,
          random: Random(7),
        ),
        MiniGame.moodMatch => MoodMatchGame(petProvider: provider),
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMochiTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: screen,
          ),
        ),
      );
      await tester.ensureVisible(find.text('Start'));
      await tester.tap(find.text('Start'));
      await tester.pump(const Duration(milliseconds: 400));
      if (game == MiniGame.moodMatch) {
        await tester.tap(find.byType(AnimatedContainer).first);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
