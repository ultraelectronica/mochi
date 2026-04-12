import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';

class PetProvider extends ChangeNotifier {
  PetProvider()
    : _pet = const Pet(name: 'Mochi', xp: 186, mood: MochiMood.happy),
      _chatEntries = <ChatEntry>[
        const ChatEntry(
          author: 'Mochi',
          text:
              'Hi family. I kept a bright little corner ready for whoever visits first.',
          isPet: true,
          timestamp: '9:08',
        ),
        const ChatEntry(
          author: 'Arne',
          text: 'Morning, Mochi. We are all a bit sleepy today.',
          isPet: false,
          timestamp: '9:10',
        ),
        const ChatEntry(
          author: 'Mochi',
          text:
              'Then I will stay cozy too. Tiny steps are enough for this morning.',
          isPet: true,
          timestamp: '9:10',
        ),
      ],
      _feedEntries = <ActivityEntry>[
        const ActivityEntry(
          title: 'Arne chatted with Mochi',
          detail: 'The pet replied with a sleepy but warm morning check-in.',
          timestamp: '6m ago',
          accent: MochiPalette.cloudBlue,
          icon: Icons.chat_bubble_rounded,
        ),
        const ActivityEntry(
          title: 'Bea checked in as Happy',
          detail: 'Mochi brightened and shifted toward a playful mood.',
          timestamp: '18m ago',
          accent: MochiPalette.lightPink,
          icon: Icons.favorite_rounded,
        ),
        const ActivityEntry(
          title: 'Mochi reached Companion stage',
          detail:
              'The family unlocked richer memories and more expressive reactions.',
          timestamp: 'Yesterday',
          accent: MochiPalette.yellow,
          icon: Icons.auto_awesome_rounded,
        ),
      ],
      _memories = <MemorySnippet>[
        const MemorySnippet(
          title: 'Picnic blanket day',
          body:
              'Mochi remembers the yellow blanket, cloud-blue cups, and everyone sitting close together.',
          timestamp: 'Saved 2 days ago',
          accent: MochiPalette.yellow,
        ),
        const MemorySnippet(
          title: 'Rainy night voice note',
          body:
              'Lia whispered a bedtime story while the whole house sounded soft and sleepy.',
          timestamp: 'Saved 4 days ago',
          accent: MochiPalette.lightPink,
        ),
        const MemorySnippet(
          title: 'After-school snack run',
          body:
              'Nico told Mochi about buns, juice, and a tiny argument that ended in a laugh.',
          timestamp: 'Saved 6 days ago',
          accent: MochiPalette.cloudBlue,
        ),
      ];

  Pet _pet;
  final List<ChatEntry> _chatEntries;
  final List<ActivityEntry> _feedEntries;
  final List<MemorySnippet> _memories;
  final Map<String, MochiMood> _memberCheckIns = <String, MochiMood>{};

  bool _serverOnline = true;
  bool _ttsEnabled = true;
  bool _notificationsEnabled = true;
  bool _replyPending = false;

  Pet get pet => _pet;
  List<ChatEntry> get chatEntries => List<ChatEntry>.unmodifiable(_chatEntries);
  List<ActivityEntry> get feedEntries =>
      List<ActivityEntry>.unmodifiable(_feedEntries);
  List<MemorySnippet> get memories =>
      List<MemorySnippet>.unmodifiable(_memories);
  Map<String, MochiMood> get memberCheckIns =>
      Map<String, MochiMood>.unmodifiable(_memberCheckIns);
  bool get serverOnline => _serverOnline;
  bool get ttsEnabled => _ttsEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get replyPending => _replyPending;

  MochiMood? moodForMember(String memberName) => _memberCheckIns[memberName];

  String greetingFor(String memberName) => switch (_pet.mood) {
    MochiMood.happy => 'Hi $memberName. I kept the room bright for you.',
    MochiMood.laughing =>
      'Hi $memberName. I am wiggly today and ready to play.',
    MochiMood.normal => 'Hi $memberName. Tell me the small thing on your mind.',
    MochiMood.tired =>
      'Hi $memberName. Quiet company sounds perfect right now.',
    MochiMood.sad => 'Hi $memberName. Stay near me for a minute.',
    MochiMood.angry =>
      'Hi $memberName. I need a soft reset, but I am still here.',
    MochiMood.scared => 'Hi $memberName. A gentle hello helps a lot.',
    MochiMood.hungry => 'Hi $memberName. I am collecting snack stories today.',
    MochiMood.confused =>
      'Hi $memberName. I am curious and still figuring things out.',
  };

  void setServerOnline(bool value) {
    if (_serverOnline == value) {
      return;
    }
    _serverOnline = value;
    notifyListeners();
  }

  void setTtsEnabled(bool value) {
    if (_ttsEnabled == value) {
      return;
    }
    _ttsEnabled = value;
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    if (_notificationsEnabled == value) {
      return;
    }
    _notificationsEnabled = value;
    notifyListeners();
  }

  void tapPet(String memberName) {
    _pet = _pet.copyWith(mood: MochiMood.laughing, xp: _pet.xp + 2);
    _prependFeed(
      ActivityEntry(
        title: '$memberName petted Mochi',
        detail: 'The pet bounced happily and sent a tiny surprise reaction.',
        timestamp: 'just now',
        accent: MochiPalette.lightPink,
        icon: Icons.front_hand_rounded,
      ),
    );
    _handleStageUp();
    notifyListeners();
  }

  bool checkIn({required Member member, required MochiMood mood}) {
    if (_memberCheckIns.containsKey(member.name)) {
      return false;
    }

    _memberCheckIns[member.name] = mood;
    _pet = _pet.copyWith(mood: _aggregatePetMood(), xp: _pet.xp + 5);
    _prependFeed(
      ActivityEntry(
        title: '${member.name} checked in as ${mood.label}',
        detail: 'The pet adjusted its tone and mood glow in response.',
        timestamp: 'just now',
        accent: mood.color.withValues(alpha: 0.28),
        icon: Icons.favorite_rounded,
      ),
    );
    _handleStageUp();
    notifyListeners();
    return true;
  }

  Future<void> sendMessage({
    required Member member,
    required String text,
  }) async {
    final PetStage before = _pet.stage;
    _chatEntries.add(
      ChatEntry(
        author: member.name,
        text: text,
        isPet: false,
        timestamp: 'now',
      ),
    );
    _replyPending = true;
    _pet = _pet.copyWith(
      mood: _nextMoodFromConversation(text),
      xp: _pet.xp + 10,
    );
    _prependFeed(
      ActivityEntry(
        title: '${member.name} chatted with Mochi',
        detail: 'A new conversation turn was added to the family pet story.',
        timestamp: 'just now',
        accent: MochiPalette.cloudBlue,
        icon: Icons.chat_bubble_rounded,
      ),
    );
    _handleStageUp(beforeStage: before);
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 420));

    _chatEntries.add(
      ChatEntry(
        author: _pet.name,
        text: _replyFor(text),
        isPet: true,
        timestamp: 'now',
      ),
    );
    _replyPending = false;
    notifyListeners();
  }

  void _handleStageUp({PetStage? beforeStage}) {
    final PetStage before = beforeStage ?? petStageForXp(_pet.xp - 1);
    final PetStage after = _pet.stage;
    if (before == after) {
      return;
    }
    _prependFeed(
      ActivityEntry(
        title: '${_pet.name} reached ${after.label}',
        detail:
            'A new life stage unlocked richer memories and stronger family reactions.',
        timestamp: 'just now',
        accent: MochiPalette.yellow,
        icon: Icons.auto_awesome_rounded,
      ),
    );
    _pet = _pet.copyWith(mood: MochiMood.laughing);
  }

  void _prependFeed(ActivityEntry entry) {
    _feedEntries.insert(0, entry);
    if (_feedEntries.length > 12) {
      _feedEntries.removeLast();
    }
  }

  MochiMood _aggregatePetMood() {
    if (_memberCheckIns.isEmpty) {
      return _pet.mood;
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

    return switch (_pet.mood) {
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
}
