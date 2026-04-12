import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';

class MemberProvider extends ChangeNotifier {
  MemberProvider.seeded()
    : _members = <Member>[
        const Member(
          name: 'Fyke',
          color: MochiPalette.sky,
          affection: 88,
          xp: 214,
          note: 'Always sends the first good-morning message.',
        ),
        const Member(
          name: 'Honey',
          color: Color(0xFFFFAFCB),
          affection: 73,
          xp: 178,
          note: 'Keeps Mochi laughing with voice notes.',
        ),
        const Member(
          name: 'Elise',
          color: Color(0xFFFFD466),
          affection: 67,
          xp: 142,
          note: 'Best at mood check-ins after school.',
        ),
        const Member(
          name: 'Ally',
          color: Color(0xFFA9E6BE),
          affection: 59,
          xp: 121,
          note: 'Leaves calm nighttime messages for later.',
        ),
        const Member(
          name: 'Toyo',
          color: Color(0xFFA9E6BE),
          affection: 59,
          xp: 121,
          note: 'Leaves calm nighttime messages for later.',
        ),
      ];

  final List<Member> _members;
  int _selectedIndex = 0;

  List<Member> get members => List<Member>.unmodifiable(_members);

  int get selectedIndex => _selectedIndex;

  Member get currentMember => _members[_selectedIndex];

  void selectMember(int index) {
    if (index < 0 || index >= _members.length || index == _selectedIndex) {
      return;
    }
    _selectedIndex = index;
    notifyListeners();
  }

  void rewardCurrentMember({required int xp, required int affection}) {
    final Member current = currentMember;
    _members[_selectedIndex] = current.copyWith(
      xp: current.xp + xp,
      affection: math.min(99, current.affection + affection),
    );
    notifyListeners();
  }
}
