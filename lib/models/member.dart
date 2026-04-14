import 'package:flutter/material.dart';

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.color,
    required this.affection,
    required this.xp,
    required this.note,
  });

  final int id;
  final String name;
  final Color color;
  final int affection;
  final int xp;
  final String note;

  factory Member.fromJson(Map<String, dynamic> json) {
    final int xp = _asInt(json['total_xp']);
    final int affection = _asInt(json['affection_score']);
    return Member(
      id: _asInt(json['id']),
      name: (json['name'] as String? ?? 'Family member').trim(),
      color: _colorFromHex(json['avatar_color'] as String? ?? '#1D9E75'),
      affection: affection,
      xp: xp,
      note: (json['note'] as String?)?.trim().isNotEmpty == true
          ? (json['note'] as String).trim()
          : _defaultNote(xp: xp, affection: affection),
    );
  }

  String get initials {
    final List<String> parts = name.split(' ');
    return parts
        .take(2)
        .map((String part) => part.substring(0, 1).toUpperCase())
        .join();
  }

  Member copyWith({
    int? id,
    String? name,
    Color? color,
    int? affection,
    int? xp,
    String? note,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      affection: affection ?? this.affection,
      xp: xp ?? this.xp,
      note: note ?? this.note,
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Color _colorFromHex(String raw) {
  final String normalized = raw.replaceFirst('#', '').trim();
  final String hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.tryParse(hex, radix: 16) ?? 0xFF1D9E75);
}

String _defaultNote({required int xp, required int affection}) {
  if (affection >= 80) {
    return 'Very close to Mochi and always nearby.';
  }
  if (xp >= 120) {
    return 'One of Mochi\'s most active family voices.';
  }
  if (xp > 0) {
    return 'Still building shared memories with Mochi.';
  }
  return 'Ready to start a first tiny moment with Mochi.';
}
