import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../games/mood_match_game.dart';
import '../games/mini_game.dart';
import '../games/snack_catch_game.dart';
import '../games/tickle_pop_game.dart';
import '../games/game_shell.dart';
import '../models/pet.dart';
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final int playsToday = petProvider.dailyMiniGamePlays();
    final int playsLeft = (GameConfig.miniGameDailyCap - playsToday).clamp(
      0,
      GameConfig.miniGameDailyCap,
    );
    final int cooldown = petProvider.miniGameCooldownRemaining();
    final int foodLeft = petProvider.gameFoodRemaining();
    final Map<MiniGame, int> best = petProvider.miniGameBestScores();

    final String status = cooldown > 0
        ? 'XP is resting · ready in ${cooldown}s'
        : playsLeft > 0
        ? '$playsLeft of ${GameConfig.miniGameDailyCap} XP plays left today'
        : 'Daily XP plays used up — games stay free to play';
    final String foodStatus = foodLeft > 0
        ? '$foodLeft of ${GameConfig.gameFoodDailyCap} food treats left today · '
              'even while XP rests'
        : 'Today\'s game treats collected · more tomorrow';

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
            'Your Mochi. Three little adventures.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MochiPalette.ink.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(foodStatus, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          for (final MiniGame game in MiniGame.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GameRow(
                game: game,
                bestScore: best[game] ?? 0,
                pet: petProvider.pet,
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
    required this.pet,
  });

  final MiniGame game;
  final int bestScore;
  final VoidCallback onPlay;
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (game) {
      MiniGame.snackCatch => MochiPalette.peach,
      MiniGame.ticklePop => MochiPalette.lavender,
      MiniGame.moodMatch => MochiPalette.mint,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _GamePreview(game: game, pet: pet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${game.emoji} ${game.label}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(switch (game) {
                      MiniGame.snackCatch => 'Drag, catch, snack!',
                      MiniGame.ticklePop => 'Move Mochi. Chase bubbles.',
                      MiniGame.moodMatch => 'Find Mochi’s matching moods.',
                    }, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Best: $bestScore · ${switch (game) {
                    MiniGame.snackCatch => '60s',
                    MiniGame.ticklePop => '30s',
                    MiniGame.moodMatch => '90s',
                  }}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MochiPalette.ink.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Text('Play'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GamePreview extends StatelessWidget {
  const _GamePreview({required this.game, required this.pet});
  final MiniGame game;
  final Pet? pet;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 80,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: <Widget>[
          if (game != MiniGame.moodMatch)
            Positioned.fill(
              child: GameScene(picnic: game == MiniGame.snackCatch),
            ),
          Positioned(
            left: 14,
            bottom: -4,
            child: MochiGameSprite(size: 58, pet: pet),
          ),
          if (game == MiniGame.snackCatch) ...<Widget>[
            const Positioned(
              left: 6,
              top: 8,
              child: Text('🍙', style: TextStyle(fontSize: 22)),
            ),
            const Positioned(
              right: 4,
              top: 4,
              child: Text('🍓', style: TextStyle(fontSize: 20)),
            ),
          ],
          if (game == MiniGame.ticklePop)
            for (final offset in <Offset>[
              const Offset(4, 8),
              const Offset(56, 14),
            ])
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                    border: Border.all(color: MochiPalette.ink, width: 2),
                  ),
                ),
              ),
          if (game == MiniGame.moodMatch)
            const Positioned(
              top: 4,
              left: 26,
              child: Icon(
                Icons.favorite_rounded,
                size: 30,
                color: MochiPalette.ink,
              ),
            ),
        ],
      ),
    ),
  );
}
