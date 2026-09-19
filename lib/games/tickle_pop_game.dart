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

class TicklePopGame extends StatefulWidget {
  const TicklePopGame({super.key, required this.petProvider});

  final PetProvider petProvider;

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
  final DateTime bornAt;
}

class _TicklePopGameState extends State<TicklePopGame>
    with WidgetsBindingObserver, GameLifecycle<TicklePopGame> {
  static const Duration _lifetime = Duration(milliseconds: 1400);
  static const int _comboWindowMs = 1100;

  final Random _random = Random();
  final List<_Bubble> _bubbles = <_Bubble>[];

  Size _area = Size.zero;
  Timer? _ticker;
  Timer? _countdown;
  double _spawnCooldown = 0.3;
  int _remaining = GameConfig.ticklePopDurationSeconds;
  int _popped = 0;
  int _combo = 0;
  int _bestCombo = 0;
  DateTime? _lastPop;
  bool _over = false;
  bool _squash = false;
  MiniGameResult? _result;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 16), _tick);
    _countdown = Timer.periodic(const Duration(seconds: 1), _countDown);
  }

  @override
  void dispose() {
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
    if (_over || _area == Size.zero) {
      return;
    }
    const double dt = 0.016;
    final DateTime now = DateTime.now();
    _bubbles.removeWhere(
      (_Bubble bubble) {
        bubble.y -= 26 * dt;
        return now.difference(bubble.bornAt) >= _lifetime;
      },
    );

    _spawnCooldown -= dt;
    if (_spawnCooldown <= 0) {
      _spawnBubble();
      _spawnCooldown =
          0.5 - (1 - _remaining / GameConfig.ticklePopDurationSeconds) * 0.2;
    }

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
        bornAt: DateTime.now(),
      ),
    );
  }

  void _pop(_Bubble bubble) {
    final DateTime now = DateTime.now();
    final bool chained =
        _lastPop != null &&
        now.difference(_lastPop!).inMilliseconds < _comboWindowMs;
    _combo = chained ? _combo + 1 : 1;
    _bestCombo = max(_bestCombo, _combo);
    _lastPop = now;
    _popped++;
    _squash = true;
    HapticFeedback.lightImpact();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() => _squash = false);
      }
    });
    setState(() => _bubbles.remove(bubble));
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
    setState(() {
      _bubbles.clear();
      _remaining = GameConfig.ticklePopDurationSeconds;
      _popped = 0;
      _combo = 0;
      _bestCombo = 0;
      _lastPop = null;
      _over = false;
      _result = null;
      _spawnCooldown = 0.3;
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
      hud: Row(
        mainAxisSize: MainAxisSize.min,
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
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        MochiPalette.lavender.withValues(alpha: 0.5),
                        Colors.white,
                      ],
                    ),
                  ),
                ),
              ),
              Center(child: MochiGameBlob(size: 120, squash: _squash)),
              for (final _Bubble bubble in _bubbles)
                Positioned(
                  left: bubble.x,
                  top: bubble.y,
                  child: GestureDetector(
                    onTap: () => _pop(bubble),
                    child: _BubbleView(bubble: bubble),
                  ),
                ),
              if (gamePaused && !_over)
                const Positioned.fill(child: GamePausedOverlay()),
              if (_over)
                Positioned.fill(
                  child: GameResultCard(
                    emoji: '🫧',
                    headline: _bestCombo >= 8
                        ? 'Mochi is extra wiggly!'
                        : 'Tickle time done',
                    accent: MochiPalette.lavender,
                    lines: <String>[
                      'Popped $_popped bubbles · best combo x$_bestCombo',
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
        '+${result.xpAwarded} XP · Mochi is delighted${result.foodSuffix}',
      MiniGameOutcome.dailyCapReached =>
        'Daily play bonus used up. Still fun though!',
      MiniGameOutcome.cooldown => 'On cooldown. No XP this time.',
    };
  }
}

class _BubbleView extends StatelessWidget {
  const _BubbleView({required this.bubble});

  final _Bubble bubble;

  @override
  Widget build(BuildContext context) {
    final double ageMs =
        DateTime.now().difference(bubble.bornAt).inMilliseconds.toDouble();
    final double life = (1 - ageMs / 1400).clamp(0.0, 1.0);
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
