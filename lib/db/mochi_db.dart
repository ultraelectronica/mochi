import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Local on-device database (SQLite via FFI).
///
/// Schema is a single-user port of `server/src/db/migrations.ts` minus the
/// server-only tables (households, accounts, invites, sessions).
class MochiDb {
  MochiDb._(this.db);

  final Database db;

  static MochiDb? _instance;

  static Future<MochiDb> instance() async {
    if (_instance != null) {
      return _instance!;
    }
    final Directory dir = await getApplicationSupportDirectory();
    final String path = p.join(dir.path, 'mochi.db');
    final Database db = sqlite3.open(path);
    db
      ..execute('PRAGMA journal_mode = WAL;')
      ..execute('PRAGMA busy_timeout = 5000;')
      ..execute('PRAGMA foreign_keys = ON;');
    _runSchema(db);
    _instance = MochiDb._(db);
    return _instance!;
  }

  static void _runSchema(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS pets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL DEFAULT 'Mochi',
        stage INTEGER NOT NULL DEFAULT 1,
        total_xp INTEGER NOT NULL DEFAULT 0,
        mood TEXT NOT NULL DEFAULT 'normal',
        mood_score INTEGER NOT NULL DEFAULT 70,
        last_interaction_at TEXT,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        avatar_color TEXT NOT NULL DEFAULT '#1D9E75',
        total_xp INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_seen_at TEXT
      );

      CREATE TABLE IF NOT EXISTS chat_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        title TEXT NOT NULL DEFAULT 'New chat',
        created_at TEXT NOT NULL,
        last_message_at TEXT
      );

      CREATE TABLE IF NOT EXISTS interactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        session_id INTEGER REFERENCES chat_sessions(id) ON DELETE CASCADE,
        input_text TEXT NOT NULL,
        response_text TEXT NOT NULL,
        input_type TEXT NOT NULL DEFAULT 'text' CHECK (input_type IN ('text', 'voice')),
        xp_awarded INTEGER NOT NULL DEFAULT 10,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        weight INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS affection (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL UNIQUE REFERENCES members(id) ON DELETE CASCADE,
        score INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS mood_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        mood TEXT NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS pet_taps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        xp_awarded INTEGER NOT NULL DEFAULT 2,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS stage_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stage INTEGER NOT NULL,
        created_at TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS interactions_session_idx
        ON interactions (session_id, created_at);
      CREATE INDEX IF NOT EXISTS interactions_created_idx
        ON interactions (created_at);
      CREATE INDEX IF NOT EXISTS chat_sessions_updated_idx
        ON chat_sessions (last_message_at);
      CREATE INDEX IF NOT EXISTS memories_created_idx
        ON memories (created_at);
      CREATE INDEX IF NOT EXISTS mood_log_created_idx
        ON mood_log (created_at);
      CREATE INDEX IF NOT EXISTS pet_taps_created_idx
        ON pet_taps (created_at);
      CREATE INDEX IF NOT EXISTS stage_events_created_idx
        ON stage_events (created_at);
    ''');
  }

  /// UTC ISO-8601 timestamp matching the server's `strftime('%Y-%m-%dT%H:%M:%fZ','now')`.
  static String nowIso() => DateTime.now().toUtc().toIso8601String();
}
