import { config } from '../config/index.ts'
import db from './index.ts'

const nowSql = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')"
const moodCheckSql = config.moods.map(({ key }) => `'${key}'`).join(', ')

export function runMigrations() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS pet (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL DEFAULT 'Mochi',
      stage INTEGER NOT NULL DEFAULT 1,
      total_xp INTEGER NOT NULL DEFAULT 0,
      mood TEXT NOT NULL DEFAULT 'normal' CHECK (mood IN (${moodCheckSql})),
      mood_score INTEGER NOT NULL DEFAULT 70,
      last_interaction_at TEXT,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      avatar_color TEXT NOT NULL DEFAULT '#1D9E75',
      total_xp INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (${nowSql}),
      last_seen_at TEXT
    );

    CREATE TABLE IF NOT EXISTS interactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      input_text TEXT NOT NULL,
      response_text TEXT NOT NULL,
      input_type TEXT NOT NULL DEFAULT 'text' CHECK (input_type IN ('text', 'voice')),
      xp_awarded INTEGER NOT NULL DEFAULT 10,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS memories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      content TEXT NOT NULL,
      weight INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS affection (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL UNIQUE REFERENCES members(id) ON DELETE CASCADE,
      score INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS mood_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      mood TEXT NOT NULL CHECK (mood IN (${moodCheckSql})),
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS stage_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      stage INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );
  `)

  db.prepare("INSERT OR IGNORE INTO pet (id, name) VALUES (1, 'Mochi')").run()
}
