import 'package:flutter/material.dart';

class Member {
  const Member({
    required this.id,
    required this.name,
    required this.color,
    required this.affection,
    required this.xp,
    required this.note,
    required this.username,
    required this.isAdmin,
    required this.invitePending,
    this.lastSeenAt,
    this.bio,
    this.birthdate,
  });

  final int id;
  final String name;
  final Color color;
  final int affection;
  final int xp;
  final String note;
  final String username;
  final bool isAdmin;
  final bool invitePending;
  final DateTime? lastSeenAt;
  final String? bio;
  final DateTime? birthdate;

  int? get age => ageFromBirthdate(birthdate);

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
        username: (json['username'] as String? ?? '').trim(),
        isAdmin: json['is_admin'] == true || json['is_admin'] == 1,
        invitePending:
            json['invite_pending'] == true || json['invite_pending'] == 1,
        lastSeenAt: _parseDateTime(json['last_seen_at']),
        bio: _parseBio(json['bio']),
        birthdate: _parseDateOnly(json['birthdate']),
      );
  }

  String get initials {
    final List<String> parts = name.split(' ');
    return parts
        .take(2)
        .map((String part) => part.substring(0, 1).toUpperCase())
        .join();
  }

  static const Object _unset = Object();

  Member copyWith({
    int? id,
    String? name,
    Color? color,
    int? affection,
    int? xp,
    String? note,
    String? username,
    bool? isAdmin,
    bool? invitePending,
    DateTime? lastSeenAt,
    Object? bio = _unset,
    Object? birthdate = _unset,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      affection: affection ?? this.affection,
      xp: xp ?? this.xp,
      note: note ?? this.note,
      username: username ?? this.username,
      isAdmin: isAdmin ?? this.isAdmin,
      invitePending: invitePending ?? this.invitePending,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      bio: identical(bio, _unset) ? this.bio : bio as String?,
      birthdate: identical(birthdate, _unset)
          ? this.birthdate
          : birthdate as DateTime?,
    );
  }
}

class CreatedMemberInvite {
  const CreatedMemberInvite({required this.member, required this.inviteCode});

  final Member member;
  final String inviteCode;
}

class MemberMoodLog {
  const MemberMoodLog({required this.mood, required this.createdAt});

  factory MemberMoodLog.fromJson(Map<String, dynamic> json) {
    return MemberMoodLog(
      mood: (json['mood'] as String? ?? 'normal').trim(),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  final String mood;
  final DateTime createdAt;
}

class MemberDetail {
  const MemberDetail({required this.member, required this.recentMoodLogs});

  factory MemberDetail.fromJson(Map<String, dynamic> json) {
    return MemberDetail(
      member: Member.fromJson(json),
      recentMoodLogs:
          (json['recent_mood_logs'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(MemberMoodLog.fromJson)
              .toList(growable: false),
    );
  }

  final Member member;
  final List<MemberMoodLog> recentMoodLogs;
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

DateTime? _parseDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

String? _parseBio(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final String trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDateOnly(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int? ageFromBirthdate(DateTime? birthdate) {
  if (birthdate == null) {
    return null;
  }
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime bd = DateTime(birthdate.year, birthdate.month, birthdate.day);
  if (bd.isAfter(today)) {
    return null;
  }
  int years = today.year - bd.year;
  if (today.month < bd.month ||
      (today.month == bd.month && today.day < bd.day)) {
    years--;
  }
  return years;
}

String formatBirthdate(DateTime birthdate) {
  final String y = birthdate.year.toString().padLeft(4, '0');
  final String m = birthdate.month.toString().padLeft(2, '0');
  final String d = birthdate.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
