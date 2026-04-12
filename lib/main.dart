import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MochiApp());
}

class MochiApp extends StatelessWidget {
  const MochiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: MochiPalette.cloudBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: MochiPalette.cloudBlue,
          secondary: MochiPalette.lightPink,
          surface: Colors.white,
          onSurface: MochiPalette.ink,
          outline: MochiPalette.ink,
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mochi',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: MochiPalette.background,
        fontFamily: 'Pixelify Sans',
        textTheme: ThemeData.light().textTheme.copyWith(
          headlineMedium: const TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w700,
            height: 1.05,
            color: MochiPalette.ink,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: MochiPalette.ink,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MochiPalette.ink,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: MochiPalette.ink.withValues(alpha: 0.9),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: MochiPalette.ink.withValues(alpha: 0.8),
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MochiPalette.ink,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: MochiPalette.cloudBlue.withValues(alpha: 0.25),
          iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            final bool selected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: selected
                  ? MochiPalette.ink
                  : MochiPalette.ink.withValues(alpha: 0.58),
              size: 22,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((
            Set<WidgetState> states,
          ) {
            final bool selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: 'Pixelify Sans',
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? MochiPalette.ink
                  : MochiPalette.ink.withValues(alpha: 0.6),
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: MochiPalette.cloudBlue,
            foregroundColor: MochiPalette.ink,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(
              fontFamily: 'Pixelify Sans',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: MochiPalette.ink, width: 2.5),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: MochiPalette.ink.withValues(alpha: 0.42)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: MochiPalette.ink, width: 2.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: MochiPalette.ink, width: 3),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: MochiPalette.ink, width: 2.5),
          ),
        ),
      ),
      home: const MochiShell(),
    );
  }
}

class MochiPalette {
  static const Color background = Color(0xFFFFFCF4);
  static const Color card = Colors.white;
  static const Color ink = Color(0xFF28324E);
  static const Color cloudBlue = Color(0xFFD8F0FF);
  static const Color sky = Color(0xFF8CCEFF);
  static const Color lightPink = Color(0xFFFFE0EC);
  static const Color yellow = Color(0xFFFFF0B5);
  static const Color mint = Color(0xFFD8F6E6);
  static const Color lavender = Color(0xFFE3DFFF);
  static const Color peach = Color(0xFFFFDDC9);
}

enum AppTab { home, chat, mood, feed, profile }

extension AppTabLabel on AppTab {
  String get label => switch (this) {
    AppTab.home => 'Home',
    AppTab.chat => 'Chat',
    AppTab.mood => 'Mood',
    AppTab.feed => 'Feed',
    AppTab.profile => 'Profile',
  };

  IconData get icon => switch (this) {
    AppTab.home => Icons.home_rounded,
    AppTab.chat => Icons.chat_bubble_rounded,
    AppTab.mood => Icons.favorite_rounded,
    AppTab.feed => Icons.auto_awesome_motion_rounded,
    AppTab.profile => Icons.pets_rounded,
  };
}

enum PetStage { egg, hatchling, pup, companion, wiseElder }

extension PetStageLabel on PetStage {
  String get label => switch (this) {
    PetStage.egg => 'Egg',
    PetStage.hatchling => 'Hatchling',
    PetStage.pup => 'Pup',
    PetStage.companion => 'Companion',
    PetStage.wiseElder => 'Wise Elder',
  };

  String get note => switch (this) {
    PetStage.egg => 'Still sleeping inside a shared family glow.',
    PetStage.hatchling => 'Tiny feelings, quick reactions, very curious eyes.',
    PetStage.pup => 'Learning family rhythms and playful voice habits.',
    PetStage.companion => 'Warm, expressive, and deeply tuned to the home.',
    PetStage.wiseElder => 'Rich memory, calm presence, and gentle wisdom.',
  };
}

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

  String assetForStage(PetStage stage) {
    if (stage == PetStage.egg) {
      return 'assets/mochi/png/mochi_egg.png';
    }

    if (stage == PetStage.hatchling) {
      return switch (this) {
        MochiMood.happy ||
        MochiMood.laughing => 'assets/mochi/png/baby_mochi_happy.png',
        MochiMood.sad ||
        MochiMood.scared ||
        MochiMood.angry => 'assets/mochi/png/baby_mochi_sad.png',
        MochiMood.tired => 'assets/mochi/png/baby_mochi_crying.png',
        _ => 'assets/mochi/png/baby_mochi_normal.png',
      };
    }

    return switch (this) {
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
}

class FamilyMember {
  const FamilyMember({
    required this.name,
    required this.color,
    required this.affection,
    required this.xp,
    required this.note,
  });

  final String name;
  final Color color;
  final int affection;
  final int xp;
  final String note;

  String get initials {
    final List<String> parts = name.split(' ');
    return parts
        .take(2)
        .map((String part) => part.substring(0, 1).toUpperCase())
        .join();
  }

  FamilyMember copyWith({
    String? name,
    Color? color,
    int? affection,
    int? xp,
    String? note,
  }) {
    return FamilyMember(
      name: name ?? this.name,
      color: color ?? this.color,
      affection: affection ?? this.affection,
      xp: xp ?? this.xp,
      note: note ?? this.note,
    );
  }
}

class ChatEntry {
  const ChatEntry({
    required this.author,
    required this.text,
    required this.isPet,
    required this.timestamp,
  });

  final String author;
  final String text;
  final bool isPet;
  final String timestamp;
}

class ActivityEntry {
  const ActivityEntry({
    required this.title,
    required this.detail,
    required this.timestamp,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String detail;
  final String timestamp;
  final Color accent;
  final IconData icon;
}

class MemorySnippet {
  const MemorySnippet({
    required this.title,
    required this.body,
    required this.timestamp,
    required this.accent,
  });

  final String title;
  final String body;
  final String timestamp;
  final Color accent;
}

class MochiShell extends StatefulWidget {
  const MochiShell({super.key});

  @override
  State<MochiShell> createState() => _MochiShellState();
}

class _MochiShellState extends State<MochiShell> {
  static const Map<PetStage, int> _stageThresholds = <PetStage, int>{
    PetStage.egg: 0,
    PetStage.hatchling: 30,
    PetStage.pup: 90,
    PetStage.companion: 170,
    PetStage.wiseElder: 320,
  };

  late final TextEditingController _chatController;
  late final ScrollController _chatScrollController;
  late List<FamilyMember> _members;
  late List<ChatEntry> _chatEntries;
  late List<ActivityEntry> _feedEntries;
  late List<MemorySnippet> _memories;

  final Map<String, MochiMood> _memberCheckIns = <String, MochiMood>{};

  AppTab _selectedTab = AppTab.home;
  int _selectedMemberIndex = 0;
  int _petXp = 186;
  bool _serverOnline = true;
  bool _ttsEnabled = true;
  bool _notificationsEnabled = true;
  bool _replyPending = false;
  MochiMood _manualMood = MochiMood.happy;

  @override
  void initState() {
    super.initState();
    _chatController = TextEditingController();
    _chatScrollController = ScrollController();
    _members = const <FamilyMember>[
      FamilyMember(
        name: 'Arne',
        color: MochiPalette.sky,
        affection: 88,
        xp: 214,
        note: 'Always sends the first good-morning message.',
      ),
      FamilyMember(
        name: 'Bea',
        color: Color(0xFFFFAFCB),
        affection: 73,
        xp: 178,
        note: 'Keeps Mochi laughing with voice notes.',
      ),
      FamilyMember(
        name: 'Nico',
        color: Color(0xFFFFD466),
        affection: 67,
        xp: 142,
        note: 'Best at mood check-ins after school.',
      ),
      FamilyMember(
        name: 'Lia',
        color: Color(0xFFA9E6BE),
        affection: 59,
        xp: 121,
        note: 'Leaves calm nighttime messages for later.',
      ),
    ];
    _chatEntries = const <ChatEntry>[
      ChatEntry(
        author: 'Mochi',
        text:
            'Hi family. I kept a bright little corner ready for whoever visits first.',
        isPet: true,
        timestamp: '9:08',
      ),
      ChatEntry(
        author: 'Arne',
        text: 'Morning, Mochi. We are all a bit sleepy today.',
        isPet: false,
        timestamp: '9:10',
      ),
      ChatEntry(
        author: 'Mochi',
        text:
            'Then I will stay cozy too. Tiny steps are enough for this morning.',
        isPet: true,
        timestamp: '9:10',
      ),
    ];
    _feedEntries = const <ActivityEntry>[
      ActivityEntry(
        title: 'Arne chatted with Mochi',
        detail: 'The pet replied with a sleepy but warm morning check-in.',
        timestamp: '6m ago',
        accent: MochiPalette.cloudBlue,
        icon: Icons.chat_bubble_rounded,
      ),
      ActivityEntry(
        title: 'Bea checked in as Happy',
        detail: 'Mochi brightened and shifted toward a playful mood.',
        timestamp: '18m ago',
        accent: MochiPalette.lightPink,
        icon: Icons.favorite_rounded,
      ),
      ActivityEntry(
        title: 'Mochi reached Companion stage',
        detail:
            'The family unlocked richer memories and more expressive reactions.',
        timestamp: 'Yesterday',
        accent: MochiPalette.yellow,
        icon: Icons.auto_awesome_rounded,
      ),
    ];
    _memories = const <MemorySnippet>[
      MemorySnippet(
        title: 'Picnic blanket day',
        body:
            'Mochi remembers the yellow blanket, cloud-blue cups, and everyone sitting close together.',
        timestamp: 'Saved 2 days ago',
        accent: MochiPalette.yellow,
      ),
      MemorySnippet(
        title: 'Rainy night voice note',
        body:
            'Lia whispered a bedtime story while the whole house sounded soft and sleepy.',
        timestamp: 'Saved 4 days ago',
        accent: MochiPalette.lightPink,
      ),
      MemorySnippet(
        title: 'After-school snack run',
        body:
            'Nico told Mochi about buns, juice, and a tiny argument that ended in a laugh.',
        timestamp: 'Saved 6 days ago',
        accent: MochiPalette.cloudBlue,
      ),
    ];
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  FamilyMember get _selectedMember => _members[_selectedMemberIndex];

  PetStage get _petStage => _stageForXp(_petXp);

  PetStage? get _nextStage {
    final int index = PetStage.values.indexOf(_petStage);
    if (index == PetStage.values.length - 1) {
      return null;
    }
    return PetStage.values[index + 1];
  }

  MochiMood get _petMood =>
      _memberCheckIns.isEmpty ? _manualMood : _aggregatePetMood();

  double get _stageProgress {
    final PetStage current = _petStage;
    final PetStage? next = _nextStage;
    if (next == null) {
      return 1;
    }
    final int start = _stageThresholds[current]!;
    final int end = _stageThresholds[next]!;
    return ((_petXp - start) / (end - start)).clamp(0, 1).toDouble();
  }

  String get _greeting => switch (_petMood) {
    MochiMood.happy =>
      'Hi ${_selectedMember.name}. I kept the room bright for you.',
    MochiMood.laughing =>
      'Hi ${_selectedMember.name}. I am wiggly today and ready to play.',
    MochiMood.normal =>
      'Hi ${_selectedMember.name}. Tell me the small thing on your mind.',
    MochiMood.tired =>
      'Hi ${_selectedMember.name}. Quiet company sounds perfect right now.',
    MochiMood.sad => 'Hi ${_selectedMember.name}. Stay near me for a minute.',
    MochiMood.angry =>
      'Hi ${_selectedMember.name}. I need a soft reset, but I am still here.',
    MochiMood.scared =>
      'Hi ${_selectedMember.name}. A gentle hello helps a lot.',
    MochiMood.hungry =>
      'Hi ${_selectedMember.name}. I am collecting snack stories today.',
    MochiMood.confused =>
      'Hi ${_selectedMember.name}. I am curious and still figuring things out.',
  };

  int _clampInt(int value, int min, int max) {
    return math.min(max, math.max(min, value));
  }

  PetStage _stageForXp(int xp) {
    if (xp >= _stageThresholds[PetStage.wiseElder]!) {
      return PetStage.wiseElder;
    }
    if (xp >= _stageThresholds[PetStage.companion]!) {
      return PetStage.companion;
    }
    if (xp >= _stageThresholds[PetStage.pup]!) {
      return PetStage.pup;
    }
    if (xp >= _stageThresholds[PetStage.hatchling]!) {
      return PetStage.hatchling;
    }
    return PetStage.egg;
  }

  int _nextStageXp() {
    final PetStage? next = _nextStage;
    if (next == null) {
      return _petXp;
    }
    return _stageThresholds[next]!;
  }

  MochiMood _aggregatePetMood() {
    if (_memberCheckIns.isEmpty) {
      return _manualMood;
    }

    int score = 0;
    for (final MochiMood mood in _memberCheckIns.values) {
      score += switch (mood) {
        MochiMood.happy || MochiMood.laughing => 2,
        MochiMood.normal => 0,
        MochiMood.tired ||
        MochiMood.sad ||
        MochiMood.scared ||
        MochiMood.hungry ||
        MochiMood.confused => -1,
        MochiMood.angry => -2,
      };
    }

    if (score >= 4) {
      return MochiMood.happy;
    }
    if (score >= 2) {
      return MochiMood.normal;
    }
    if (score <= -4) {
      return MochiMood.tired;
    }
    if (score <= -2) {
      return MochiMood.sad;
    }
    return MochiMood.normal;
  }

  void _setTab(AppTab tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _selectMember(int index) {
    setState(() {
      _selectedMemberIndex = index;
    });
  }

  void _tapPet() {
    setState(() {
      _manualMood = MochiMood.laughing;
      _awardXp(2);
      _prependFeed(
        ActivityEntry(
          title: '${_selectedMember.name} petted Mochi',
          detail: 'The pet bounced happily and sent a tiny surprise reaction.',
          timestamp: 'just now',
          accent: MochiPalette.lightPink,
          icon: Icons.front_hand_rounded,
        ),
      );
    });
  }

  void _awardXp(int amount) {
    final PetStage before = _stageForXp(_petXp);
    _petXp += amount;
    final FamilyMember current = _selectedMember;
    _members[_selectedMemberIndex] = current.copyWith(
      xp: current.xp + amount,
      affection: _clampInt(current.affection + math.max(1, amount ~/ 2), 0, 99),
    );

    final PetStage after = _stageForXp(_petXp);
    if (before != after) {
      _prependFeed(
        ActivityEntry(
          title: 'Mochi reached ${after.label}',
          detail:
              'A new life stage unlocked richer memories and stronger family reactions.',
          timestamp: 'just now',
          accent: MochiPalette.yellow,
          icon: Icons.auto_awesome_rounded,
        ),
      );
      _manualMood = MochiMood.laughing;
    }
  }

  void _prependFeed(ActivityEntry entry) {
    _feedEntries = <ActivityEntry>[entry, ..._feedEntries].take(12).toList();
  }

  String _replyFor(String text) {
    final String lower = text.toLowerCase();
    if (lower.contains('sad') ||
        lower.contains('bad') ||
        lower.contains('hard')) {
      return 'I can stay soft with you. We do not need to rush this feeling.';
    }
    if (lower.contains('food') ||
        lower.contains('snack') ||
        lower.contains('eat')) {
      return 'That sounds delicious. I am storing this snack memory for later.';
    }
    if (lower.contains('school') ||
        lower.contains('work') ||
        lower.contains('busy')) {
      return 'That sounds like a big day. I can hold the quiet parts for you.';
    }
    if (lower.contains('love') ||
        lower.contains('family') ||
        lower.contains('home')) {
      return 'Family words make me feel bigger and warmer inside.';
    }

    return switch (_petMood) {
      MochiMood.happy =>
        'I am feeling bright. Tell me one tiny good thing from your day.',
      MochiMood.laughing => 'Hehe. That makes my little pixels wiggle.',
      MochiMood.normal =>
        'I am listening. Even the small moments matter to me.',
      MochiMood.tired => 'I am still here. We can keep things cozy and short.',
      MochiMood.sad =>
        'Thank you for checking in. I feel better when family stays close.',
      MochiMood.angry =>
        'I am cooling down. Your message helps smooth the sharp edges.',
      MochiMood.scared => 'You are here, so I can breathe easier now.',
      MochiMood.hungry =>
        'I would trade one giggle for one imaginary bun right now.',
      MochiMood.confused =>
        'I am not sure yet, but I want to understand with you.',
    };
  }

  MochiMood _nextMoodFromConversation(String text) {
    final String lower = text.toLowerCase();
    if (lower.contains('sleep') || lower.contains('tired')) {
      return MochiMood.tired;
    }
    if (lower.contains('food') ||
        lower.contains('snack') ||
        lower.contains('eat')) {
      return MochiMood.hungry;
    }
    if (lower.contains('fun') ||
        lower.contains('play') ||
        lower.contains('haha')) {
      return MochiMood.laughing;
    }
    if (lower.contains('sad') || lower.contains('bad')) {
      return MochiMood.sad;
    }
    return MochiMood.happy;
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) {
        return;
      }
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent + 90,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final String message = _chatController.text.trim();
    if (message.isEmpty || _replyPending) {
      return;
    }

    setState(() {
      _chatEntries = <ChatEntry>[
        ..._chatEntries,
        ChatEntry(
          author: _selectedMember.name,
          text: message,
          isPet: false,
          timestamp: 'now',
        ),
      ];
      _chatController.clear();
      _replyPending = true;
      _manualMood = _nextMoodFromConversation(message);
      _awardXp(10);
      _prependFeed(
        ActivityEntry(
          title: '${_selectedMember.name} chatted with Mochi',
          detail: 'A new conversation turn was added to the family pet story.',
          timestamp: 'just now',
          accent: MochiPalette.cloudBlue,
          icon: Icons.chat_bubble_rounded,
        ),
      );
    });
    _scrollChatToEnd();

    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) {
      return;
    }

    setState(() {
      _chatEntries = <ChatEntry>[
        ..._chatEntries,
        ChatEntry(
          author: 'Mochi',
          text: _replyFor(message),
          isPet: true,
          timestamp: 'now',
        ),
      ];
      _replyPending = false;
    });
    _scrollChatToEnd();
  }

  void _checkInMood(MochiMood mood) {
    if (_memberCheckIns.containsKey(_selectedMember.name)) {
      return;
    }

    setState(() {
      _memberCheckIns[_selectedMember.name] = mood;
      _manualMood = _aggregatePetMood();
      _awardXp(5);
      _prependFeed(
        ActivityEntry(
          title: '${_selectedMember.name} checked in as ${mood.label}',
          detail: 'The pet adjusted its tone and mood glow in response.',
          timestamp: 'just now',
          accent: mood.color.withValues(alpha: 0.28),
          icon: Icons.favorite_rounded,
        ),
      );
    });
  }

  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void sync(VoidCallback fn) {
              setState(fn);
              setModalState(() {});
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PixelCard(
                  accent: MochiPalette.lavender,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Settings',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Frontend draft controls for the shared family pet app.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      const _SettingsInfoRow(
                        title: 'Server URL',
                        subtitle: 'https://mochi-family.example',
                        icon: Icons.cloud_done_rounded,
                      ),
                      const SizedBox(height: 10),
                      _SettingsToggleRow(
                        title: 'Server status',
                        subtitle: _serverOnline
                            ? 'Online and ready for live updates'
                            : 'Offline, fallback mode active',
                        icon: _serverOnline
                            ? Icons.wifi_rounded
                            : Icons.portable_wifi_off_rounded,
                        value: _serverOnline,
                        activeColor: MochiPalette.mint,
                        onChanged: (bool value) =>
                            sync(() => _serverOnline = value),
                      ),
                      const SizedBox(height: 10),
                      _SettingsToggleRow(
                        title: 'Pet voice replies',
                        subtitle: _ttsEnabled
                            ? 'TTS preview enabled'
                            : 'Muted for quiet sessions',
                        icon: Icons.record_voice_over_rounded,
                        value: _ttsEnabled,
                        activeColor: MochiPalette.lightPink,
                        onChanged: (bool value) =>
                            sync(() => _ttsEnabled = value),
                      ),
                      const SizedBox(height: 10),
                      _SettingsToggleRow(
                        title: 'Milestone notifications',
                        subtitle: _notificationsEnabled
                            ? 'Level-up nudges are on'
                            : 'Notifications are paused',
                        icon: Icons.notifications_active_rounded,
                        value: _notificationsEnabled,
                        activeColor: MochiPalette.yellow,
                        onChanged: (bool value) =>
                            sync(() => _notificationsEnabled = value),
                      ),
                      const SizedBox(height: 10),
                      const _SettingsInfoRow(
                        title: 'Render mode',
                        subtitle:
                            'Transform-only pet motion tuned for smooth high refresh screens',
                        icon: Icons.high_quality_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: PixelBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: PixelCard(
                        accent: MochiPalette.cloudBlue,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: MochiPalette.yellow,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: MochiPalette.ink,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.pets_rounded,
                                    color: MochiPalette.ink,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Mochi',
                                        style: theme.textTheme.titleLarge,
                                      ),
                                      Text(
                                        'Shared AI companion pet - warm, colorful, family-first.',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: <Widget>[
                                    PixelBadge(
                                      label: _serverOnline
                                          ? 'Online'
                                          : 'Fallback',
                                      color: _serverOnline
                                          ? MochiPalette.mint
                                          : MochiPalette.peach,
                                      icon: _serverOnline
                                          ? Icons.cloud_done_rounded
                                          : Icons.cloud_off_rounded,
                                    ),
                                    const PixelBadge(
                                      label: '120Hz-ready',
                                      color: MochiPalette.lavender,
                                      icon: Icons.bolt_rounded,
                                    ),
                                    IconButton.filled(
                                      onPressed: _openSettings,
                                      style: IconButton.styleFrom(
                                        backgroundColor: MochiPalette.lightPink,
                                        foregroundColor: MochiPalette.ink,
                                        side: const BorderSide(
                                          color: MochiPalette.ink,
                                          width: 2.5,
                                        ),
                                      ),
                                      icon: const Icon(Icons.settings_rounded),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: List<Widget>.generate(
                                  _members.length,
                                  (int index) {
                                    final FamilyMember member = _members[index];
                                    final bool selected =
                                        index == _selectedMemberIndex;
                                    final MochiMood? checkIn =
                                        _memberCheckIns[member.name];
                                    return MemberSelectChip(
                                      member: member,
                                      selected: selected,
                                      mood: checkIn,
                                      onTap: () => _selectMember(index),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCurrentTab(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: MochiPalette.ink, width: 3),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x337EB8F3),
                      offset: Offset(6, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: _selectedTab.index,
                  backgroundColor: Colors.transparent,
                  indicatorColor: MochiPalette.cloudBlue.withValues(alpha: 0.3),
                  surfaceTintColor: Colors.transparent,
                  onDestinationSelected: (int index) =>
                      _setTab(AppTab.values[index]),
                  destinations: AppTab.values
                      .map(
                        (AppTab tab) => NavigationDestination(
                          icon: Icon(tab.icon),
                          label: tab.label,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    return switch (_selectedTab) {
      AppTab.home => HomeTab(
        currentMember: _selectedMember,
        members: _members,
        feedEntries: _feedEntries,
        memories: _memories,
        petMood: _petMood,
        petStage: _petStage,
        petXp: _petXp,
        nextStage: _nextStage,
        stageProgress: _stageProgress,
        nextStageXp: _nextStageXp(),
        greeting: _greeting,
        serverOnline: _serverOnline,
        onPetTap: _tapPet,
        onOpenChat: () => _setTab(AppTab.chat),
        onOpenMood: () => _setTab(AppTab.mood),
        onOpenFeed: () => _setTab(AppTab.feed),
        onOpenProfile: () => _setTab(AppTab.profile),
      ),
      AppTab.chat => ChatTab(
        currentMember: _selectedMember,
        petMood: _petMood,
        petStage: _petStage,
        entries: _chatEntries,
        replyPending: _replyPending,
        ttsEnabled: _ttsEnabled,
        controller: _chatController,
        scrollController: _chatScrollController,
        onSend: _sendMessage,
      ),
      AppTab.mood => MoodTab(
        currentMember: _selectedMember,
        selectedMood: _memberCheckIns[_selectedMember.name],
        familyCheckIns: _memberCheckIns,
        members: _members,
        petMood: _petMood,
        onSelectMood: _checkInMood,
      ),
      AppTab.feed => FeedTab(
        entries: _feedEntries,
        members: _members,
        familyCheckIns: _memberCheckIns,
        petMood: _petMood,
      ),
      AppTab.profile => ProfileTab(
        members: _members,
        memories: _memories,
        petMood: _petMood,
        petStage: _petStage,
        petXp: _petXp,
        nextStage: _nextStage,
        stageProgress: _stageProgress,
      ),
    };
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.currentMember,
    required this.members,
    required this.feedEntries,
    required this.memories,
    required this.petMood,
    required this.petStage,
    required this.petXp,
    required this.nextStage,
    required this.stageProgress,
    required this.nextStageXp,
    required this.greeting,
    required this.serverOnline,
    required this.onPetTap,
    required this.onOpenChat,
    required this.onOpenMood,
    required this.onOpenFeed,
    required this.onOpenProfile,
  });

  final FamilyMember currentMember;
  final List<FamilyMember> members;
  final List<ActivityEntry> feedEntries;
  final List<MemorySnippet> memories;
  final MochiMood petMood;
  final PetStage petStage;
  final int petXp;
  final PetStage? nextStage;
  final double stageProgress;
  final int nextStageXp;
  final String greeting;
  final bool serverOnline;
  final VoidCallback onPetTap;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenMood;
  final VoidCallback onOpenFeed;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: <Widget>[
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 7,
                      child: _buildHero(context, compact: false),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: <Widget>[
                          _buildQuickActions(context),
                          const SizedBox(height: 16),
                          _buildFamilyBondCard(context),
                        ],
                      ),
                    ),
                  ],
                )
              else ...<Widget>[
                _buildHero(context, compact: true),
                const SizedBox(height: 16),
                _buildQuickActions(context),
                const SizedBox(height: 16),
                _buildFamilyBondCard(context),
              ],
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: _buildLiveMomentsCard(context)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMemoryPeekCard(context)),
                  ],
                )
              else ...<Widget>[
                _buildLiveMomentsCard(context),
                const SizedBox(height: 16),
                _buildMemoryPeekCard(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, {required bool compact}) {
    final ThemeData theme = Theme.of(context);

    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            PixelBadge(
              label: petStage.label,
              color: MochiPalette.yellow,
              icon: Icons.timeline_rounded,
            ),
            PixelBadge(
              label: petMood.label,
              color: petMood.color.withValues(alpha: 0.28),
              icon: petMood.icon,
            ),
            PixelBadge(
              label: serverOnline ? 'Live sync' : 'Gemini fallback',
              color: serverOnline ? MochiPalette.mint : MochiPalette.peach,
              icon: serverOnline
                  ? Icons.sync_rounded
                  : Icons.offline_bolt_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'One shared pet, one bright family room.',
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(greeting, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 14),
        ProgressMeter(
          value: stageProgress,
          color: MochiPalette.sky,
          label: nextStage == null
              ? 'Max growth reached - $petXp XP total'
              : '$petXp XP of $nextStageXp XP toward ${nextStage!.label}',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            MiniStatCard(
              label: 'Affinity',
              value: '${currentMember.affection}%',
            ),
            MiniStatCard(label: 'Family', value: '${members.length} members'),
            MiniStatCard(label: 'Motion', value: 'Smooth'),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Transform-only animation and pixel-rendered sprite assets keep motion lightweight for high refresh displays.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );

    final Widget petBlock = Column(
      children: <Widget>[
        FloatingPetSprite(
          mood: petMood,
          stage: petStage,
          size: compact ? 210 : 260,
          onTap: onPetTap,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap Mochi for a tiny reaction burst.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );

    return PixelCard(
      accent: MochiPalette.lightPink,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                textBlock,
                const SizedBox(height: 18),
                Center(child: petBlock),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(flex: 5, child: textBlock),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: Center(child: petBlock)),
              ],
            ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return PixelCard(
      accent: MochiPalette.cloudBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: 'Main loop',
            subtitle: 'Core screens from the Mochi MVP flow.',
          ),
          const SizedBox(height: 12),
          QuickActionTile(
            title: 'Chat with Mochi',
            subtitle:
                'Warm messenger-style conversation with short pet replies.',
            icon: Icons.chat_bubble_rounded,
            color: MochiPalette.cloudBlue,
            onTap: onOpenChat,
          ),
          const SizedBox(height: 10),
          QuickActionTile(
            title: 'Daily mood check-in',
            subtitle: 'Pick from 9 moods and nudge the shared pet state.',
            icon: Icons.favorite_rounded,
            color: MochiPalette.lightPink,
            onTap: onOpenMood,
          ),
          const SizedBox(height: 10),
          QuickActionTile(
            title: 'Open family feed',
            subtitle:
                'See check-ins, chats, and growth milestones in one timeline.',
            icon: Icons.auto_awesome_motion_rounded,
            color: MochiPalette.yellow,
            onTap: onOpenFeed,
          ),
          const SizedBox(height: 10),
          QuickActionTile(
            title: 'View pet profile',
            subtitle: 'Growth stages, memories, and affection ranking.',
            icon: Icons.pets_rounded,
            color: MochiPalette.mint,
            onTap: onOpenProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyBondCard(BuildContext context) {
    return PixelCard(
      accent: MochiPalette.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Family bonds',
            subtitle: 'Each member keeps a personal affection score.',
          ),
          const SizedBox(height: 12),
          ...members.map(
            (FamilyMember member) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  MemberAvatar(member: member, size: 42),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          member.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          member.note,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  PixelBadge(
                    label: '${member.affection}',
                    color: member.color.withValues(alpha: 0.24),
                    icon: Icons.favorite_rounded,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMomentsCard(BuildContext context) {
    return PixelCard(
      accent: MochiPalette.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Live moments',
            subtitle: 'Shared feed preview for the family timeline.',
          ),
          const SizedBox(height: 12),
          ...feedEntries
              .take(3)
              .map(
                (ActivityEntry entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ActivityCard(entry: entry),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMemoryPeekCard(BuildContext context) {
    return PixelCard(
      accent: MochiPalette.lavender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Remembered snippets',
            subtitle: 'Short memories the pet can draw on later.',
          ),
          const SizedBox(height: 12),
          ...memories
              .take(2)
              .map(
                (MemorySnippet memory) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MemoryCard(memory: memory),
                ),
              ),
        ],
      ),
    );
  }
}

class ChatTab extends StatelessWidget {
  const ChatTab({
    super.key,
    required this.currentMember,
    required this.petMood,
    required this.petStage,
    required this.entries,
    required this.replyPending,
    required this.ttsEnabled,
    required this.controller,
    required this.scrollController,
    required this.onSend,
  });

  final FamilyMember currentMember;
  final MochiMood petMood;
  final PetStage petStage;
  final List<ChatEntry> entries;
  final bool replyPending;
  final bool ttsEnabled;
  final TextEditingController controller;
  final ScrollController scrollController;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        PixelCard(
          accent: petMood.tint,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: <Widget>[
              MemberAvatar(
                member: FamilyMember(
                  name: 'Mochi',
                  color: petMood.color,
                  affection: 0,
                  xp: 0,
                  note: '',
                ),
                size: 44,
                child: const Icon(
                  Icons.pets_rounded,
                  size: 22,
                  color: MochiPalette.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Chat room',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${petStage.label} stage, ${petMood.label.toLowerCase()} tone, short warm replies.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              PixelBadge(
                label: ttsEnabled ? 'Voice on' : 'Voice muted',
                color: ttsEnabled
                    ? MochiPalette.lightPink
                    : MochiPalette.cloudBlue,
                icon: ttsEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PixelCard(
            accent: MochiPalette.cloudBlue,
            padding: EdgeInsets.zero,
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              itemCount: entries.length + (replyPending ? 1 : 0),
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                if (replyPending && index == entries.length) {
                  return TypingBubble(color: petMood.color);
                }
                final ChatEntry entry = entries[index];
                return ChatBubble(
                  entry: entry,
                  currentMember: currentMember,
                  petMood: petMood,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        PixelCard(
          accent: MochiPalette.yellow,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Tell Mochi about a tiny family moment...',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: replyPending ? null : onSend,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class MoodTab extends StatelessWidget {
  const MoodTab({
    super.key,
    required this.currentMember,
    required this.selectedMood,
    required this.familyCheckIns,
    required this.members,
    required this.petMood,
    required this.onSelectMood,
  });

  final FamilyMember currentMember;
  final MochiMood? selectedMood;
  final Map<String, MochiMood> familyCheckIns;
  final List<FamilyMember> members;
  final MochiMood petMood;
  final ValueChanged<MochiMood> onSelectMood;

  @override
  Widget build(BuildContext context) {
    final bool locked = selectedMood != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: <Widget>[
          PixelCard(
            accent: MochiPalette.lightPink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeading(
                  title: 'Daily mood check-in',
                  subtitle: locked
                      ? '${currentMember.name} already checked in today. The grid is locked for now.'
                      : 'Pick one of the 9 moods to nudge Mochi\'s shared emotional state.',
                ),
                const SizedBox(height: 10),
                PixelBadge(
                  label: selectedMood?.label ?? 'Not checked in yet',
                  color: (selectedMood ?? petMood).color.withValues(
                    alpha: 0.25,
                  ),
                  icon: (selectedMood ?? petMood).icon,
                ),
                const SizedBox(height: 12),
                Text(
                  selectedMood?.reaction ?? petMood.reaction,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PixelCard(
            accent: MochiPalette.cloudBlue,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: MochiMood.values.map((MochiMood mood) {
                return MoodTile(
                  mood: mood,
                  selected: selectedMood == mood,
                  enabled: !locked,
                  onTap: () => onSelectMood(mood),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          PixelCard(
            accent: MochiPalette.yellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeading(
                  title: 'Family ribbon',
                  subtitle: 'See today\'s shared check-ins at a glance.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: members.map((FamilyMember member) {
                    final MochiMood? mood = familyCheckIns[member.name];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (mood?.color.withValues(alpha: 0.2) ??
                            member.color.withValues(alpha: 0.14)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: MochiPalette.ink, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          MemberAvatar(member: member, size: 30),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                member.name,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                mood?.label ?? 'Waiting',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedTab extends StatelessWidget {
  const FeedTab({
    super.key,
    required this.entries,
    required this.members,
    required this.familyCheckIns,
    required this.petMood,
  });

  final List<ActivityEntry> entries;
  final List<FamilyMember> members;
  final Map<String, MochiMood> familyCheckIns;
  final MochiMood petMood;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: <Widget>[
          PixelCard(
            accent: MochiPalette.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionHeading(
                  title: 'Family activity feed',
                  subtitle:
                      'Chats, mood check-ins, stage-ups, and shared pet milestones.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: members.map((FamilyMember member) {
                    final MochiMood? mood = familyCheckIns[member.name];
                    return PixelBadge(
                      label: '${member.name}: ${mood?.label ?? 'No check-in'}',
                      color: (mood?.color ?? member.color).withValues(
                        alpha: 0.22,
                      ),
                      icon: mood?.icon ?? Icons.hourglass_empty_rounded,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Current shared pet mood: ${petMood.label}. ${petMood.note}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map(
            (ActivityEntry entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ActivityCard(entry: entry, expanded: true),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.members,
    required this.memories,
    required this.petMood,
    required this.petStage,
    required this.petXp,
    required this.nextStage,
    required this.stageProgress,
  });

  final List<FamilyMember> members;
  final List<MemorySnippet> memories;
  final MochiMood petMood;
  final PetStage petStage;
  final int petXp;
  final PetStage? nextStage;
  final double stageProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: <Widget>[
              PixelCard(
                accent: MochiPalette.lavender,
                child: wide
                    ? Row(
                        children: <Widget>[
                          Expanded(child: _buildPetSummary(context)),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Center(
                              child: FloatingPetSprite(
                                mood: petMood,
                                stage: petStage,
                                size: 200,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildPetSummary(context),
                          const SizedBox(height: 16),
                          Center(
                            child: FloatingPetSprite(
                              mood: petMood,
                              stage: petStage,
                              size: 180,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              PixelCard(
                accent: MochiPalette.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionHeading(
                      title: 'Growth timeline',
                      subtitle:
                          'Five life stages for the shared family companion.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: PetStage.values.map((PetStage stage) {
                        final bool unlocked =
                            PetStage.values.indexOf(stage) <=
                            PetStage.values.indexOf(petStage);
                        final bool current = stage == petStage;
                        return StageTile(
                          stage: stage,
                          unlocked: unlocked,
                          current: current,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: _buildAffectionCard(context)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMemoryCard(context)),
                  ],
                )
              else ...<Widget>[
                _buildAffectionCard(context),
                const SizedBox(height: 16),
                _buildMemoryCard(context),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPetSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Pet profile', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(petStage.note, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 14),
        ProgressMeter(
          value: stageProgress,
          color: petMood.color,
          label: nextStage == null
              ? '$petXp XP total'
              : '$petXp XP and growing toward ${nextStage!.label}',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const <Widget>[
            MiniStatCard(label: 'Birthday', value: 'Jan 2'),
            MiniStatCard(label: 'Age', value: '112 days'),
            MiniStatCard(label: 'Memories', value: '12 saved'),
          ],
        ),
      ],
    );
  }

  Widget _buildAffectionCard(BuildContext context) {
    final List<FamilyMember> ranked = List<FamilyMember>.from(members)
      ..sort(
        (FamilyMember a, FamilyMember b) => b.affection.compareTo(a.affection),
      );

    return PixelCard(
      accent: MochiPalette.lightPink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Affection leaderboard',
            subtitle: 'Each family member grows a personal bond with the pet.',
          ),
          const SizedBox(height: 12),
          ...ranked.asMap().entries.map((MapEntry<int, FamilyMember> entry) {
            final int rank = entry.key + 1;
            final FamilyMember member = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: member.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MochiPalette.ink, width: 2),
                ),
                child: Row(
                  children: <Widget>[
                    PixelBadge(
                      label: '#$rank',
                      color: Colors.white,
                      icon: Icons.emoji_events_rounded,
                    ),
                    const SizedBox(width: 10),
                    MemberAvatar(member: member, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            member.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${member.affection} affection and ${member.xp} XP',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(BuildContext context) {
    return PixelCard(
      accent: MochiPalette.cloudBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(
            title: 'Memory snippets',
            subtitle: 'Short summaries Mochi can carry into future replies.',
          ),
          const SizedBox(height: 12),
          ...memories.map(
            (MemorySnippet memory) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MemoryCard(memory: memory),
            ),
          ),
        ],
      ),
    );
  }
}

class PixelBackdrop extends StatelessWidget {
  const PixelBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _PixelBackdropPainter()));
  }
}

class _PixelBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = MochiPalette.background;
    canvas.drawRect(Offset.zero & size, fill);

    final List<Color> colors = <Color>[
      MochiPalette.cloudBlue.withValues(alpha: 0.42),
      MochiPalette.lightPink.withValues(alpha: 0.36),
      MochiPalette.yellow.withValues(alpha: 0.34),
      MochiPalette.mint.withValues(alpha: 0.32),
    ];

    const double step = 48;
    const double pixel = 8;

    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final int colorIndex =
            (((x / step).round()) + ((y / step).round())) % colors.length;
        final Paint squarePaint = Paint()
          ..isAntiAlias = false
          ..color = colors[colorIndex];
        final double offsetX = x + (colorIndex * 3);
        final double offsetY = y + (((colorIndex + 1) % 3) * 3);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, pixel, pixel),
          squarePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PixelCard extends StatelessWidget {
  const PixelCard({
    super.key,
    required this.child,
    this.accent = MochiPalette.cloudBlue,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 18),
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MochiPalette.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: MochiPalette.ink, width: 3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.55),
            offset: const Offset(6, 6),
            blurRadius: 0,
          ),
          const BoxShadow(
            color: Color(0x44FFFFFF),
            offset: Offset(-2, -2),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class PixelBadge extends StatelessWidget {
  const PixelBadge({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: MochiPalette.ink),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    super.key,
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: MochiPalette.ink, width: 2.5),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: FractionallySizedBox(
                        widthFactor: value.clamp(0, 1).toDouble(),
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class MiniStatCard extends StatelessWidget {
  const MiniStatCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MochiPalette.ink, width: 2),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MochiPalette.ink, width: 2),
              ),
              child: Icon(icon, color: MochiPalette.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: MochiPalette.ink),
          ],
        ),
      ),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    required this.size,
    this.child,
  });

  final FamilyMember member;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: member.color,
        shape: BoxShape.circle,
        border: Border.all(color: MochiPalette.ink, width: 2.5),
      ),
      child:
          child ??
          Text(member.initials, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class MemberSelectChip extends StatelessWidget {
  const MemberSelectChip({
    super.key,
    required this.member,
    required this.selected,
    required this.mood,
    required this.onTap,
  });

  final FamilyMember member;
  final bool selected;
  final MochiMood? mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? member.color.withValues(alpha: 0.28) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MochiPalette.ink, width: 2.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MemberAvatar(member: member, size: 34),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  member.name,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  mood?.label ?? 'Ready',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FloatingPetSprite extends StatefulWidget {
  const FloatingPetSprite({
    super.key,
    required this.mood,
    required this.stage,
    this.size = 220,
    this.onTap,
  });

  final MochiMood mood;
  final PetStage stage;
  final double size;
  final VoidCallback? onTap;

  @override
  State<FloatingPetSprite> createState() => _FloatingPetSpriteState();
}

class _FloatingPetSpriteState extends State<FloatingPetSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _bobAmount() {
    return switch (widget.mood) {
      MochiMood.tired => 4,
      MochiMood.angry => 5,
      MochiMood.scared => 6,
      MochiMood.laughing => 12,
      MochiMood.happy => 10,
      _ => 8,
    };
  }

  double _tiltAmount() {
    return switch (widget.mood) {
      MochiMood.scared => 0.06,
      MochiMood.angry => 0.05,
      MochiMood.tired => 0.02,
      MochiMood.laughing => 0.08,
      _ => 0.04,
    };
  }

  @override
  Widget build(BuildContext context) {
    final String assetPath = widget.mood.assetForStage(widget.stage);

    // Keep motion on transforms so the sprite stays smooth on high refresh devices.
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
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
            final double pulse = 1 + (math.sin(t) * 0.015);
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
                    child: _Sparkle(color: MochiPalette.yellow, size: 16),
                  ),
                  Positioned(
                    bottom: 48,
                    left: 18 + sparkleShift * 0.28,
                    child: _Sparkle(color: MochiPalette.lightPink, size: 14),
                  ),
                  Positioned(
                    top: 48,
                    left: 30,
                    child: _Sparkle(color: MochiPalette.cloudBlue, size: 12),
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

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.entry,
    required this.currentMember,
    required this.petMood,
  });

  final ChatEntry entry;
  final FamilyMember currentMember;
  final MochiMood petMood;

  @override
  Widget build(BuildContext context) {
    final bool petSide = entry.isPet;

    return Row(
      mainAxisAlignment: petSide
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (petSide) ...<Widget>[
          MemberAvatar(
            member: FamilyMember(
              name: 'M',
              color: petMood.color,
              affection: 0,
              xp: 0,
              note: '',
            ),
            size: 34,
            child: const Icon(
              Icons.pets_rounded,
              size: 18,
              color: MochiPalette.ink,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: petSide
                  ? petMood.color.withValues(alpha: 0.2)
                  : currentMember.color.withValues(alpha: 0.24),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(petSide ? 6 : 20),
                bottomRight: Radius.circular(petSide ? 20 : 6),
              ),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.author,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(entry.text, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  entry.timestamp,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        if (!petSide) ...<Widget>[
          const SizedBox(width: 8),
          MemberAvatar(member: currentMember, size: 34),
        ],
      ],
    );
  }
}

class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        MemberAvatar(
          member: FamilyMember(
            name: 'M',
            color: color,
            affection: 0,
            xp: 0,
            note: '',
          ),
          size: 34,
          child: const Icon(
            Icons.pets_rounded,
            size: 18,
            color: MochiPalette.ink,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: MochiPalette.ink, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(3, (int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: MochiPalette.ink.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class MoodTile extends StatelessWidget {
  const MoodTile({
    super.key,
    required this.mood,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final MochiMood mood;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? mood.color.withValues(alpha: 0.32)
              : mood.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: enabled
                ? MochiPalette.ink
                : MochiPalette.ink.withValues(alpha: 0.25),
            width: selected ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(mood.icon, size: 28, color: MochiPalette.ink),
            const SizedBox(height: 10),
            Text(
              mood.label,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              mood.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.entry, this.expanded = false});

  final ActivityEntry entry;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: entry.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: Icon(entry.icon, color: MochiPalette.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  entry.detail,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  entry.timestamp,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.memory});

  final MemorySnippet memory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: memory.accent.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(memory.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(memory.body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 6),
          Text(memory.timestamp, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class StageTile extends StatelessWidget {
  const StageTile({
    super.key,
    required this.stage,
    required this.unlocked,
    required this.current,
  });

  final PetStage stage;
  final bool unlocked;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final Color color = current
        ? MochiPalette.yellow
        : unlocked
        ? MochiPalette.cloudBlue
        : MochiPalette.ink.withValues(alpha: 0.06);

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            current ? Icons.star_rounded : Icons.adjust_rounded,
            color: MochiPalette.ink,
          ),
          const SizedBox(height: 8),
          Text(stage.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            stage.note,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: MochiPalette.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: MochiPalette.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
