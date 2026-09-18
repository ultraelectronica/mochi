import '../config/game_config.dart';
import 'mini_game.dart';

/// Raw XP a finished run is worth before the pet's mood modifier is applied.
///
/// Games deliberately stay under [GameConfig.xpPerChat] so chatting remains the
/// primary growth path. Every branch clamps to
/// [GameConfig.xpPerMiniGameMax] and floors at 0.
int miniGameXpForScore(
  MiniGame game, {
  int score = 0,
  int bestCombo = 0,
  int moves = 0,
  bool finished = true,
}) {
  final int raw = switch (game) {
    MiniGame.snackCatch => 2 + (score < 0 ? 0 : score) ~/ 25,
    MiniGame.ticklePop => 2 + (bestCombo < 0 ? 0 : bestCombo) ~/ 2,
    MiniGame.moodMatch => finished
        ? _moodMatchXp(moves)
        : 1,
  };
  return raw.clamp(0, GameConfig.xpPerMiniGameMax);
}

int _moodMatchXp(int moves) {
  final int overPar = (moves - GameConfig.moodMatchParMoves).clamp(0, 100);
  final int xp = GameConfig.xpPerMiniGameMax - overPar ~/ 2;
  return xp < 3 ? 3 : xp;
}
