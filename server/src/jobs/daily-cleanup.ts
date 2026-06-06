import cron from 'node-cron'

import { config } from '../config/index.ts'
import db from '../db/index.ts'
import { pruneStaleMemories } from '../services/memories.ts'

export function startDailyCleanupJob() {
  cron.schedule('0 4 * * *', () => {
    try {
      const sessionResult = db
        .prepare(
          `DELETE FROM auth_sessions
           WHERE datetime(created_at) <= datetime('now', ? || ' days')`,
        )
        .run(String(-config.sessionMaxAgeDays))

      if (sessionResult.changes > 0) {
        console.info(`Pruned ${sessionResult.changes} expired sessions`)
      }

      pruneStaleMemories()
    } catch (error) {
      console.error('Daily cleanup job failed:', error)
    }
  })
}
