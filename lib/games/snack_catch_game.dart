import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../models/food.dart';
import '../models/mood.dart';
import '../providers/pet_provider.dart';
import 'game_shell.dart';
import 'mini_game.dart';

class SnackCatchGame extends StatefulWidget {
  const SnackCatchGame({super.key, required this.petProvider});

  final PetProvider petProvider;

  @override
  State<SnackCatchGame> createState() => _SnackCatchGameState();
}

class _FallingItem {
  _FallingItem({
    required this.x,
    required this.y,
    required this.speed,
    required this.good,
    required this.emoji,
  });

  double x;
  double y;
  double speed;
  final bool good;
  final String emoji;
}

class _SnackCatchGameState extends State<SnackCatchGame>
    with WidgetsBindingObserver, GameLifecycle<SnackCatchGame> {
  static const double _itemSize = 42;
  static const double _mochiHeight = 88;
  static const double _mochiBottomGap = 28;
  static const List<String> _trash = <String>['🧦', '🗑️', '🪨'];

  final Random _random = Random();
  final List<_FallingItem> _items = <_FallingItem>[];

  Size _area = Size.zero;
  Timer? _ticker;
  Timer? _countdown;
  Timer? _squashTimer;
  double _mochiX = 0;
  bool _mochiPlaced = false;
  double _spawnCooldown = 0.6;
  int _remaining = GameConfig.snackCatchDurationSeconds;
  int _lives = GameConfig.snackCatchLives;
  int _score = 0;
  int _catches = 0;
  bool _over = false;
  bool _squash = false;
  MiniGameResult? _result;
  String? _feedback;
  double _feedbackTime = 0;
  bool _hurt = false;

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
    if (_over || !gameActive) {
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

  double get _mochiWidth => _mochiHeight;

  void _tick(Timer timer) {
    if (_over || !gameActive || _area == Size.zero) {
      return;
    }
    const double dt = 0.016;
    _feedbackTime = max(0, _feedbackTime - dt);
    if (_feedbackTime == 0) {
      _feedback = null;
      _hurt = false;
    }
    final double mochiTop = _area.height - _mochiHeight - _mochiBottomGap;

    _items.removeWhere((_FallingItem item) {
      item.y += item.speed * dt;
      final double centerX = item.x + _itemSize / 2;
      final bool caught =
          item.y + _itemSize >= mochiTop &&
          item.y + _itemSize <= _area.height - _mochiBottomGap + 6 &&
          centerX >= _mochiX &&
          centerX <= _mochiX + _mochiWidth;

      if (caught) {
        _resolveCatch(item);
        return true;
      }
      if (item.y > _area.height) {
        if (item.good) {
          _loseLife();
        }
        return true;
      }
      return false;
    });

    if (_over) {
      return;
    }

    _spawnCooldown -= dt;
    if (_spawnCooldown <= 0) {
      _spawnItem();
      final double progress =
          1 - _remaining / GameConfig.snackCatchDurationSeconds;
      _spawnCooldown = 0.85 - progress * 0.35;
    }

    setState(() {});
  }

  void _spawnItem() {
    final bool good = _random.nextDouble() > 0.28;
    final double x = _random.nextDouble() * (_area.width - _itemSize);
    final String emoji = good
        ? Food.values[_random.nextInt(Food.values.length)].emoji
        : _trash[_random.nextInt(_trash.length)];
    _items.add(
      _FallingItem(
        x: x,
        y: -_itemSize,
        speed: 130 + _random.nextDouble() * 90,
        good: good,
        emoji: emoji,
      ),
    );
  }

  void _resolveCatch(_FallingItem item) {
    if (item.good) {
      _score += 10;
      _catches++;
      _feedback = '+10';
      _feedbackTime = 0.6;
      _hurt = false;
      _squash = true;
      HapticFeedback.selectionClick();
      _squashTimer?.cancel();
      _squashTimer = Timer(const Duration(milliseconds: 130), () {
        if (mounted) {
          setState(() => _squash = false);
        }
      });
    } else {
      _loseLife();
    }
  }

  void _loseLife() {
    if (_over) return;
    _feedback = 'Oops!';
    _feedbackTime = 0.6;
    _hurt = true;
    _lives--;
    HapticFeedback.mediumImpact();
    if (_lives <= 0) {
      _lives = 0;
      _finish();
    }
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
      game: MiniGame.snackCatch,
      score: _score,
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
      _items.clear();
      _remaining = GameConfig.snackCatchDurationSeconds;
      _lives = GameConfig.snackCatchLives;
      _score = 0;
      _catches = 0;
      _over = false;
      _result = null;
      _spawnCooldown = 0.6;
      _mochiPlaced = false;
      _feedback = null;
      _hurt = false;
      _squash = false;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 16), _tick);
    _countdown = Timer.periodic(const Duration(seconds: 1), _countDown);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Snack Catch',
      emoji: '🍡',
      accent: MochiPalette.peach,
      onQuit: () => Navigator.of(context).pop(),
      pet: widget.petProvider.pet,
      instructions:
          'Drag Mochi left and right to catch snacks. Dodge the trash! You have three hearts and one minute.',
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
            icon: Icons.favorite_rounded,
            label: '$_lives',
            color: MochiPalette.lightPink,
          ),
          GameHudPill(icon: Icons.stars_rounded, label: '$_score'),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _area = Size(constraints.maxWidth, constraints.maxHeight);
          if (!_mochiPlaced) {
            _mochiX = (_area.width - _mochiWidth) / 2;
            _mochiPlaced = true;
          }
          final double mochiTop = _area.height - _mochiHeight - _mochiBottomGap;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              if (_over || !gameActive) {
                return;
              }
              setState(() {
                _mochiX = (_mochiX + details.delta.dx).clamp(
                  0.0,
                  _area.width - _mochiWidth,
                );
              });
            },
            onTapDown: (TapDownDetails details) {
              if (_over || !gameActive) {
                return;
              }
              setState(() {
                _mochiX = (details.localPosition.dx - _mochiWidth / 2).clamp(
                  0.0,
                  _area.width - _mochiWidth,
                );
              });
            },
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: GameScene(picnic: true)),
                Positioned(
                  top: 18,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Text(
                      'Catch snacks · dodge trash',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                for (final _FallingItem item in _items)
                  Positioned(
                    left: item.x,
                    top: item.y,
                    child: Text(
                      item.emoji,
                      style: const TextStyle(fontSize: _itemSize),
                    ),
                  ),
                Positioned(
                  left: _mochiX,
                  top: mochiTop,
                  child: SizedBox(
                    width: _mochiWidth,
                    height: _mochiHeight,
                    child: Center(
                      child: MochiGameSprite(
                        size: _mochiHeight,
                        squash: _squash,
                        pet: widget.petProvider.pet,
                        mood: _hurt ? MochiMood.scared : MochiMood.happy,
                      ),
                    ),
                  ),
                ),
                if (_feedback != null)
                  Positioned(
                    left: _mochiX,
                    top: mochiTop - 30,
                    child: IgnorePointer(
                      child: Text(
                        _feedback!,
                        style: Theme.of(context).textTheme.titleLarge,
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
                      emoji: '🍡',
                      headline: _score >= 150
                          ? 'Snack champion!'
                          : 'Playtime over',
                      accent: MochiPalette.peach,
                      lines: <String>[
                        'Caught $_catches snacks · score $_score',
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
        '+${result.xpAwarded} XP · Satiety ${result.satietyAfter}%',
      MiniGameOutcome.dailyCapReached ||
      MiniGameOutcome.cooldown => result.xpRestLine,
    };
  }
}
