import { config } from '../config/index.ts'
import { createInviteCode, fallbackUsername } from '../services/auth.ts'
import db from './index.ts'

const nowSql = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')"
const moodCheckSql = config.moods.map(({ key }) => `'${key}'`).join(', ')

type TableInfoRow = {
  name: string
}

function tableExists(name: string) {
  return Boolean(
    db
      .prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?")
      .get(name),
  )
}

function columnExists(table: string, column: string) {
  return (db.prepare(`PRAGMA table_info(${table})`).all() as TableInfoRow[]).some(
    (row) => row.name === column,
  )
}

function ensureColumn(table: string, definition: string) {
  const column = definition.trim().split(/\s+/)[0]

  if (columnExists(table, column)) {
    return
  }

  db.exec(`ALTER TABLE ${table} ADD COLUMN ${definition}`)
}

function ensureIndex(name: string, sql: string) {
  if (
    db
      .prepare("SELECT 1 FROM sqlite_master WHERE type = 'index' AND name = ?")
      .get(name)
  ) {
    return
  }

  db.exec(sql)
}

function ensureDefaultHousehold() {
  db.prepare(
    `INSERT OR IGNORE INTO households (id, name, code)
     VALUES (1, 'Home', 'HOME01')`,
  ).run()
}

function createLegacyAccounts() {
  if (!tableExists('members')) {
    return
  }

  const members = db
    .prepare(
      `SELECT members.id, members.household_id, members.name
       FROM members
       LEFT JOIN accounts ON accounts.member_id = members.id
       WHERE accounts.id IS NULL
       ORDER BY members.id ASC`,
    )
    .all() as Array<{ id: number; household_id: number; name: string }>

  for (const member of members) {
    let username = fallbackUsername(member.name, member.id)
    let suffix = 2

    while (
      db
        .prepare(
          `SELECT 1
           FROM accounts
           WHERE household_id = ? AND username = ?`,
        )
        .get(member.household_id, username)
    ) {
      username = `${fallbackUsername(member.name, member.id)}${suffix}`
      suffix += 1
    }

    const result = db
      .prepare(
        `INSERT INTO accounts (household_id, member_id, username, is_admin)
         VALUES (?, ?, ?, ?)`,
      )
      .run(member.household_id, member.id, username, member.id === 1 ? 1 : 0)

    db.prepare(
      `INSERT INTO account_invites (account_id, household_id, code)
       VALUES (?, ?, ?)`,
    ).run(result.lastInsertRowid, member.household_id, createInviteCode())
  }
}

export function runMigrations() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS households (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS pets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER NOT NULL UNIQUE REFERENCES households(id) ON DELETE CASCADE,
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
      household_id INTEGER REFERENCES households(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      avatar_color TEXT NOT NULL DEFAULT '#1D9E75',
      total_xp INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (${nowSql}),
      last_seen_at TEXT
    );

    CREATE TABLE IF NOT EXISTS interactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER REFERENCES households(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      input_text TEXT NOT NULL,
      response_text TEXT NOT NULL,
      input_type TEXT NOT NULL DEFAULT 'text' CHECK (input_type IN ('text', 'voice')),
      xp_awarded INTEGER NOT NULL DEFAULT 10,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS memories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER REFERENCES households(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      content TEXT NOT NULL,
      weight INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS affection (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER REFERENCES households(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL UNIQUE REFERENCES members(id) ON DELETE CASCADE,
      score INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS mood_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER REFERENCES households(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      mood TEXT NOT NULL CHECK (mood IN (${moodCheckSql})),
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS pet_taps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER REFERENCES households(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      xp_awarded INTEGER NOT NULL DEFAULT 2,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS stage_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER REFERENCES households(id) ON DELETE CASCADE,
      stage INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER NOT NULL REFERENCES households(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL UNIQUE REFERENCES members(id) ON DELETE CASCADE,
      username TEXT NOT NULL,
      password_hash TEXT NOT NULL DEFAULT '',
      password_salt TEXT NOT NULL DEFAULT '',
      is_admin INTEGER NOT NULL DEFAULT 0 CHECK (is_admin IN (0, 1)),
      created_at TEXT NOT NULL DEFAULT (${nowSql}),
      UNIQUE (household_id, username)
    );

    CREATE TABLE IF NOT EXISTS account_invites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL UNIQUE REFERENCES accounts(id) ON DELETE CASCADE,
      household_id INTEGER NOT NULL REFERENCES households(id) ON DELETE CASCADE,
      created_by_account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
      code TEXT NOT NULL UNIQUE,
      accepted_at TEXT,
      created_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS auth_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
      token_hash TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL DEFAULT (${nowSql}),
      last_used_at TEXT NOT NULL DEFAULT (${nowSql})
    );

    CREATE TABLE IF NOT EXISTS chat_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      household_id INTEGER NOT NULL REFERENCES households(id) ON DELETE CASCADE,
      member_id INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
      title TEXT NOT NULL DEFAULT 'New chat',
      created_at TEXT NOT NULL DEFAULT (${nowSql}),
      last_message_at TEXT
    );
  `)

  ensureColumn('members', 'household_id INTEGER REFERENCES households(id) ON DELETE CASCADE')
  ensureColumn('interactions', 'household_id INTEGER REFERENCES households(id) ON DELETE CASCADE')
  ensureColumn('interactions', 'session_id INTEGER REFERENCES chat_sessions(id) ON DELETE CASCADE')
  ensureColumn('memories', 'household_id INTEGER REFERENCES households(id) ON DELETE CASCADE')
  ensureColumn('affection', 'household_id INTEGER REFERENCES households(id) ON DELETE CASCADE')
  ensureColumn('mood_log', 'household_id INTEGER REFERENCES households(id) ON DELETE CASCADE')
  ensureColumn('pet_taps', 'household_id INTEGER REFERENCES households(id) ON DELETE CASCADE')
  ensureColumn('stage_events', 'household_id INTEGER REFERENCES households(id) ON DELETE CASCADE')

  ensureIndex(
    'members_household_idx',
    'CREATE INDEX members_household_idx ON members (household_id)',
  )
  ensureIndex(
    'interactions_household_idx',
    'CREATE INDEX interactions_household_idx ON interactions (household_id, created_at)',
  )
  ensureIndex(
    'interactions_session_idx',
    'CREATE INDEX interactions_session_idx ON interactions (session_id, created_at)',
  )
  ensureIndex(
    'chat_sessions_household_idx',
    'CREATE INDEX chat_sessions_household_idx ON chat_sessions (household_id, last_message_at)',
  )
  ensureIndex(
    'memories_household_idx',
    'CREATE INDEX memories_household_idx ON memories (household_id, created_at)',
  )
  ensureIndex(
    'mood_log_household_idx',
    'CREATE INDEX mood_log_household_idx ON mood_log (household_id, created_at)',
  )
  ensureIndex(
    'pet_taps_household_idx',
    'CREATE INDEX pet_taps_household_idx ON pet_taps (household_id, created_at)',
  )
  ensureIndex(
    'stage_events_household_idx',
    'CREATE INDEX stage_events_household_idx ON stage_events (household_id, created_at)',
  )

  const hasLegacyPet =
    tableExists('pet') &&
    Boolean(
      db.prepare('SELECT 1 FROM pet WHERE id = 1').get(),
    )

  const hasLegacyMembers =
    tableExists('members') &&
    Boolean(
      db.prepare('SELECT 1 FROM members LIMIT 1').get(),
    )

  if (hasLegacyPet || hasLegacyMembers) {
    ensureDefaultHousehold()

    db.prepare('UPDATE members SET household_id = 1 WHERE household_id IS NULL').run()
    db.prepare('UPDATE interactions SET household_id = 1 WHERE household_id IS NULL').run()
    db.prepare('UPDATE memories SET household_id = 1 WHERE household_id IS NULL').run()
    db.prepare('UPDATE affection SET household_id = 1 WHERE household_id IS NULL').run()
    db.prepare('UPDATE mood_log SET household_id = 1 WHERE household_id IS NULL').run()
    db.prepare('UPDATE pet_taps SET household_id = 1 WHERE household_id IS NULL').run()
    db.prepare('UPDATE stage_events SET household_id = 1 WHERE household_id IS NULL').run()

    const existingPet = db.prepare('SELECT 1 FROM pets WHERE household_id = 1').get()

    if (!existingPet) {
      const legacyPet = hasLegacyPet
        ? (db
            .prepare(
              `SELECT name, stage, total_xp, mood, mood_score, last_interaction_at, created_at
               FROM pet
               WHERE id = 1`,
            )
            .get() as
            | {
                name: string
                stage: number
                total_xp: number
                mood: string
                mood_score: number
                last_interaction_at: string | null
                created_at: string
              }
            | undefined)
        : undefined

      if (legacyPet) {
        db.prepare(
          `INSERT INTO pets (
             household_id,
             name,
             stage,
             total_xp,
             mood,
             mood_score,
             last_interaction_at,
             created_at
           )
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        ).run(
          1,
          legacyPet.name,
          legacyPet.stage,
          legacyPet.total_xp,
          legacyPet.mood,
          legacyPet.mood_score,
          legacyPet.last_interaction_at,
          legacyPet.created_at,
        )
      } else {
        db.prepare("INSERT INTO pets (household_id, name) VALUES (1, 'Mochi')").run()
      }
    }

    createLegacyAccounts()
  }

  importLegacyInteractionsIntoSessions()
}

function importLegacyInteractionsIntoSessions() {
  const households = db
    .prepare(
      `SELECT DISTINCT household_id AS id
       FROM interactions
       WHERE session_id IS NULL`,
    )
    .all() as Array<{ id: number }>

  if (households.length === 0) {
    return
  }

  for (const { id: householdId } of households) {
    const created = db
      .prepare(
        `INSERT INTO chat_sessions (household_id, member_id, title, created_at, last_message_at)
         SELECT ?, MIN(member_id), 'Previous chats', MIN(created_at), MAX(created_at)
         FROM interactions
         WHERE household_id = ? AND session_id IS NULL`,
      )
      .run(householdId, householdId)

    db.prepare(
      `UPDATE interactions
       SET session_id = ?
       WHERE household_id = ? AND session_id IS NULL`,
    ).run(Number(created.lastInsertRowid), householdId)
  }
}
