import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../games/mood_match_game.dart';
import '../games/mini_game.dart';
import '../games/snack_catch_game.dart';
import '../games/tickle_pop_game.dart';
import '../providers/pet_provider.dart';

/// Home entry point for the three mini-games. Games stay a side dish: a small
/// XP top-up with a shared daily cap and cooldown handled by the repository.
class PlayPanel extends StatelessWidget {
  const PlayPanel({super.key, required this.petProvider});

  final PetProvider petProvider;

  void _open(BuildContext context, MiniGame game) {
    final Widget screen = switch (game) {
      MiniGame.snackCatch => SnackCatchGame(petProvider: petProvider),
      MiniGame.ticklePop => TicklePopGame(petProvider: petProvider),
      MiniGame.moodMatch => MoodMatchGame(petProvider: petProvider),
    };
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int playsToday = petProvider.dailyMiniGamePlays();
    final int playsLeft = (GameConfig.miniGameDailyCap - playsToday).clamp(
      0,
      GameConfig.miniGameDailyCap,
    );
    final int cooldown = petProvider.miniGameCooldownRemaining();
    final Map<MiniGame, int> best = petProvider.miniGameBestScores();

    final String status = cooldown > 0
        ? 'On reward cooldown · ready in ${cooldown}s'
        : playsLeft > 0
        ? '$playsLeft of ${GameConfig.miniGameDailyCap} reward plays left today'
        : 'Daily reward plays used up — games stay free to play';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: pixelCardDecoration(MochiPalette.mint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🎮', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                'Play with Mochi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tiny games, tiny treats. Chat is still the best way to grow.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MochiPalette.ink.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 12),
          for (final MiniGame game in MiniGame.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GameRow(
                game: game,
                bestScore: best[game] ?? 0,
                onPlay: () => _open(context, game),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.bestScore,
    required this.onPlay,
  });

  final MiniGame game;
  final int bestScore;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MochiPalette.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: MochiPalette.cloudBlue.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: Center(
              child: Text(game.emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  game.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  game.blurb,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Best: $bestScore',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MochiPalette.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onPlay,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }
}
