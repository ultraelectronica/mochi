import Database from 'better-sqlite3'
import { fileURLToPath } from 'node:url'

const db = new Database(fileURLToPath(new URL('../../mochi.db', import.meta.url)))

db.pragma('journal_mode = WAL')
db.pragma('busy_timeout = 5000')
db.pragma('foreign_keys = ON')

export default db
