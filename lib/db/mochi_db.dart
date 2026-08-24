import 'dart:io';

import 'package:flutter/foundation.dart';
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
    final Database db = _openWithRecovery(File(path));
    db
      ..execute('PRAGMA journal_mode = WAL;')
      ..execute('PRAGMA busy_timeout = 5000;')
      ..execute('PRAGMA foreign_keys = ON;');
    _runSchema(db);
    _runMigration(db);
    _runFtsSchema(db);
    repairFtsSync(db);
    _instance = MochiDb._(db);
    return _instance!;
  }

  /// Fresh in-memory database for tests: full schema, no platform channels.
  static MochiDb openInMemory() {
    final Database db = sqlite3.openInMemory();
    _runSchema(db);
    _runMigration(db);
    _runFtsSchema(db);
    return MochiDb._(db);
  }

  /// Opens [file], checking for corruption before handing it over.
  ///
  /// SQLite only reports damage when the broken pages get touched, so a
  /// corrupt file can sit unnoticed until the first write hits it. If
  /// `PRAGMA quick_check` fails (structural/page damage), the file(s) are
  /// archived and a fresh database is created.
  static Database _openWithRecovery(File file) {
    Database? db;
    try {
      db = sqlite3.open(file.path);
      final ResultSet rows = db.select('PRAGMA quick_check;');
      if (rows.length == 1 && rows.first.values.first == 'ok') {
        return db;
      }
      debugPrint(
        '[MochiDb] quick_check found the database corrupt: '
        '${rows.map((Row r) => r.values.first.toString()).join('\n')}',
      );
    } catch (error) {
      debugPrint('[MochiDb] cannot read database, rebuilding: $error');
    }
    db?.close();
    _archiveCorrupt(file);
    return sqlite3.open(file.path);
  }

  static void _archiveCorrupt(File file) {
    final String stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[-:.]'), '_');
    for (final String suffix in const <String>['-wal', '-shm', '']) {
      final File part = File('${file.path}$suffix');
      if (part.existsSync()) {
        try {
          part.renameSync('${file.path}.corrupt-$stamp$suffix');
        } catch (error) {
          debugPrint('[MochiDb] could not archive $part: $error');
        }
      }
    }
  }

  /// Re-syncs the FTS5 external-content indexes with their content tables.
  ///
  /// The trigger pair (`memories_ai`/`memories_ad` etc.) keeps the shadow
  /// index in sync with writes. If they drift — a crash mid-write, a file
  /// copy/restore without the WAL, a full disk — the after-DELETE/UPDATE
  /// triggers fail with SQLITE_CORRUPT ("database disk image is malformed",
  /// code 267) and take down unrelated statements like memory pruning.
  ///
  /// Drift is not detectable: plain reads on external-content tables hit the
  /// content table, `integrity-check` cannot see missing index entries, and
  /// counting MATCH hits against the index runs into tombstone ambiguity. So
  /// the index is rebuilt unconditionally on open — `delete-all` + `rebuild`
  /// is cheap at this app's scale and makes the drift impossible by
  /// construction.
  static void repairFtsSync(Database db) {
    final Row enabled = db.select(
      "SELECT sqlite_compileoption_used('ENABLE_FTS5') AS used",
    ).single;
    if (enabled['used'] != 1) {
      return;
    }
    for (final String fts in const <String>[
      'memories_fts',
      'interactions_fts',
    ]) {
      final bool exists = db
              .select(
                'SELECT COUNT(*) AS c FROM sqlite_schema '
                'WHERE name = ? AND type = ?',
                <Object?>[fts, 'table'],
              )
              .single['c'] ==
          1;
      if (!exists) {
        continue;
      }
      try {
        db.execute("INSERT INTO $fts($fts) VALUES('delete-all');");
        db.execute("INSERT INTO $fts($fts) VALUES('rebuild');");
      } on SqliteException catch (error) {
        debugPrint('[MochiDb] $fts rebuild failed: $error');
      }
    }
  }

  /// FTS5 index for long-term recall (Phase 3 of "Mochi Remembers").
  ///
  /// External-content tables mirror `memories` and `interactions`, kept in
  /// sync by triggers. Guarded on `ENABLE_FTS5`; on builds without it the
  /// repository falls back to token-overlap scoring. Backfills existing rows
  /// once so pre-existing data becomes searchable after an upgrade.
  static void _runFtsSchema(Database db) {
    final Row enabled = db.select(
      "SELECT sqlite_compileoption_used('ENABLE_FTS5') AS used",
    ).single;
    if (enabled['used'] != 1) {
      return;
    }

    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
        content,
        content='memories',
        content_rowid='id',
        tokenize='unicode61'
      );

      CREATE TRIGGER IF NOT EXISTS memories_ai
      AFTER INSERT ON memories BEGIN
        INSERT INTO memories_fts(rowid, content)
        VALUES (new.id, new.content);
      END;

      CREATE TRIGGER IF NOT EXISTS memories_ad
      AFTER DELETE ON memories BEGIN
        INSERT INTO memories_fts(memories_fts, rowid, content)
        VALUES ('delete', old.id, old.content);
      END;

      CREATE TRIGGER IF NOT EXISTS memories_au
      AFTER UPDATE ON memories BEGIN
        INSERT INTO memories_fts(memories_fts, rowid, content)
        VALUES ('delete', old.id, old.content);
        INSERT INTO memories_fts(rowid, content)
        VALUES (new.id, new.content);
      END;

      CREATE VIRTUAL TABLE IF NOT EXISTS interactions_fts USING fts5(
        input_text,
        response_text,
        content='interactions',
        content_rowid='id',
        tokenize='unicode61'
      );

      CREATE TRIGGER IF NOT EXISTS interactions_ai
      AFTER INSERT ON interactions BEGIN
        INSERT INTO interactions_fts(rowid, input_text, response_text)
        VALUES (new.id, new.input_text, new.response_text);
      END;

      CREATE TRIGGER IF NOT EXISTS interactions_ad
      AFTER DELETE ON interactions BEGIN
        INSERT INTO interactions_fts(interactions_fts, rowid,
          input_text, response_text)
        VALUES ('delete', old.id, old.input_text, old.response_text);
      END;

      CREATE TRIGGER IF NOT EXISTS interactions_au
      AFTER UPDATE ON interactions BEGIN
        INSERT INTO interactions_fts(interactions_fts, rowid,
          input_text, response_text)
        VALUES ('delete', old.id, old.input_text, old.response_text);
        INSERT INTO interactions_fts(rowid, input_text, response_text)
        VALUES (new.id, new.input_text, new.response_text);
      END;
    ''');

    final int memoryCount =
        db.select('SELECT COUNT(*) AS c FROM memories_fts').single['c'] as int;
    if (memoryCount == 0) {
      db.execute(
        'INSERT INTO memories_fts(rowid, content) '
        'SELECT id, content FROM memories',
      );
    }
    final int interactionCount = db
        .select('SELECT COUNT(*) AS c FROM interactions_fts')
        .single['c'] as int;
    if (interactionCount == 0) {
      db.execute(
        'INSERT INTO interactions_fts(rowid, input_text, response_text) '
        'SELECT id, input_text, response_text FROM interactions',
      );
    }
  }

  static void _runMigration(Database db) {
    final Set<String> memberCols = db
        .select('PRAGMA table_info(members)')
        .map((Row row) => row['name'] as String)
        .toSet();
    if (!memberCols.contains('bio')) {
      db.execute('ALTER TABLE members ADD COLUMN bio TEXT');
    }
    if (!memberCols.contains('birthdate')) {
      db.execute('ALTER TABLE members ADD COLUMN birthdate TEXT');
    }
    db.execute('CREATE INDEX IF NOT EXISTS members_birthdate_idx '
        'ON members (birthdate)');
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
