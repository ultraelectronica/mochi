import 'pet.dart';

enum Food { mochiBite, strawberryDaifuku, onigiri, matchaTea, ramen }

Food foodFromString(String raw) {
  return Food.values.firstWhere(
    (Food food) => food.name == raw,
    orElse: () => Food.mochiBite,
  );
}

extension FoodData on Food {
  String get asset => switch (this) {
    Food.mochiBite => 'assets/foods/svg/dango.svg',
    Food.strawberryDaifuku => 'assets/foods/svg/strawberry_daifuku.svg',
    Food.onigiri => 'assets/foods/svg/onigiri.svg',
    Food.matchaTea => 'assets/foods/svg/matcha_tea.svg',
    Food.ramen => 'assets/foods/svg/ramen.svg',
  };

  String get label => switch (this) {
    Food.mochiBite => 'Mochi bite',
    Food.strawberryDaifuku => 'Strawberry daifuku',
    Food.onigiri => 'Onigiri',
    Food.matchaTea => 'Matcha tea',
    Food.ramen => 'Ramen',
  };

  String get blurb => switch (this) {
    Food.mochiBite => 'A soft staple bite. Always a good idea.',
    Food.strawberryDaifuku => 'A sweet treat. Big happiness, small fill.',
    Food.onigiri => 'A hearty rice triangle. Solid and filling.',
    Food.matchaTea => 'A warm, calm sip. Cozy and gentle.',
    Food.ramen => 'A whole cozy feast for a growing Mochi.',
  };

  String get emoji => switch (this) {
    Food.mochiBite => '🍡',
    Food.strawberryDaifuku => '🍓',
    Food.onigiri => '🍙',
    Food.matchaTea => '🍵',
    Food.ramen => '🍜',
  };

  int get satietyGain => switch (this) {
    Food.mochiBite => 20,
    Food.strawberryDaifuku => 12,
    Food.onigiri => 35,
    Food.matchaTea => 8,
    Food.ramen => 50,
  };

  int get moodGain => switch (this) {
    Food.mochiBite => 5,
    Food.strawberryDaifuku => 15,
    Food.onigiri => 3,
    Food.matchaTea => 8,
    Food.ramen => 8,
  };

  int get xpAward => switch (this) {
    Food.mochiBite => 3,
    Food.strawberryDaifuku => 5,
    Food.onigiri => 4,
    Food.matchaTea => 2,
    Food.ramen => 6,
  };

  PetStage get unlockStage =>
      this == Food.ramen ? PetStage.pup : PetStage.hatchling;
}

enum FeedOutcome { success, cooldown, full, locked }

class FeedResult {
  const FeedResult({
    required this.outcome,
    this.xpAwarded = 0,
    this.satietyAfter,
  });

  const FeedResult.success({required this.xpAwarded, required this.satietyAfter})
    : outcome = FeedOutcome.success;

  const FeedResult.cooldown() : this(outcome: FeedOutcome.cooldown);

  const FeedResult.full() : this(outcome: FeedOutcome.full);

  const FeedResult.locked() : this(outcome: FeedOutcome.locked);

  final FeedOutcome outcome;
  final int xpAwarded;
  final int? satietyAfter;

  bool get success => outcome == FeedOutcome.success;
}
