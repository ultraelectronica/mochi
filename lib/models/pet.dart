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
  PetStage.hatchling: 30,
  PetStage.pup: 90,
  PetStage.companion: 170,
  PetStage.wiseElder: 320,
};

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
  const Pet({required this.name, required this.xp, required this.mood});

  final String name;
  final int xp;
  final MochiMood mood;

  PetStage get stage => petStageForXp(xp);

  PetStage? get nextStage => nextPetStage(stage);

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

  Pet copyWith({String? name, int? xp, MochiMood? mood}) {
    return Pet(
      name: name ?? this.name,
      xp: xp ?? this.xp,
      mood: mood ?? this.mood,
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
