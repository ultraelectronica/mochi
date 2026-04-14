import express from 'express'

import db from '../db/index.ts'

const router = express.Router()
const colorPattern = /^#[0-9a-f]{6}$/i

function parseId(raw: string) {
  const id = Number(raw)
  return Number.isInteger(id) && id > 0 ? id : null
}

router.get('/', (_request, response) => {
  const members = db
    .prepare(
      `SELECT members.id,
              members.name,
              members.avatar_color,
              members.total_xp,
              members.created_at,
              members.last_seen_at,
              COALESCE(affection.score, 0) AS affection_score
       FROM members
       LEFT JOIN affection ON affection.member_id = members.id
       ORDER BY datetime(members.created_at) ASC`,
    )
    .all()

  response.json(members)
})

router.post('/', (request, response) => {
  const name = typeof request.body?.name === 'string' ? request.body.name.trim() : ''
  const avatarColor =
    typeof request.body?.avatar_color === 'string' && colorPattern.test(request.body.avatar_color)
      ? request.body.avatar_color
      : '#1D9E75'

  if (!name) {
    response.status(400).json({ error: 'Name is required' })
    return
  }

  const result = db.prepare('INSERT INTO members (name, avatar_color) VALUES (?, ?)').run(name, avatarColor)
  db.prepare('INSERT INTO affection (member_id) VALUES (?)').run(result.lastInsertRowid)

  const member = db
    .prepare(
      `SELECT members.id,
              members.name,
              members.avatar_color,
              members.total_xp,
              members.created_at,
              members.last_seen_at,
              COALESCE(affection.score, 0) AS affection_score
       FROM members
       LEFT JOIN affection ON affection.member_id = members.id
       WHERE members.id = ?`,
    )
    .get(result.lastInsertRowid)

  response.status(201).json(member)
})

router.get('/:id', (request, response) => {
  const memberId = parseId(request.params.id)

  if (!memberId) {
    response.status(400).json({ error: 'Invalid member id' })
    return
  }

  const member = db
    .prepare(
      `SELECT members.id,
              members.name,
              members.avatar_color,
              members.total_xp,
              members.created_at,
              members.last_seen_at,
              COALESCE(affection.score, 0) AS affection_score
       FROM members
       LEFT JOIN affection ON affection.member_id = members.id
       WHERE members.id = ?`,
    )
    .get(memberId)

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const recentMoodLogs = db
    .prepare(
      `SELECT id, mood, created_at
       FROM mood_log
       WHERE member_id = ?
       ORDER BY datetime(created_at) DESC
       LIMIT 10`,
    )
    .all(memberId)

  response.json({
    ...member,
    recent_mood_logs: recentMoodLogs,
  })
})

router.delete('/:id', (request, response) => {
  const memberId = parseId(request.params.id)

  if (!memberId) {
    response.status(400).json({ error: 'Invalid member id' })
    return
  }

  const result = db.prepare('DELETE FROM members WHERE id = ?').run(memberId)

  if (!result.changes) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  response.status(204).send()
})

export default router
