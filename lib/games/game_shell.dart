import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../widgets/pet_sprite.dart';

String formatGameClock(int seconds) {
  final int safe = seconds < 0 ? 0 : seconds;
  final int minutes = safe ~/ 60;
  final int secs = safe % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

/// Shared chrome for the mini-games: back button, title, live HUD, and a
/// full-bleed play area. Keeps the three games visually consistent.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.emoji,
    required this.accent,
    required this.hud,
    required this.child,
    required this.onQuit,
    required this.instructions,
    required this.started,
    required this.onStart,
    required this.onPause,
    required this.pet,
  });

  final String title;
  final String emoji;
  final Color accent;
  final Widget hud;
  final Widget child;
  final VoidCallback onQuit;
  final String instructions;
  final bool started;
  final VoidCallback onStart;
  final VoidCallback? onPause;
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MochiPalette.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: onQuit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Leave game',
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: started ? onPause : null,
                    tooltip: 'Pause game',
                    icon: const Icon(Icons.pause_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: hud,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: pixelCardDecoration(accent),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(child: child),
                      if (!started)
                        Positioned.fill(
                          child: ColoredBox(
                            color: MochiPalette.background.withValues(
                              alpha: 0.96,
                            ),
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    MochiGameSprite(size: 140, pet: pet),
                                    const SizedBox(height: 16),
                                    Text(
                                      title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      instructions,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton(
                                      onPressed: onStart,
                                      child: const Text('Start'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameHudPill extends StatelessWidget {
  const GameHudPill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? MochiPalette.cloudBlue).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: MochiPalette.ink),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

/// Result overlay shown when a run ends. [xpLine] and [extraLines] describe the
/// reward; the reward itself is always recorded through the repository.
class GameResultCard extends StatelessWidget {
  const GameResultCard({
    super.key,
    required this.emoji,
    required this.headline,
    required this.lines,
    required this.accent,
    required this.onReplay,
    required this.onDone,
    this.replayLabel = 'Play again',
    this.pet,
    this.ready = true,
  });

  final String emoji;
  final String headline;
  final List<String> lines;
  final Color accent;
  final VoidCallback onReplay;
  final VoidCallback onDone;
  final String replayLabel;
  final Pet? pet;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MochiPalette.ink.withValues(alpha: 0.28),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: pixelCardDecoration(accent),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  MochiGameSprite(size: 100, pet: pet, mood: MochiMood.happy),
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final String line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDone,
                          child: const Text('Done'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: ready ? onReplay : null,
                          child: Text(replayLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cropped to the creature so movement and collisions follow visible artwork.
class MochiGameSprite extends StatelessWidget {
  const MochiGameSprite({
    super.key,
    required this.size,
    this.mood = MochiMood.laughing,
    this.squash = false,
    this.pet,
  });

  final double size;
  final MochiMood mood;
  final bool squash;
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: squash && !MediaQuery.disableAnimationsOf(context) ? 0.86 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: SizedBox(
        width: size,
        height: size,
        child: Semantics(
          label: 'Mochi',
          image: true,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: size * 1.8,
              maxHeight: size * 1.8,
              child: Image.asset(
                mochiSpriteAsset(
                  (pet ??
                          const Pet(
                            id: 0,
                            name: 'Mochi',
                            stageNumber: 3,
                            xp: 0,
                            mood: MochiMood.normal,
                            moodScore: 60,
                          ))
                      .copyWith(mood: mood),
                ),
                width: size * 1.8,
                height: size * 1.8,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GameScene extends StatelessWidget {
  const GameScene({super.key, this.picnic = false});
  final bool picnic;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _GameScenePainter(picnic)));
}

class _GameScenePainter extends CustomPainter {
  _GameScenePainter(this.picnic);
  final bool picnic;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();
    canvas.drawRect(
      Offset.zero & size,
      paint..color = picnic ? MochiPalette.cloudBlue : MochiPalette.lavender,
    );
    if (picnic) {
      for (final Offset cloud in <Offset>[
        Offset(size.width * 0.15, 85),
        Offset(size.width * 0.75, 145),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: cloud, width: 90, height: 22),
            const Radius.circular(12),
          ),
          paint..color = Colors.white.withValues(alpha: 0.8),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: cloud - const Offset(0, 12),
              width: 50,
              height: 22,
            ),
            const Radius.circular(12),
          ),
          paint,
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - 38, size.width, 38),
        paint..color = MochiPalette.mint,
      );
      canvas.drawLine(
        Offset(0, size.height - 38),
        Offset(size.width, size.height - 38),
        paint
          ..color = MochiPalette.ink.withValues(alpha: 0.15)
          ..strokeWidth = 2,
      );
    } else {
      paint
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (int i = 0; i < 7; i++) {
        canvas.drawCircle(
          Offset(
            size.width * ((i * 0.37) % 1),
            size.height * ((i * 0.23 + 0.1) % 1),
          ),
          20 + i * 5,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GameScenePainter oldDelegate) =>
      picnic != oldDelegate.picnic;
}

/// Pauses a game's timers while the app is backgrounded. Games wire
/// [onGamePause]/[onGameResume] to cancel and restart their own timers.
mixin GameLifecycle<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  bool _gamePaused = false;
  bool gameStarted = false;
  bool get gameActive => gameStarted && !_gamePaused;

  void startGame() {
    setState(() {
      gameStarted = true;
      _gamePaused = false;
    });
    onGameResume();
  }

  void toggleGamePause() {
    if (!gameStarted) return;
    setState(() => _gamePaused = !_gamePaused);
    if (_gamePaused) {
      onGamePause();
    } else {
      onGameResume();
    }
  }

  bool get gamePaused => _gamePaused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      if (_gamePaused || !gameStarted) {
        return;
      }
      _gamePaused = true;
      onGamePause();
    } else if (state == AppLifecycleState.resumed) {
      return;
    } else {
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void onGamePause();

  void onGameResume();
}

/// Dimmed overlay shown while a game is paused by the OS.
class GamePausedOverlay extends StatelessWidget {
  const GamePausedOverlay({super.key, required this.onResume});
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MochiPalette.ink.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: pixelCardDecoration(MochiPalette.yellow),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.pause_circle_rounded, size: 34),
              const SizedBox(height: 6),
              Text('Paused', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton(onPressed: onResume, child: const Text('Resume')),
            ],
          ),
        ),
      ),
    );
  }
}
