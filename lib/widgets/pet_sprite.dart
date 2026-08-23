import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/mood.dart';
import '../models/pet.dart';

String mochiSpriteAsset(Pet pet) {
  if (pet.stage == PetStage.egg) {
    return 'assets/mochi/png/mochi_egg.png';
  }

  if (pet.stage == PetStage.hatchling) {
    return switch (pet.mood) {
      MochiMood.happy ||
      MochiMood.laughing => 'assets/mochi/png/baby_mochi_happy.png',
      MochiMood.sad ||
      MochiMood.scared ||
      MochiMood.angry => 'assets/mochi/png/baby_mochi_sad.png',
      MochiMood.tired => 'assets/mochi/png/baby_mochi_crying.png',
      _ => 'assets/mochi/png/baby_mochi_normal.png',
    };
  }

  return switch (pet.mood) {
    MochiMood.happy => 'assets/mochi/png/mochi_happy.png',
    MochiMood.laughing => 'assets/mochi/png/mochi_laughing.png',
    MochiMood.normal => 'assets/mochi/png/mochi_normal.png',
    MochiMood.tired => 'assets/mochi/png/mochi_tired.png',
    MochiMood.sad => 'assets/mochi/png/mochi_sad.png',
    MochiMood.angry => 'assets/mochi/png/mochi_angry.png',
    MochiMood.scared => 'assets/mochi/png/mochi_scared.png',
    MochiMood.hungry => 'assets/mochi/png/mochi_hungry.png',
    MochiMood.confused => 'assets/mochi/png/mochi_confused.png',
  };
}

class PetSprite extends StatefulWidget {
  const PetSprite({super.key, required this.pet, this.size = 264, this.onTap});

  final Pet pet;
  final double size;
  final VoidCallback? onTap;

  @override
  State<PetSprite> createState() => _PetSpriteState();
}

class _PetSpriteState extends State<PetSprite>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  late final AnimationController _tapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _tapScale = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 0.92).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.92, end: 1.08).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 35,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.08, end: 1).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 35,
      ),
    ],
  ).animate(_tapController);

  @override
  void dispose() {
    _controller.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) {
      return;
    }
    _tapController.forward(from: 0);
    widget.onTap!.call();
  }

  double _bobAmount() {
    return switch (widget.pet.mood) {
      MochiMood.tired => 4,
      MochiMood.angry => 5,
      MochiMood.scared => 6,
      MochiMood.laughing => 12,
      MochiMood.happy => 10,
      _ => 8,
    };
  }

  double _tiltAmount() {
    return switch (widget.pet.mood) {
      MochiMood.scared => 0.06,
      MochiMood.angry => 0.05,
      MochiMood.tired => 0.02,
      MochiMood.laughing => 0.08,
      _ => 0.04,
    };
  }

  @override
  Widget build(BuildContext context) {
    final String assetPath = mochiSpriteAsset(widget.pet);

    // Keep motion on transforms so the sprite stays smooth on high refresh screens.
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_controller, _tapController]),
          child: Image.asset(
            assetPath,
            width: widget.size,
            height: widget.size,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
          ),
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value * math.pi * 2;
            final double bob = math.sin(t) * _bobAmount();
            final double tilt = math.sin(t * 0.5) * _tiltAmount();
            final double pulse = (1 + (math.sin(t) * 0.015)) * _tapScale.value;
            final double sparkleShift = math.cos(t) * 10;

            return SizedBox(
              width: widget.size + 80,
              height: widget.size + 84,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    bottom: 16,
                    child: Container(
                      width: widget.size * 0.52,
                      height: 24,
                      decoration: BoxDecoration(
                        color: MochiPalette.ink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18 + sparkleShift * 0.18,
                    right: 26,
                    child: const _Sparkle(color: MochiPalette.yellow, size: 16),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 18 + sparkleShift * 0.28,
                    child: const _Sparkle(
                      color: MochiPalette.lightPink,
                      size: 14,
                    ),
                  ),
                  Positioned(
                    top: 48,
                    left: 30,
                    child: const _Sparkle(
                      color: MochiPalette.cloudBlue,
                      size: 12,
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, bob),
                    child: Transform.rotate(
                      angle: tilt,
                      child: Transform.scale(scale: pulse, child: child),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MochiPalette.ink, width: 1.5),
      ),
    );
  }
}
