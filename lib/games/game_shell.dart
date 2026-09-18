import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/mood.dart';

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
  });

  final String title;
  final String emoji;
  final Color accent;
  final Widget hud;
  final Widget child;
  final VoidCallback onQuit;

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
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  hud,
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: pixelCardDecoration(accent),
                  clipBehavior: Clip.antiAlias,
                  child: child,
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
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
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
  });

  final String emoji;
  final String headline;
  final List<String> lines;
  final Color accent;
  final VoidCallback onReplay;
  final VoidCallback onDone;
  final String replayLabel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MochiPalette.ink.withValues(alpha: 0.28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: pixelCardDecoration(accent),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(emoji, style: const TextStyle(fontSize: 44)),
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
                        onPressed: onReplay,
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
    );
  }
}

/// A soft Mochi-ish paddle/creature used by the reflex games.
class MochiGameBlob extends StatelessWidget {
  const MochiGameBlob({
    super.key,
    required this.size,
    this.mood = MochiMood.laughing,
    this.squash = false,
  });

  final double size;
  final MochiMood mood;
  final bool squash;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: squash ? 0.86 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: mood.color,
          shape: BoxShape.circle,
          border: Border.all(color: MochiPalette.ink, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: MochiPalette.ink.withValues(alpha: 0.2),
              offset: const Offset(3, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Icon(mood.icon, size: size * 0.44, color: MochiPalette.ink),
        ),
      ),
    );
  }
}

/// Pauses a game's timers while the app is backgrounded. Games wire
/// [onGamePause]/[onGameResume] to cancel and restart their own timers.
mixin GameLifecycle<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  bool _gamePaused = false;

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
    if (state == AppLifecycleState.paused) {
      if (_gamePaused) {
        return;
      }
      _gamePaused = true;
      onGamePause();
    } else if (state == AppLifecycleState.resumed) {
      if (!_gamePaused) {
        return;
      }
      _gamePaused = false;
      onGameResume();
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
  const GamePausedOverlay({super.key});

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
            ],
          ),
        ),
      ),
    );
  }
}

