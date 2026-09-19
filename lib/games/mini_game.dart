import 'package:flutter/material.dart';

import '../models/food.dart';

enum MiniGame { snackCatch, ticklePop, moodMatch }

MiniGame miniGameFromString(String raw) {
  return MiniGame.values.firstWhere(
    (MiniGame game) => game.name == raw,
    orElse: () => MiniGame.snackCatch,
  );
}

extension MiniGameData on MiniGame {
  String get label => switch (this) {
    MiniGame.snackCatch => 'Snack Catch',
    MiniGame.ticklePop => 'Tickle Pop',
    MiniGame.moodMatch => 'Mood Match',
  };

  String get blurb => switch (this) {
    MiniGame.snackCatch => 'Catch falling snacks, dodge the trash.',
    MiniGame.ticklePop => 'Pop bubbles around Mochi for combos.',
    MiniGame.moodMatch => 'Flip mood pairs at a calm pace.',
  };

  String get emoji => switch (this) {
    MiniGame.snackCatch => '🍡',
    MiniGame.ticklePop => '🫧',
    MiniGame.moodMatch => '🃏',
  };

  IconData get icon => switch (this) {
    MiniGame.snackCatch => Icons.restaurant_rounded,
    MiniGame.ticklePop => Icons.bubble_chart_rounded,
    MiniGame.moodMatch => Icons.style_rounded,
  };
}

enum MiniGameOutcome { rewarded, dailyCapReached, cooldown }

class MiniGameResult {
  const MiniGameResult({
    required this.outcome,
    this.xpAwarded = 0,
    this.satietyAfter,
    this.playsRemaining = 0,
    this.foodAwarded,
  });

  final MiniGameOutcome outcome;
  final int xpAwarded;
  final int? satietyAfter;
  final int playsRemaining;
  final Food? foodAwarded;

  bool get rewarded => outcome == MiniGameOutcome.rewarded;
}

extension MiniGameResultData on MiniGameResult {
  /// Result-card suffix for an earned pantry item, e.g. ` · +1 🍙 Onigiri`.
  String get foodSuffix => foodAwarded == null
      ? ''
      : ' · +1 ${foodAwarded!.emoji} ${foodAwarded!.label}';
}
