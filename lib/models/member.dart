import 'package:flutter/material.dart';

class Member {
  const Member({
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

  Member copyWith({
    String? name,
    Color? color,
    int? affection,
    int? xp,
    String? note,
  }) {
    return Member(
      name: name ?? this.name,
      color: color ?? this.color,
      affection: affection ?? this.affection,
      xp: xp ?? this.xp,
      note: note ?? this.note,
    );
  }
}
