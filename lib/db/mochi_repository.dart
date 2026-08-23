import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../config/game_config.dart';
import '../models/chat_session.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import 'mochi_db.dart';

class MochiRepository {
  MochiRepository(this._db);

  final MochiDb _db;

  sqlite3.Database get _sql => _db.db;

  // ---- Pet --------------------------------------------------------------

  Pet? getPet() {
    final sqlite3.Row? row = _selectOne('SELECT * FROM pets ORDER BY id LIMIT 1');
    return row == null ? null : _petFromRow(row);
  }

  Pet createPet(String name) {
    _sql.execute(
      'INSERT INTO pets (name, created_at) VALUES (?, ?)',
      <Object?>[name, MochiDb.nowIso()],
    );
    return getPet()!;
  }

  void updatePetName(String name) {
    _sql.execute('UPDATE pets SET name = ?', <Object?>[name]);
  }

  // ---- Profile (single user) --------------------------------------------

  Member? getProfile() {
    final sqlite3.Row? row = _selectOne('SELECT * FROM members ORDER BY id LIMIT 1');
    return row == null ? null : _memberFromRow(row);
  }

  Member createProfile(String name, String colorHex) {
    _sql.execute(
      'INSERT INTO members (name, avatar_color, created_at) VALUES (?, ?, ?)',
      <Object?>[name, colorHex, MochiDb.nowIso()],
    );
    final int id = _sql.lastInsertRowId;
    _sql.execute(
      'INSERT INTO affection (member_id, score, updated_at) VALUES (?, 0, ?)',
      <Object?>[id, MochiDb.nowIso()],
    );
    return getProfile()!;
  }

  void renameProfile(String name) {
    _sql.execute('UPDATE members SET name = ?', <Object?>[name]);
  }

  void touchProfileSeen(DateTime when) {
    _sql.execute(
      'UPDATE members SET last_seen_at = ?',
      <Object?>[when.toUtc().toIso8601String()],
    );
  }

  // ---- Chat sessions ------------------------------------------------------

  int resolveSession({required int memberId, int? requestedSessionId}) {
    if (requestedSessionId != null && requestedSessionId > 0) {
      final sqlite3.Row? owned = _selectOne(
        'SELECT id FROM chat_sessions WHERE id = ?',
        <Object?>[requestedSessionId],
      );
      if (owned != null) {
        return owned['id'] as int;
      }
    }
    _sql.execute(
      'INSERT INTO chat_sessions (member_id, title, created_at) '
      'VALUES (?, ?, ?)',
      <Object?>[memberId, 'New chat', MochiDb.nowIso()],
    );
    return _sql.lastInsertRowId;
  }

  void deriveSessionTitle(int sessionId, String text) {
    final String trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String title = trimmed.length > 48
        ? '${trimmed.substring(0, 45)}...'
        : trimmed;
    _sql.execute(
      'UPDATE chat_sessions SET title = ? '
      'WHERE id = ? AND title = ?',
      <Object?>[title.isEmpty ? 'New chat' : title, sessionId, 'New chat'],
    );
  }

  void touchSession(int sessionId) {
    _sql.execute(
      'UPDATE chat_sessions SET last_message_at = ? WHERE id = ?',
      <Object?>[MochiDb.nowIso(), sessionId],
    );
  }

  List<ChatSession> listSessions({int limit = 50}) {
    final sqlite3.ResultSet rows = _sql.select(
      '''SELECT s.id, s.title, s.created_at, s.last_message_at,
                members.name AS member_name,
                (SELECT COUNT(*) FROM interactions i WHERE i.session_id = s.id)
                  AS message_count,
                (SELECT i.input_text FROM interactions i
                  WHERE i.session_id = s.id
                  ORDER BY i.created_at ASC, i.id ASC LIMIT 1) AS preview
         FROM chat_sessions s
         LEFT JOIN members ON members.id = s.member_id
         ORDER BY COALESCE(s.last_message_at, s.created_at) DESC, s.id DESC
         LIMIT ?''',
      <Object?>[limit],
    );
    return rows.map(_sessionFromRow).toList(growable: false);
  }

  void deleteSession(int sessionId) {
    _sql.execute(
      'DELETE FROM interactions WHERE session_id = ?',
      <Object?>[sessionId],
    );
    _sql.execute(
      'DELETE FROM chat_sessions WHERE id = ?',
      <Object?>[sessionId],
    );
  }

  // ---- Interactions -------------------------------------------------------

  List<ChatEntry> chatHistory({required int sessionId, int limit = 30}) {
    final sqlite3.ResultSet rows = _sql.select(
      '''SELECT i.id, i.input_text, i.response_text, i.created_at,
                members.name AS member_name
         FROM (
           SELECT * FROM interactions
           WHERE session_id = ?
           ORDER BY created_at DESC, id DESC LIMIT ?
         ) i
         JOIN members ON members.id = i.member_id
         ORDER BY i.created_at ASC, i.id ASC''',
      <Object?>[sessionId, limit],
    );
    final List<ChatEntry> entries = <ChatEntry>[];
    for (final sqlite3.Row row in rows) {
      final DateTime createdAt = _parseDate(row['created_at']);
      final String memberName =
          (row['member_name'] as String? ?? 'Family member').trim();
      entries
        ..add(
          ChatEntry(
            id: row['id'] as int,
            author: memberName,
            text: (row['input_text'] as String? ?? '').trim(),
            isPet: false,
            timestamp: _formatClock(createdAt),
            createdAt: createdAt,
          ),
        )
        ..add(
          ChatEntry(
            id: row['id'] as int,
            author: 'Mochi',
            text: (row['response_text'] as String? ?? '').trim(),
            isPet: true,
            timestamp: _formatClock(createdAt),
            createdAt: createdAt,
          ),
        );
    }
    return entries;
  }

  int insertInteraction({
    required int memberId,
    required int sessionId,
    required String inputText,
    required String responseText,
    required String inputType,
    required int xpAwarded,
  }) {
    _sql.execute(
      '''INSERT INTO interactions
         (member_id, session_id, input_text, response_text, input_type,
          xp_awarded, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      <Object?>[
        memberId,
        sessionId,
        inputText,
        responseText,
        inputType,
        xpAwarded,
        MochiDb.nowIso(),
      ],
    );
    return _sql.lastInsertRowId;
  }

  // ---- XP / growth --------------------------------------------------------

  int awardXp({required int memberId, required int amount}) {
    final Pet pet = getPet()!;
    final double modifier = pet.mood.xpModifier;
    final int adjusted = math.max(1, (amount * modifier).round());
    final int affectionGain = math.max(1, (adjusted / 2).ceil());
    final String now = MochiDb.nowIso();

    _sql.execute(
      'UPDATE members SET total_xp = total_xp + ?, last_seen_at = ? '
      'WHERE id = ?',
      <Object?>[adjusted, now, memberId],
    );
    _sql.execute(
      'UPDATE pets SET total_xp = total_xp + ?, last_interaction_at = ?',
      <Object?>[adjusted, now],
    );
    _sql.execute(
      '''INSERT INTO affection (member_id, score, updated_at)
         VALUES (?, ?, ?)
         ON CONFLICT(member_id) DO UPDATE SET
           score = affection.score + excluded.score,
           updated_at = excluded.updated_at''',
      <Object?>[memberId, affectionGain, now],
    );
    return adjusted;
  }

  /// Returns true when the pet advanced to one or more new stages.
  bool checkStagePromotion() {
    final sqlite3.Row row = _sql.select(
      'SELECT stage, total_xp FROM pets ORDER BY id LIMIT 1',
    ).single;
    int currentStage = row['stage'] as int;
    final int totalXp = row['total_xp'] as int;

    int nextStage = currentStage;
    for (final PetStage stage in PetStage.values) {
      if (totalXp >= petStageThresholds[stage]!) {
        nextStage = petStageNumber(stage);
      }
    }
    if (nextStage <= currentStage) {
      return false;
    }

    final List<int> crossed = <int>[
      for (PetStage stage in PetStage.values)
        if (petStageNumber(stage) > currentStage &&
            petStageNumber(stage) <= nextStage)
          petStageNumber(stage),
    ];
    final String now = MochiDb.nowIso();
    for (final int stage in crossed) {
      _sql.execute(
        'INSERT INTO stage_events (stage, created_at) VALUES (?, ?)',
        <Object?>[stage, now],
      );
    }
    _sql.execute('UPDATE pets SET stage = ?', <Object?>[nextStage]);
    return true;
  }

  // ---- Mood ---------------------------------------------------------------

  bool memberCheckedInToday(int memberId) {
    final String dayStart = _dayStartUtc;
    final sqlite3.Row? row = _selectOne(
      'SELECT id FROM mood_log WHERE member_id = ? AND created_at >= ?',
      <Object?>[memberId, dayStart],
    );
    return row != null;
  }

  void recordMoodCheckIn({required int memberId, required String mood}) {
    _sql.execute(
      'INSERT INTO mood_log (member_id, mood, created_at) VALUES (?, ?, ?)',
      <Object?>[memberId, mood, MochiDb.nowIso()],
    );
  }

  String recalculateMood() {
    final Pet pet = getPet()!;
    final DateTime now = DateTime.now().toUtc();

    final List<String> recentMoods = _sql
        .select(
          '''SELECT mood FROM mood_log
             WHERE created_at >= ?
             ORDER BY created_at DESC''',
          <Object?>[now.subtract(const Duration(hours: 3)).toIso8601String()],
        )
        .map((sqlite3.Row r) => r['mood'] as String)
        .toList();

    final int recentChats = _sql
        .select(
          '''SELECT COUNT(*) AS count FROM interactions
             WHERE created_at >= ?''',
          <Object?>[now.subtract(const Duration(hours: 1)).toIso8601String()],
        )
        .single['count'] as int;

    double score = 70;
    for (final String mood in recentMoods) {
      score += moodDelta[mood] ?? 0;
    }
    score += math.min(recentChats * 4, 20);

    final double inactivityHours = pet.lastInteractionAt == null
        ? 0
        : now.difference(pet.lastInteractionAt!.toUtc()).inSeconds / 3600.0;

    if (inactivityHours >= GameConfig.moodDecayHours * 2) {
      score = math.min(score, 28);
    } else if (inactivityHours >= GameConfig.moodDecayHours) {
      score = math.min(score, 42);
    }
    score = _clamp(score.round(), 0, 100).toDouble();

    final MochiMood mood = pickMood(
      score.round(),
      recentMoods,
      recentChats,
      inactivityHours,
    );

    _sql.execute(
      'UPDATE pets SET mood = ?, mood_score = ?',
      <Object?>[mood.name, score.round()],
    );
    return mood.name;
  }

  static final Map<String, double> moodDelta = <String, double>{
    'happy': 12,
    'sad': -14,
    'angry': -20,
    'normal': 0,
    'tired': -10,
    'confused': -6,
    'laughing': 16,
    'hungry': -12,
    'scared': -22,
  };

  static MochiMood pickMood(
    int score,
    List<String> recentMoods,
    int recentChats,
    double inactivityHours,
  ) {
    if (inactivityHours >= GameConfig.moodDecayHours * 2) {
      return MochiMood.hungry;
    }
    if (inactivityHours >= GameConfig.moodDecayHours) {
      return MochiMood.tired;
    }
    if (recentMoods.take(3).toSet().length >= 3 &&
        score >= 35 &&
        score <= 75) {
      return MochiMood.confused;
    }
    if (score >= 90 || recentChats >= 4) {
      return MochiMood.laughing;
    }
    if (score >= 78) {
      return MochiMood.happy;
    }
    if (_dominantCount(recentMoods, 'scared') >= 2 || score <= 10) {
      return MochiMood.scared;
    }
    if (_dominantCount(recentMoods, 'angry') >= 2 || score <= 25) {
      return MochiMood.angry;
    }
    if (_dominantCount(recentMoods, 'sad') >= 2 || score <= 45) {
      return MochiMood.sad;
    }
    return MochiMood.normal;
  }

  // ---- Taps ---------------------------------------------------------------

  int tapCooldownRemainingSeconds({required int memberId}) {
    final sqlite3.Row? last = _selectOne(
      'SELECT created_at FROM pet_taps WHERE member_id = ? ORDER BY created_at DESC LIMIT 1',
      <Object?>[memberId],
    );
    if (last == null) {
      return 0;
    }
    final DateTime? lastAt = DateTime.tryParse(
      last['created_at'] as String,
    )?.toUtc();
    if (lastAt == null) {
      return 0;
    }
    final int elapsed = DateTime.now().toUtc().difference(lastAt).inSeconds;
    final int remaining = GameConfig.tapCooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  int tapPet({required int memberId}) {
    if (tapCooldownRemainingSeconds(memberId: memberId) > 0) {
      return 0;
    }
    final int xpAwarded = awardXp(memberId: memberId, amount: GameConfig.xpPerTap);
    _sql.execute(
      'INSERT INTO pet_taps (member_id, xp_awarded, created_at) VALUES (?, ?, ?)',
      <Object?>[memberId, xpAwarded, MochiDb.nowIso()],
    );
    _sql.execute(
      '''UPDATE pets
         SET mood = 'laughing',
             mood_score = CASE WHEN mood_score < 88 THEN 88 ELSE mood_score END''',
    );
    checkStagePromotion();
    return xpAwarded;
  }

  // ---- Memories -----------------------------------------------------------

  List<MemorySnippet> listMemories({int limit = 10}) {
    final sqlite3.ResultSet rows = _sql.select(
      '''SELECT memories.id, memories.member_id, memories.content,
                memories.weight, memories.created_at,
                members.name AS member_name
         FROM memories
         LEFT JOIN members ON members.id = memories.member_id
         ORDER BY memories.weight DESC, memories.created_at DESC
         LIMIT ?''',
      <Object?>[limit],
    );
    return rows.map(_memoryFromRow).toList(growable: false);
  }

  int addMemory({
    required int memberId,
    required String content,
    required int weight,
  }) {
    _sql.execute(
      'INSERT INTO memories (member_id, content, weight, created_at) '
      'VALUES (?, ?, ?, ?)',
      <Object?>[memberId, content, weight, MochiDb.nowIso()],
    );
    return _sql.lastInsertRowId;
  }

  void updateMemory({required int id, String? content, int? weight}) {
    final List<String> sets = <String>[];
    final List<Object> values = <Object>[];
    if (content != null) {
      sets.add('content = ?');
      values.add(content);
    }
    if (weight != null) {
      sets.add('weight = ?');
      values.add(weight);
    }
    if (sets.isEmpty) {
      return;
    }
    values.add(id);
    _sql.execute(
      'UPDATE memories SET ${sets.join(', ')} WHERE id = ?',
      values,
    );
  }

  void deleteMemory(int id) {
    _sql.execute('DELETE FROM memories WHERE id = ?', <Object?>[id]);
  }

  /// Port of `server/src/services/memories.ts` upsertMemory: exact-match
  /// lines reinforce, else insert with weight 2 while capping per-member
  /// count at [GameConfig.maxMemoriesPerMember].
  void upsertMemory({required int memberId, required String content}) {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final String clipped = trimmed.length > 240
        ? trimmed.substring(0, 240)
        : trimmed;

    final sqlite3.Row? similar = _selectOne(
      'SELECT id, weight FROM memories WHERE member_id = ? AND content = ?',
      <Object?>[memberId, clipped],
    );
    if (similar != null) {
      _sql.execute(
        'UPDATE memories SET weight = MIN(weight + 1, 5) WHERE id = ?',
        <Object?>[similar['id']],
      );
      return;
    }

    final int count =
        _sql.select(
              'SELECT COUNT(*) AS count FROM memories WHERE member_id = ?',
              <Object?>[memberId],
            ).single['count'] as int;

    if (count >= GameConfig.maxMemoriesPerMember) {
      _sql.execute(
        '''DELETE FROM memories WHERE id = (
             SELECT id FROM memories
             WHERE member_id = ?
             ORDER BY weight ASC, created_at ASC LIMIT 1)''',
        <Object?>[memberId],
      );
    }
    _sql.execute(
      'INSERT INTO memories (member_id, content, weight, created_at) '
      'VALUES (?, ?, 2, ?)',
      <Object?>[memberId, clipped, MochiDb.nowIso()],
    );
  }

  void pruneStaleMemories() {
    final String cutoff =
        DateTime.now()
            .toUtc()
            .subtract(const Duration(days: GameConfig.memoryPruneDays))
            .toIso8601String();
    _sql.execute(
      'DELETE FROM memories WHERE weight <= 2 AND created_at <= ?',
      <Object?>[cutoff],
    );
  }

  /// Today's mood check-ins keyed by member id (server `/mood/log` port).
  Map<int, MochiMood> todayMoodMap() {
    final sqlite3.ResultSet rows = _sql.select(
      '''SELECT member_id, mood FROM mood_log
         WHERE created_at >= ?
         ORDER BY created_at DESC''',
      <Object?>[_dayStartUtc],
    );
    final Map<int, MochiMood> map = <int, MochiMood>{};
    for (final sqlite3.Row row in rows) {
      final int memberId = row['member_id'] as int;
      map.putIfAbsent(memberId, () => mochiMoodFromString(row['mood'] as String));
    }
    return map;
  }

  /// Top-3 memory contents for the prompt block (`ORDER BY weight DESC`).
  List<String> memoriesForPrompt() {
    return _sql
        .select(
          '''SELECT content FROM memories
             ORDER BY weight DESC, created_at DESC LIMIT 3''',
        )
        .map((sqlite3.Row row) => row['content'] as String)
        .toList(growable: false);
  }

  // ---- Feed ---------------------------------------------------------------
  List<ActivityEntry> feed({int limit = 30}) {
    final List<Map<String, dynamic>> events = <Map<String, dynamic>>[];

    for (final sqlite3.Row row
        in _sql.select(
          '''SELECT interactions.id, interactions.created_at,
                    members.id AS member_id, members.name AS member_name
             FROM interactions
             JOIN members ON members.id = interactions.member_id
             ORDER BY interactions.created_at DESC LIMIT ?''',
          <Object?>[limit],
        )) {
      events.add(<String, dynamic>{
        'event_type': 'chat',
        'created_at': row['created_at'],
        'member_name': row['member_name'],
        'detail': 'chatted with Mochi',
      });
    }

    for (final sqlite3.Row row
        in _sql.select(
          '''SELECT mood_log.id, mood_log.created_at, mood_log.mood,
                    members.id AS member_id, members.name AS member_name
             FROM mood_log
             JOIN members ON members.id = mood_log.member_id
             ORDER BY mood_log.created_at DESC LIMIT ?''',
          <Object?>[limit],
        )) {
      events.add(<String, dynamic>{
        'event_type': 'mood_checkin',
        'created_at': row['created_at'],
        'member_name': row['member_name'],
        'detail': 'checked in as ${row['mood']}',
      });
    }

    for (final sqlite3.Row row
        in _sql.select(
          '''SELECT id, stage, created_at FROM stage_events
             ORDER BY created_at DESC LIMIT ?''',
          <Object?>[limit],
        )) {
      final int stage = row['stage'] as int;
      events.add(<String, dynamic>{
        'event_type': 'stage_up',
        'created_at': row['created_at'],
        'detail': 'Mochi reached ${petStageFromNumber(stage).label}',
      });
    }

    for (final sqlite3.Row row
        in _sql.select(
          '''SELECT pet_taps.id, pet_taps.created_at,
                    members.id AS member_id, members.name AS member_name
             FROM pet_taps
             JOIN members ON members.id = pet_taps.member_id
             ORDER BY pet_taps.created_at DESC LIMIT ?''',
          <Object?>[limit],
        )) {
      events.add(<String, dynamic>{
        'event_type': 'pet_tap',
        'created_at': row['created_at'],
        'member_name': row['member_name'],
        'detail': 'petted Mochi',
      });
    }

    events.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );

    return events
        .take(limit)
        .map(ActivityEntry.fromJson)
        .toList(growable: false);
  }

  // ---- Mapping helpers ----------------------------------------------------

  Pet _petFromRow(sqlite3.Row row) {
    return Pet(
      id: row['id'] as int,
      name: (row['name'] as String? ?? 'Mochi').trim(),
      stageNumber: row['stage'] as int,
      xp: row['total_xp'] as int,
      mood: mochiMoodFromString(row['mood'] as String? ?? 'normal'),
      moodScore: row['mood_score'] as int,
      lastInteractionAt: _parseDateOrNull(row['last_interaction_at']),
      createdAt: _parseDate(row['created_at']),
    );
  }

  Member _memberFromRow(sqlite3.Row row) {
    final int xp = row['total_xp'] as int;
    final sqlite3.Row? affection = _selectOne(
      'SELECT score FROM affection WHERE member_id = ?',
      <Object?>[row['id']],
    );
    final int affectionScore =
        affection == null ? 0 : affection['score'] as int;
    return Member(
      id: row['id'] as int,
      name: (row['name'] as String? ?? 'Family member').trim(),
      color: _colorFromHex(row['avatar_color'] as String? ?? '#1D9E75'),
      affection: affectionScore,
      xp: xp,
      note: _defaultMemberNote(xp: xp, affection: affectionScore),
      username: '',
      isAdmin: false,
      invitePending: false,
      lastSeenAt: _parseDate(row['last_seen_at']),
    );
  }

  ChatSession _sessionFromRow(sqlite3.Row row) {
    final DateTime createdAt = _parseDate(row['created_at']);
    final DateTime? lastMessageAt = _parseDateOrNull(row['last_message_at']);
    return ChatSession(
      id: row['id'] as int,
      title: (row['title'] as String? ?? '').trim().isEmpty
          ? 'New chat'
          : (row['title'] as String).trim(),
      preview: (row['preview'] as String? ?? '').trim(),
      messageCount: row['message_count'] as int,
      memberName: (row['member_name'] as String? ?? 'Family').trim(),
      timestamp: _formatRelative(lastMessageAt ?? createdAt),
      createdAt: createdAt,
      lastMessageAt: lastMessageAt,
    );
  }

  MemorySnippet _memoryFromRow(sqlite3.Row row) {
    final int weight = row['weight'] as int;
    final DateTime createdAt = _parseDate(row['created_at']);
    final String memberName = (row['member_name'] as String? ?? 'Family')
        .trim();
    return MemorySnippet(
      id: row['id'] as int,
      title: '$memberName memory',
      body: (row['content'] as String? ?? '').trim(),
      timestamp: 'Saved ${_formatRelative(createdAt).toLowerCase()}',
      accent: switch (weight) {
        >= 4 => const Color(0xFFFFF0B5),
        3 => const Color(0xFFFFE0EC),
        _ => const Color(0xFFD8F0FF),
      },
    );
  }

  // ---- Helpers --------------------------------------------------------------

  sqlite3.Row? _selectOne(String sql, [List<Object?> args = const <Object?>[]]) {
    final sqlite3.ResultSet rows = _sql.select(sql, args);
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  static String get _dayStartUtc {
    final DateTime now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day).toIso8601String();
  }

  static int _clamp(int value, int min, int max) =>
      math.max(min, math.min(max, value));

  static int _dominantCount(List<String> moods, String target) =>
      moods.where((String mood) => mood == target).length;
}

DateTime _parseDate(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return DateTime.now();
  }
  return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
}

DateTime? _parseDateOrNull(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

Color _colorFromHex(String raw) {
  final String normalized = raw.replaceFirst('#', '').trim();
  final String hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.tryParse(hex, radix: 16) ?? 0xFF1D9E75);
}

String _defaultMemberNote({required int xp, required int affection}) {
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
