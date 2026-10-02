import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../models/mood.dart';
import '../models/food.dart';
import '../providers/pet_provider.dart';
import 'game_shell.dart';
import 'mini_game.dart';

class TicklePopGame extends StatefulWidget {
  const TicklePopGame({super.key, required this.petProvider, this.random});

  final PetProvider petProvider;
  final Random? random;

  @override
  State<TicklePopGame> createState() => _TicklePopGameState();
}

class _Bubble {
  _Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.mood,
    required this.bornAt,
  });

  double x;
  double y;
  final double size;
  final MochiMood mood;
  final double bornAt;
}

class _TicklePopGameState extends State<TicklePopGame>
    with WidgetsBindingObserver, GameLifecycle<TicklePopGame> {
  static const double _lifetime = 1.4;
  static const double _comboWindow = 1.1;

  late final Random _random = widget.random ?? Random();
  final List<_Bubble> _bubbles = <_Bubble>[];

  Size _area = Size.zero;
  Timer? _ticker;
  Timer? _countdown;
  Timer? _squashTimer;
  double _spawnCooldown = 0.3;
  int _remaining = GameConfig.ticklePopDurationSeconds;
  int _popped = 0;
  int _combo = 0;
  int _bestCombo = 0;
  double? _lastPop;
  double _elapsed = 0;
  bool _over = false;
  bool _squash = false;
  MiniGameResult? _result;
  Offset? _mochi;
  static const double _mochiSize = 88;
  final List<({Offset position, double bornAt, int combo})> _bursts = [];

  @override
  void dispose() {
    _squashTimer?.cancel();
    _ticker?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  @override
  void onGamePause() {
    _ticker?.cancel();
    _countdown?.cancel();
  }

  @override
  void onGameResume() {
    if (_over) {
      return;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 16), _tick);
    _countdown = Timer.periodic(const Duration(seconds: 1), _countDown);
  }

  void _countDown(Timer timer) {
    if (_over) {
      return;
    }
    setState(() => _remaining--);
    if (_remaining <= 0) {
      _finish();
    }
  }

  void _tick(Timer timer) {
    if (_over || !gameActive || _area == Size.zero) {
      return;
    }
    const double dt = 0.016;
    final double now = _elapsed += dt;
    _bursts.removeWhere((burst) => now - burst.bornAt > 0.5);
    if (_lastPop != null && now - _lastPop! >= _comboWindow) {
      _combo = 0;
    }
    _bubbles.removeWhere((_Bubble bubble) {
      bubble.y -= 26 * dt;
      return now - bubble.bornAt >= _lifetime;
    });

    _spawnCooldown -= dt;
    if (_spawnCooldown <= 0) {
      _spawnBubble();
      _spawnCooldown =
          0.5 - (1 - _remaining / GameConfig.ticklePopDurationSeconds) * 0.2;
    }
    _checkCollisions();

    setState(() {});
  }

  void _spawnBubble() {
    final double size = 56 + _random.nextDouble() * 24;
    final double x = _random.nextDouble() * (_area.width - size);
    final double y = 40 + _random.nextDouble() * (_area.height - size - 60);
    _bubbles.add(
      _Bubble(
        x: x,
        y: y,
        size: size,
        mood: MochiMood.values[_random.nextInt(MochiMood.values.length)],
        bornAt: _elapsed,
      ),
    );
  }

  void _pop(_Bubble bubble) {
    if (!gameActive || _over) return;
    final double now = _elapsed;
    final bool chained = _lastPop != null && now - _lastPop! < _comboWindow;
    _combo = chained ? _combo + 1 : 1;
    _bestCombo = max(_bestCombo, _combo);
    _lastPop = now;
    _popped++;
    _bursts.add((
      position: Offset(bubble.x, bubble.y),
      bornAt: now,
      combo: _combo,
    ));
    _squash = true;
    HapticFeedback.lightImpact();
    _squashTimer?.cancel();
    _squashTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() => _squash = false);
      }
    });
    setState(() => _bubbles.remove(bubble));
  }

  void _checkCollisions() {
    if (_mochi == null) return;
    for (final _Bubble bubble in List<_Bubble>.of(_bubbles)) {
      final Offset center = Offset(
        bubble.x + bubble.size / 2,
        bubble.y + bubble.size / 2,
      );
      if ((center - _mochi!).distance <= bubble.size / 2 + _mochiSize * 0.35) {
        _pop(bubble);
      }
    }
  }

  void _move(Offset position) {
    if (_over || !gameActive) return;
    setState(
      () => _mochi = Offset(
        position.dx.clamp(
          _mochiSize / 2,
          max(_mochiSize / 2, _area.width - _mochiSize / 2),
        ),
        position.dy.clamp(
          _mochiSize / 2,
          max(_mochiSize / 2, _area.height - _mochiSize / 2),
        ),
      ),
    );
    _checkCollisions();
  }

  Future<void> _finish() async {
    if (_over) {
      return;
    }
    setState(() {
      _over = true;
      _ticker?.cancel();
      _countdown?.cancel();
    });
    final MiniGameResult result = await widget.petProvider.playMiniGame(
      game: MiniGame.ticklePop,
      score: _popped,
      bestCombo: _bestCombo,
      finished: true,
    );
    if (!mounted) {
      return;
    }
    setState(() => _result = result);
    HapticFeedback.mediumImpact();
  }

  void _reset() {
    _squashTimer?.cancel();
    setState(() {
      _bubbles.clear();
      _remaining = GameConfig.ticklePopDurationSeconds;
      _popped = 0;
      _combo = 0;
      _bestCombo = 0;
      _lastPop = null;
      _elapsed = 0;
      _over = false;
      _result = null;
      _spawnCooldown = 0.3;
      _mochi = null;
      _bursts.clear();
      _squash = false;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 16), _tick);
    _countdown = Timer.periodic(const Duration(seconds: 1), _countDown);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Tickle Pop',
      emoji: '🫧',
      accent: MochiPalette.lavender,
      onQuit: () => Navigator.of(context).pop(),
      pet: widget.petProvider.pet,
      instructions:
          'Drag Mochi through the bubbles to pop them. Keep moving to chain combos! Thirty seconds, no lost hearts.',
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
            icon: Icons.bolt_rounded,
            label: 'x$_combo',
            color: MochiPalette.mint,
          ),
          GameHudPill(icon: Icons.touch_app_rounded, label: '$_popped'),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _area = Size(constraints.maxWidth, constraints.maxHeight);
          _mochi ??= Offset(_area.width / 2, _area.height / 2);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _move(details.localPosition),
            onPanUpdate: (details) => _move(details.localPosition),
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: GameScene()),
                Positioned(
                  bottom: 16,
                  left: 20,
                  right: 20,
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _combo > 1
                              ? 'Keep it going! x$_combo'
                              : 'Chase a little joy',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: _lastPop == null
                                ? 0
                                : (1 - (_elapsed - _lastPop!) / _comboWindow)
                                      .clamp(0.0, 1.0),
                            color: MochiPalette.ink,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Text(
                      'Drag Mochi through the bubbles',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                for (final _Bubble bubble in _bubbles)
                  Positioned(
                    left: bubble.x,
                    top: bubble.y,
                    child: IgnorePointer(
                      child: _BubbleView(bubble: bubble, elapsed: _elapsed),
                    ),
                  ),
                for (final burst in _bursts)
                  Positioned(
                    left: burst.position.dx,
                    top: burst.position.dy - 12,
                    child: IgnorePointer(
                      child: Text(
                        '✦ x${burst.combo}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                Positioned(
                  left: _mochi!.dx - _mochiSize / 2,
                  top: _mochi!.dy - _mochiSize / 2,
                  child: IgnorePointer(
                    child: MochiGameSprite(
                      size: _mochiSize,
                      pet: widget.petProvider.pet,
                      squash: _squash,
                    ),
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
                      emoji: '🫧',
                      headline: _bestCombo >= 8
                          ? 'Mochi is extra wiggly!'
                          : 'Tickle time done',
                      accent: MochiPalette.lavender,
                      lines: <String>[
                        'Popped $_popped bubbles · best combo x$_bestCombo',
                        _rewardLine(_result),
                        if (_result?.foodAwarded != null)
                          '+1 ${_result!.foodAwarded!.emoji} ${_result!.foodAwarded!.label}',
                      ],
                      onReplay: _reset,
                      onDone: () => Navigator.of(context).pop(),
                    ),
                  ),
              ],
            ),
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
        '+${result.xpAwarded} XP · Mochi is delighted',
      MiniGameOutcome.dailyCapReached ||
      MiniGameOutcome.cooldown => result.xpRestLine,
    };
  }
}

class _BubbleView extends StatelessWidget {
  const _BubbleView({required this.bubble, required this.elapsed});

  final _Bubble bubble;
  final double elapsed;

  @override
  Widget build(BuildContext context) {
    final double life = (1 - (elapsed - bubble.bornAt) / 1.4).clamp(0.0, 1.0);
    return Opacity(
      opacity: 0.35 + life * 0.65,
      child: Container(
        width: bubble.size,
        height: bubble.size,
        decoration: BoxDecoration(
          color: bubble.mood.color.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: MochiPalette.ink, width: 2.5),
        ),
        child: Center(
          child: Icon(
            bubble.mood.icon,
            size: bubble.size * 0.42,
            color: MochiPalette.ink,
          ),
        ),
      ),
    );
  }
}
