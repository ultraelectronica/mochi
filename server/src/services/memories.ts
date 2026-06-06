import db from '../db/index.ts'

const MAX_MEMORIES_PER_MEMBER = 12
const MEMORY_PRUNE_DAYS = 30

export function upsertMemory(params: {
  householdId: number
  memberId: number
  content: string
}) {
  const { householdId, memberId, content } = params
  const trimmed = content.trim().slice(0, 240)

  if (!trimmed) {
    return
  }

  const similar = db
    .prepare(
      `SELECT id, weight
       FROM memories
       WHERE household_id = ? AND member_id = ? AND content = ?`,
    )
    .get(householdId, memberId, trimmed) as
    | { id: number; weight: number }
    | undefined

  if (similar) {
    db.prepare('UPDATE memories SET weight = MIN(weight + 1, 5) WHERE id = ?').run(similar.id)
    return
  }

  const count = (
    db
      .prepare(
        `SELECT COUNT(*) AS count
         FROM memories
         WHERE household_id = ? AND member_id = ?`,
      )
      .get(householdId, memberId) as { count: number }
  ).count

  if (count >= MAX_MEMORIES_PER_MEMBER) {
    db.prepare(
      `DELETE FROM memories
       WHERE id = (
         SELECT id FROM memories
         WHERE household_id = ? AND member_id = ?
         ORDER BY weight ASC, datetime(created_at) ASC
         LIMIT 1
       )`,
    ).run(householdId, memberId)
  }

  db.prepare(
    `INSERT INTO memories (household_id, member_id, content, weight)
     VALUES (?, ?, ?, 2)`,
  ).run(householdId, memberId, trimmed)
}

export function pruneStaleMemories() {
  db.prepare(
    `DELETE FROM memories
     WHERE weight <= 2
       AND datetime(created_at) <= datetime('now', ? || ' days')`,
  ).run(String(-MEMORY_PRUNE_DAYS))
}
