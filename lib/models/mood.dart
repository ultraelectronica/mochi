import 'package:flutter/material.dart';

enum MochiMood {
  happy,
  laughing,
  normal,
  tired,
  sad,
  angry,
  scared,
  hungry,
  confused,
}

MochiMood mochiMoodFromString(String raw) {
  return MochiMood.values.firstWhere(
    (MochiMood mood) => mood.name == raw,
    orElse: () => MochiMood.normal,
  );
}

extension MochiMoodData on MochiMood {
  String get label => switch (this) {
    MochiMood.happy => 'Happy',
    MochiMood.laughing => 'Laughing',
    MochiMood.normal => 'Normal',
    MochiMood.tired => 'Tired',
    MochiMood.sad => 'Sad',
    MochiMood.angry => 'Angry',
    MochiMood.scared => 'Scared',
    MochiMood.hungry => 'Hungry',
    MochiMood.confused => 'Confused',
  };

  IconData get icon => switch (this) {
    MochiMood.happy => Icons.wb_sunny_rounded,
    MochiMood.laughing => Icons.sentiment_very_satisfied_rounded,
    MochiMood.normal => Icons.adjust_rounded,
    MochiMood.tired => Icons.hotel_rounded,
    MochiMood.sad => Icons.cloud_rounded,
    MochiMood.angry => Icons.local_fire_department_rounded,
    MochiMood.scared => Icons.flash_on_rounded,
    MochiMood.hungry => Icons.cookie_rounded,
    MochiMood.confused => Icons.question_mark_rounded,
  };

  Color get color => switch (this) {
    MochiMood.happy => const Color(0xFF8FD29F),
    MochiMood.laughing => const Color(0xFF6ED7C8),
    MochiMood.normal => const Color(0xFFB6BBD0),
    MochiMood.tired => const Color(0xFFB4A6F4),
    MochiMood.sad => const Color(0xFF7EB8F3),
    MochiMood.angry => const Color(0xFFFF8D7A),
    MochiMood.scared => const Color(0xFFFF93C6),
    MochiMood.hungry => const Color(0xFFFFB36C),
    MochiMood.confused => const Color(0xFFFFD86D),
  };

  Color get tint => color.withValues(alpha: 0.22);

  String get note => switch (this) {
    MochiMood.happy => 'Bright replies and buoyant little hops.',
    MochiMood.laughing => 'Playful energy with extra bounce.',
    MochiMood.normal => 'Steady, warm, and ready to listen.',
    MochiMood.tired => 'Slower motion and cozy responses.',
    MochiMood.sad => 'Soft tone, wants the family close.',
    MochiMood.angry => 'Sharp edges, needs a gentle reset.',
    MochiMood.scared => 'Tiny shivers and a need for reassurance.',
    MochiMood.hungry => 'Food hints, curious sniffing, restless wiggles.',
    MochiMood.confused => 'Head tilts and lots of wondering.',
  };

  String get reaction => switch (this) {
    MochiMood.happy => 'I saved a warm little smile for you.',
    MochiMood.laughing => 'That tickles. I feel extra sparkly today.',
    MochiMood.normal => 'I am right here. Tell me your tiny moment.',
    MochiMood.tired => 'Can we keep today soft and slow together?',
    MochiMood.sad => 'Stay close. I like hearing family voices.',
    MochiMood.angry => 'I need a tiny breath, then I can listen better.',
    MochiMood.scared => 'Hold my paw for a second. I will calm down.',
    MochiMood.hungry => 'I could really go for a snack story right now.',
    MochiMood.confused => 'I am still learning this feeling, but I am trying.',
  };
}
