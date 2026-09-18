class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.preview,
    required this.messageCount,
    required this.memberName,
    required this.timestamp,
    required this.createdAt,
    this.lastMessageAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final DateTime createdAt =
        _parseDateTime(json['created_at']) ?? DateTime.now();
    final DateTime? lastMessageAt =
        _parseDateTime(json['last_message_at']);
    final DateTime reference = lastMessageAt ?? createdAt;

    return ChatSession(
      id: _asInt(json['id']),
      title: (json['title'] as String? ?? '').trim().isEmpty
          ? 'New chat'
          : (json['title'] as String).trim(),
      preview: (json['preview'] as String? ?? '').trim(),
      messageCount: _asInt(json['message_count']),
      memberName: (json['member_name'] as String? ?? 'Family').trim(),
      timestamp: _formatRelative(reference),
      createdAt: createdAt,
      lastMessageAt: lastMessageAt,
    );
  }

  final int id;
  final String title;
  final String preview;
  final int messageCount;
  final String memberName;
  final String timestamp;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}

String _formatRelative(DateTime value) {
  final Duration delta = DateTime.now().difference(value);

  if (delta.inMinutes < 1) {
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

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
