import 'package:flutter/material.dart';

import 'mood.dart';

enum PetStage { egg, hatchling, pup, companion, wiseElder }

extension PetStageData on PetStage {
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

const Map<PetStage, int> petStageThresholds = <PetStage, int>{
  PetStage.egg: 0,
  PetStage.hatchling: 250,
  PetStage.pup: 750,
  PetStage.companion: 1800,
  PetStage.wiseElder: 4000,
};

PetStage petStageFromNumber(int stage) {
  return switch (stage) {
    1 => PetStage.egg,
    2 => PetStage.hatchling,
    3 => PetStage.pup,
    4 => PetStage.companion,
    5 => PetStage.wiseElder,
    _ => PetStage.egg,
  };
}

int petStageNumber(PetStage stage) {
  return switch (stage) {
    PetStage.egg => 1,
    PetStage.hatchling => 2,
    PetStage.pup => 3,
    PetStage.companion => 4,
    PetStage.wiseElder => 5,
  };
}

PetStage petStageForXp(int xp) {
  if (xp >= petStageThresholds[PetStage.wiseElder]!) {
    return PetStage.wiseElder;
  }
  if (xp >= petStageThresholds[PetStage.companion]!) {
    return PetStage.companion;
  }
  if (xp >= petStageThresholds[PetStage.pup]!) {
    return PetStage.pup;
  }
  if (xp >= petStageThresholds[PetStage.hatchling]!) {
    return PetStage.hatchling;
  }
  return PetStage.egg;
}

PetStage? nextPetStage(PetStage stage) {
  final int index = PetStage.values.indexOf(stage);
  if (index == PetStage.values.length - 1) {
    return null;
  }
  return PetStage.values[index + 1];
}

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.stageNumber,
    required this.xp,
    required this.mood,
    required this.moodScore,
    this.satiety = 70,
    this.lastInteractionAt,
    this.createdAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: _asInt(json['id']),
      name: (json['name'] as String? ?? 'Mochi').trim(),
      stageNumber: _asInt(json['stage']),
      xp: _asInt(json['total_xp']),
      mood: mochiMoodFromString(json['mood'] as String? ?? 'normal'),
      moodScore: _asInt(json['mood_score']),
      satiety: _asInt(json['satiety']),
      lastInteractionAt: _parseDateTime(json['last_interaction_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final int id;
  final String name;
  final int stageNumber;
  final int xp;
  final MochiMood mood;
  final int moodScore;
  final int satiety;
  final DateTime? lastInteractionAt;
  final DateTime? createdAt;

  PetStage get stage => petStageFromNumber(stageNumber);

  PetStage? get nextStage => nextPetStage(stage);

  String get hungerLabel => switch (satiety) {
    >= 70 => 'full',
    >= 30 => 'a little peckish',
    _ => 'very hungry',
  };

  int get nextStageXp {
    final PetStage? next = nextStage;
    if (next == null) {
      return xp;
    }
    return petStageThresholds[next]!;
  }

  double get stageProgress {
    final PetStage current = stage;
    final PetStage? next = nextStage;
    if (next == null) {
      return 1;
    }
    final int start = petStageThresholds[current]!;
    final int end = petStageThresholds[next]!;
    return ((xp - start) / (end - start)).clamp(0, 1).toDouble();
  }

  Pet copyWith({
    int? id,
    String? name,
    int? stageNumber,
    int? xp,
    MochiMood? mood,
    int? moodScore,
    int? satiety,
    DateTime? lastInteractionAt,
    DateTime? createdAt,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      stageNumber: stageNumber ?? this.stageNumber,
      xp: xp ?? this.xp,
      mood: mood ?? this.mood,
      moodScore: moodScore ?? this.moodScore,
      satiety: satiety ?? this.satiety,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class ChatEntry {
  const ChatEntry({
    required this.id,
    required this.author,
    required this.text,
    required this.isPet,
    required this.timestamp,
    required this.createdAt,
  });

  factory ChatEntry.local({
    required String author,
    required String text,
    required bool isPet,
  }) {
    final DateTime now = DateTime.now();
    return ChatEntry(
      id: null,
      author: author,
      text: text,
      isPet: isPet,
      timestamp: _formatClock(now),
      createdAt: now,
    );
  }

  static List<ChatEntry> fromInteractionJson(Map<String, dynamic> json) {
    final DateTime createdAt =
        _parseDateTime(json['created_at']) ?? DateTime.now();
    final int id = _asInt(json['id']);
    final String memberName =
        (json['member_name'] as String? ?? 'Family member').trim();
    return <ChatEntry>[
      ChatEntry(
        id: id,
        author: memberName,
        text: (json['input_text'] as String? ?? '').trim(),
        isPet: false,
        timestamp: _formatClock(createdAt),
        createdAt: createdAt,
      ),
      ChatEntry(
        id: id,
        author: 'Mochi',
        text: (json['response_text'] as String? ?? '').trim(),
        isPet: true,
        timestamp: _formatClock(createdAt),
        createdAt: createdAt,
      ),
    ];
  }

  final int? id;
  final String author;
  final String text;
  final bool isPet;
  final String timestamp;
  final DateTime createdAt;
}

class ActivityEntry {
  const ActivityEntry({
    required this.title,
    required this.detail,
    required this.timestamp,
    required this.accent,
    required this.icon,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    final String eventType = json['event_type'] as String? ?? 'chat';
    final String? memberName = (json['member_name'] as String?)?.trim();
    final String detail = (json['detail'] as String? ?? '').trim();
    final DateTime createdAt =
        _parseDateTime(json['created_at']) ?? DateTime.now();

    return ActivityEntry(
      title: switch (eventType) {
        'mood_checkin' =>
          '${memberName ?? 'Family'} checked in as ${_titleFromMoodDetail(detail)}',
        'stage_up' => detail,
        'pet_tap' => '${memberName ?? 'Family'} petted Mochi',
        'feed' =>
          '${memberName ?? 'Family'} fed Mochi ${json['food_label'] ?? 'a snack'}',
        'mini_game' =>
          '${memberName ?? 'Family'} played ${json['game_label'] ?? 'a game'}',
        'food_grant' =>
          '${memberName ?? 'Family'} found ${json['food_label'] ?? 'a treat'}',
        _ => '${memberName ?? 'Family'} chatted with Mochi',
      },
      detail: switch (eventType) {
        'mood_checkin' => 'Mochi adjusted her shared mood glow.',
        'stage_up' =>
          'A new life stage unlocked richer memories and reactions.',
        'pet_tap' => 'Mochi bounced happily from a tiny tap.',
        'feed' => 'Satiety rose and Mochi wiggled with joy.',
        'mini_game' => (json['xp_awarded'] as int? ?? 0) > 0
            ? 'Playtime together earned +${json['xp_awarded']} XP.'
            : 'Mochi enjoyed the company, no XP this time.',
        'food_grant' => switch (json['source'] as String? ?? '') {
          'chat' => 'A reward from a good chat — waiting in the pantry.',
          'game' => 'A mini-game prize — waiting in the pantry.',
          'checkIn' => "Today's check-in treat — waiting in the pantry.",
          _ => 'A treat added to the pantry.',
        },
        _ => detail.isEmpty ? 'A new conversation turn was added.' : detail,
      },
      timestamp: _formatRelative(createdAt),
      accent: switch (eventType) {
        'mood_checkin' => mochiMoodFromString(
          _moodKeyFromDetail(detail),
        ).color.withValues(alpha: 0.28),
        'stage_up' => const Color(0xFFFFF0B5),
        'pet_tap' => const Color(0xFFFFE0EC),
        'feed' => const Color(0xFFFFE8CC),
        'mini_game' => const Color(0xFFE4DDFF),
        'food_grant' => const Color(0xFFFFF0C2),
        _ => const Color(0xFFD8F0FF),
      },
      icon: switch (eventType) {
        'mood_checkin' => Icons.favorite_rounded,
        'stage_up' => Icons.auto_awesome_rounded,
        'pet_tap' => Icons.front_hand_rounded,
        'feed' => Icons.restaurant_rounded,
        'mini_game' => Icons.videogame_asset_rounded,
        'food_grant' => Icons.card_giftcard_rounded,
        _ => Icons.chat_bubble_rounded,
      },
    );
  }

  final String title;
  final String detail;
  final String timestamp;
  final Color accent;
  final IconData icon;
}

class MemorySnippet {
  const MemorySnippet({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.accent,
  });

  factory MemorySnippet.fromJson(Map<String, dynamic> json) {
    final int weight = _asInt(json['weight']);
    final DateTime createdAt =
        _parseDateTime(json['created_at']) ?? DateTime.now();
    final String memberName = (json['member_name'] as String? ?? 'Family')
        .trim();
    return MemorySnippet(
      id: _asInt(json['id']),
      title: '$memberName memory',
      body: (json['content'] as String? ?? '').trim(),
      timestamp: 'Saved ${_formatRelative(createdAt).toLowerCase()}',
      accent: switch (weight) {
        >= 4 => const Color(0xFFFFF0B5),
        3 => const Color(0xFFFFE0EC),
        _ => const Color(0xFFD8F0FF),
      },
    );
  }

  final int id;
  final String title;
  final String body;
  final String timestamp;
  final Color accent;
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

String _formatClock(DateTime value) {
  final int hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final String minute = value.minute.toString().padLeft(2, '0');
  final String period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatRelative(DateTime value) {
  final Duration delta = DateTime.now().difference(value);

  if (delta.inSeconds < 60) {
    return 'just now';
  }
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes}m ago';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours}h ago';
  }
  if (delta.inDays == 1) {
    return 'Yesterday';
  }
  if (delta.inDays < 7) {
    return '${delta.inDays}d ago';
  }
  return '${value.month}/${value.day}/${value.year}';
}

String _moodKeyFromDetail(String detail) {
  final RegExpMatch? match = RegExp(
    r'as\s+([a-z]+)$',
    caseSensitive: false,
  ).firstMatch(detail);
  return match?.group(1)?.toLowerCase() ?? 'normal';
}

String _titleFromMoodDetail(String detail) {
  final String key = _moodKeyFromDetail(detail);
  final String lower = key.toLowerCase();
  if (lower.isEmpty) {
    return 'Normal';
  }
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
