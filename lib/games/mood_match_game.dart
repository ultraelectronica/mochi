import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../models/mood.dart';
import '../providers/pet_provider.dart';
import 'game_shell.dart';
import 'mini_game.dart';

class _Card {
  _Card(this.mood);

  final MochiMood mood;
  bool matched = false;
}

class MoodMatchGame extends StatefulWidget {
  const MoodMatchGame({super.key, required this.petProvider});

  final PetProvider petProvider;

  @override
  State<MoodMatchGame> createState() => _MoodMatchGameState();
}

class _MoodMatchGameState extends State<MoodMatchGame>
    with WidgetsBindingObserver, GameLifecycle<MoodMatchGame> {
  final Random _random = Random();
  final List<_Card> _cards = <_Card>[];
  final Set<int> _revealed = <int>{};

  Timer? _countdown;
  int _remaining = GameConfig.moodMatchSeconds;
  int _moves = 0;
  bool _busy = false;
  bool _over = false;
  MiniGameResult? _result;

  int get _matchedCount =>
      _cards.where((_Card card) => card.matched).length;

  bool get _allMatched => _cards.isNotEmpty && _matchedCount == _cards.length;

  @override
  void initState() {
    super.initState();
    _deal();
    _countdown = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  void onGamePause() {
    _countdown?.cancel();
  }

  @override
  void onGameResume() {
    if (_over) {
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _deal() {
    final List<MochiMood> moods = List<MochiMood>.of(MochiMood.values)
      ..shuffle(_random);
    final List<MochiMood> chosen = moods.take(6).toList();
    _cards
      ..clear()
      ..addAll(<_Card>[
        for (final MochiMood mood in chosen) ...<_Card>[
          _Card(mood),
          _Card(mood),
        ],
      ])
      ..shuffle(_random);
  }

  void _tick(Timer timer) {
    if (_over) {
      return;
    }
    setState(() => _remaining--);
    if (_remaining <= 0) {
      _finish();
    }
  }

  Future<void> _tap(int index) async {
    if (_over || _busy) {
      return;
    }
    final _Card card = _cards[index];
    if (card.matched || _revealed.contains(index)) {
      return;
    }
    setState(() => _revealed.add(index));
    HapticFeedback.selectionClick();

    if (_revealed.length < 2) {
      return;
    }

    _moves++;
    final List<int> pair = _revealed.toList();
    if (_cards[pair[0]].mood == _cards[pair[1]].mood) {
      setState(() {
        _cards[pair[0]].matched = true;
        _cards[pair[1]].matched = true;
        _revealed.clear();
      });
      HapticFeedback.lightImpact();
      if (_allMatched) {
        _finish();
      }
      return;
    }

    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted) {
      return;
    }
    setState(() {
      _revealed.clear();
      _busy = false;
    });
  }

  Future<void> _finish() async {
    if (_over) {
      return;
    }
    setState(() {
      _over = true;
      _countdown?.cancel();
    });
    final MiniGameResult result = await widget.petProvider.playMiniGame(
      game: MiniGame.moodMatch,
      score: _matchedCount,
      moves: _moves,
      finished: _allMatched,
    );
    if (!mounted) {
      return;
    }
    setState(() => _result = result);
    HapticFeedback.mediumImpact();
  }

  void _reset() {
    setState(() {
      _cards.clear();
      _revealed.clear();
      _remaining = GameConfig.moodMatchSeconds;
      _moves = 0;
      _busy = false;
      _over = false;
      _result = null;
      _deal();
    });
    _countdown = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Mood Match',
      emoji: '🃏',
      accent: MochiPalette.mint,
      onQuit: () => Navigator.of(context).pop(),
      hud: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GameHudPill(
            icon: Icons.timer_outlined,
            label: formatGameClock(_remaining),
            color: MochiPalette.yellow,
          ),
          GameHudPill(
            icon: Icons.swap_horiz_rounded,
            label: '$_moves',
            color: MochiPalette.cloudBlue,
          ),
          GameHudPill(
            icon: Icons.grid_view_rounded,
            label: '${_matchedCount ~/ 2}/6',
            color: MochiPalette.mint,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth >= 520 ? 4 : 3;
          const double gap = 10;
          const double pad = 10;
          final int rows = (_cards.length / columns).ceil();
          final double cellWidth =
              (constraints.maxWidth - pad * 2 - gap * (columns - 1)) / columns;
          final double cellHeight =
              (constraints.maxHeight - pad * 2 - gap * (rows - 1)) / rows;
          final double ratio =
              cellWidth / (cellHeight <= 0 ? cellWidth : cellHeight);
          return Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(pad),
                child: GridView.count(
                  crossAxisCount: columns,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: ratio,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    for (int i = 0; i < _cards.length; i++)
                      _MoodCard(
                        card: _cards[i],
                        faceUp: _revealed.contains(i) || _cards[i].matched,
                        onTap: () => _tap(i),
                      ),
                  ],
                ),
              ),
              if (gamePaused && !_over)
                const Positioned.fill(child: GamePausedOverlay()),
              if (_over)
                Positioned.fill(
                  child: GameResultCard(
                    emoji: '🃏',
                    headline: _allMatched ? 'All matched!' : 'Time is up',
                    accent: MochiPalette.mint,
                    lines: <String>[
                      'Pairs ${_matchedCount ~/ 2}/6 · $_moves moves',
                      _rewardLine(_result),
                    ],
                    onReplay: _reset,
                    onDone: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _rewardLine(MiniGameResult? result) {
    if (result == null) {
      return 'Saving the run...';
    }
    return switch (result.outcome) {
      MiniGameOutcome.rewarded =>
        '+${result.xpAwarded} XP · calm and cozy${result.foodSuffix}',
      MiniGameOutcome.dailyCapReached =>
        'Daily play bonus used up. Still fun though!',
      MiniGameOutcome.cooldown => 'On cooldown. No XP this time.',
    };
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.card,
    required this.faceUp,
    required this.onTap,
  });

  final _Card card;
  final bool faceUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: faceUp
              ? card.mood.color.withValues(alpha: 0.8)
              : MochiPalette.cloudBlue.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: card.matched ? MochiPalette.mint : MochiPalette.ink,
            width: card.matched ? 3.5 : 2.5,
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double iconSize =
                constraints.biggest.shortestSide * 0.42;
            return Center(
              child: faceUp
                  ? Icon(card.mood.icon, size: iconSize, color: MochiPalette.ink)
                  : Icon(
                      Icons.question_mark_rounded,
                      size: iconSize * 0.8,
                      color: MochiPalette.ink,
                    ),
            );
          },
        ),
      ),
    );
  }
}
