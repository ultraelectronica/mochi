import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../models/mood.dart';
import '../models/food.dart';
import '../models/pet.dart';
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
  Timer? _revealTimer;
  int _remaining = GameConfig.moodMatchSeconds;
  int _moves = 0;
  bool _busy = false;
  bool _over = false;
  MiniGameResult? _result;

  int get _matchedCount => _cards.where((_Card card) => card.matched).length;

  bool get _allMatched => _cards.isNotEmpty && _matchedCount == _cards.length;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  @override
  void onGamePause() {
    _revealTimer?.cancel();
    _countdown?.cancel();
  }

  @override
  void onGameResume() {
    if (_over) {
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), _tick);
    if (_busy) _hideMismatch();
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

  void _tap(int index) {
    if (_over || _busy || !gameActive) {
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
    _hideMismatch();
  }

  void _hideMismatch() {
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(milliseconds: 720), () {
      if (!mounted || _over || !gameActive) return;
      setState(() {
        _revealed.clear();
        _busy = false;
      });
    });
  }

  Future<void> _finish() async {
    _revealTimer?.cancel();
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
    _revealTimer?.cancel();
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
      pet: widget.petProvider.pet,
      instructions:
          'Turn over two cards and find matching Mochi moods. Six pairs, one cozy puzzle. Take your time!',
      started: gameStarted,
      onStart: startGame,
      onPause: _over ? null : toggleGamePause,
      hud: Wrap(
        runSpacing: 6,
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
                        pet: widget.petProvider.pet,
                      ),
                  ],
                ),
              ),
              if (gamePaused && !_over)
                Positioned.fill(
                  child: GamePausedOverlay(onResume: toggleGamePause),
                ),
              if (_over)
                Positioned.fill(
                  child: GameResultCard(
                    pet: widget.petProvider.pet,
                    ready: _result != null,
                    emoji: '🃏',
                    headline: _allMatched ? 'All matched!' : 'Time is up',
                    accent: MochiPalette.mint,
                    lines: <String>[
                      'Pairs ${_matchedCount ~/ 2}/6 · $_moves moves',
                      _rewardLine(_result),
                      if (_result?.foodAwarded != null)
                        '+1 ${_result!.foodAwarded!.emoji} ${_result!.foodAwarded!.label}',
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
      MiniGameOutcome.rewarded => '+${result.xpAwarded} XP · calm and cozy',
      MiniGameOutcome.dailyCapReached ||
      MiniGameOutcome.cooldown => result.xpRestLine,
    };
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.card,
    required this.faceUp,
    required this.onTap,
    required this.pet,
  });

  final _Card card;
  final bool faceUp;
  final VoidCallback onTap;
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: card.matched
          ? '${card.mood.label} matched'
          : faceUp
          ? card.mood.label
          : 'Hidden mood card',
      child: GestureDetector(
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
              final double iconSize = max(
                0.0,
                min(
                  constraints.maxWidth * 0.42,
                  (constraints.maxHeight - (card.matched ? 42 : 24)) / 1.6,
                ),
              );
              return Center(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY((1 - animation.value) * pi / 2),
                      child: child,
                    ),
                  ),
                  child: faceUp
                      ? Column(
                          key: ValueKey(card.mood),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            MochiGameSprite(
                              size: iconSize * 1.6,
                              pet: pet,
                              mood: card.mood,
                            ),
                            FittedBox(
                              child: Text(
                                card.mood.label,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            if (card.matched)
                              const Icon(Icons.check_rounded, size: 18),
                          ],
                        )
                      : Icon(
                          Icons.favorite_rounded,
                          key: const ValueKey('back'),
                          size: iconSize * 0.8,
                          color: MochiPalette.ink,
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
