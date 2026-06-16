import express from 'express'

import { config } from '../config/index.ts'
import db from '../db/index.ts'
import { getRequestAuth } from '../middleware/auth.ts'
import { getReply } from '../services/ai.ts'
import { recalculateMood } from '../services/mood-engine.ts'
import { getPet } from '../services/pets.ts'
import { buildMessages } from '../services/prompt.ts'
import { upsertMemory } from '../services/memories.ts'
import { awardXP, checkStagePromotion } from '../services/xp.ts'
import { broadcastHousehold } from '../ws/index.ts'

const router = express.Router()

const nowSql = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')"

function resolveSession(householdId: number, memberId: number, requestedSessionId: number): number {
  if (requestedSessionId > 0) {
    const owned = db
      .prepare('SELECT id FROM chat_sessions WHERE id = ? AND household_id = ?')
      .get(requestedSessionId, householdId) as { id: number } | undefined

    if (owned) {
      return owned.id
    }
  }

  const created = db
    .prepare(
      `INSERT INTO chat_sessions (household_id, member_id, title) VALUES (?, ?, 'New chat')`,
    )
    .run(householdId, memberId)

  return Number(created.lastInsertRowid)
}

function deriveSessionTitle(sessionId: number, text: string) {
  const trimmed = text.trim().replace(/\s+/g, ' ')
  const title = trimmed.length > 48 ? `${trimmed.slice(0, 45)}...` : trimmed
  db.prepare('UPDATE chat_sessions SET title = ? WHERE id = ? AND title = ?').run(
    title || 'New chat',
    sessionId,
    'New chat',
  )
}

router.post('/', async (request, response) => {
  const auth = getRequestAuth(request)
  const memberId = auth.memberId
  const text = typeof request.body?.text === 'string' ? request.body.text.trim() : ''
  const inputType = request.body?.input_type === 'voice' ? 'voice' : 'text'
  const requestedSessionId = Number(request.body?.session_id) || 0

  if (!text) {
    response.status(400).json({ error: 'text is required' })
    return
  }

  const member = db
    .prepare(
      `SELECT id, name
       FROM members
       WHERE id = ? AND household_id = ?`,
    )
    .get(memberId, auth.householdId) as
    | { id: number; name: string }
    | undefined

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const sessionId = resolveSession(auth.householdId, memberId, requestedSessionId)

  const pet = getPet(auth.householdId) as { mood: string }
  const memories = db
    .prepare(
      `SELECT content
       FROM memories
       WHERE household_id = ?
         AND member_id = ?
       ORDER BY weight DESC, datetime(created_at) DESC
       LIMIT 3`,
    )
    .all(auth.householdId, memberId) as Array<{ content: string }>

  const messages = buildMessages({
    memberName: member.name,
    text,
    mood: pet.mood,
    memories,
  })

  try {
    const reply = await getReply(messages)
    const xpAwarded = awardXP({ householdId: auth.householdId, memberId, amount: config.xpPerChat })

    db.prepare(
      `INSERT INTO interactions (household_id, member_id, session_id, input_text, response_text, input_type, xp_awarded)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).run(auth.householdId, memberId, sessionId, text, reply, inputType, xpAwarded)

    deriveSessionTitle(sessionId, text)
    db.prepare(`UPDATE chat_sessions SET last_message_at = ${nowSql} WHERE id = ?`).run(sessionId)

    upsertMemory({
      householdId: auth.householdId,
      memberId: auth.memberId,
      content: text,
    })

    const promoted = checkStagePromotion(auth.householdId)
    recalculateMood(auth.householdId)

    const updatedPet = getPet(auth.householdId)
    broadcastHousehold(auth.householdId, { type: 'pet.updated', pet: updatedPet, promoted })

    response.json({ reply, pet: updatedPet, session_id: sessionId })
  } catch (error) {
    console.error('Chat request failed:', error)
    response.status(503).json({ error: 'Chat service unavailable' })
  }
})

router.get('/', (request, response) => {
  const auth = getRequestAuth(request)
  const requestedLimit = Number(request.query.limit)
  const limit = Math.min(
    Number.isInteger(requestedLimit) && requestedLimit > 0 ? requestedLimit : 30,
    200,
  )
  const sessionId = Number(request.query.session_id) || 0

  if (!sessionId) {
    response.json([])
    return
  }

  const interactions = db
    .prepare(
      `SELECT recent.id,
              recent.member_id,
              recent.input_text,
              recent.response_text,
              recent.input_type,
              recent.xp_awarded,
              recent.created_at,
              members.name AS member_name
       FROM (
         SELECT *
         FROM interactions
         WHERE household_id = ? AND session_id = ?
         ORDER BY datetime(created_at) DESC, id DESC
         LIMIT ?
       ) AS recent
         JOIN members ON members.id = recent.member_id
        ORDER BY datetime(recent.created_at) ASC, recent.id ASC`,
    )
    .all(auth.householdId, sessionId, limit)

  response.json(interactions)
})

router.get('/sessions', (request, response) => {
  const auth = getRequestAuth(request)
  const requestedLimit = Number(request.query.limit)
  const limit = Math.min(
    Number.isInteger(requestedLimit) && requestedLimit > 0 ? requestedLimit : 50,
    200,
  )

  const sessions = db
    .prepare(
      `SELECT s.id,
              s.title,
              s.created_at,
              s.last_message_at,
              members.name AS member_name,
              (SELECT COUNT(*) FROM interactions i WHERE i.session_id = s.id) AS message_count,
              (SELECT input_text
               FROM interactions i
               WHERE i.session_id = s.id
               ORDER BY datetime(i.created_at) ASC, i.id ASC
               LIMIT 1) AS preview
       FROM chat_sessions s
       LEFT JOIN members ON members.id = s.member_id
       WHERE s.household_id = ?
       ORDER BY datetime(COALESCE(s.last_message_at, s.created_at)) DESC, s.id DESC
       LIMIT ?`,
    )
    .all(auth.householdId, limit)

  response.json(sessions)
})

router.delete('/sessions/:id', (request, response) => {
  const auth = getRequestAuth(request)
  const sessionId = Number(request.params.id)

  const owned = db
    .prepare('SELECT id FROM chat_sessions WHERE id = ? AND household_id = ?')
    .get(sessionId, auth.householdId) as { id: number } | undefined

  if (!owned) {
    response.status(404).json({ error: 'Session not found' })
    return
  }

  db.prepare('DELETE FROM interactions WHERE session_id = ?').run(sessionId)
  db.prepare('DELETE FROM chat_sessions WHERE id = ?').run(sessionId)

  response.json({ ok: true })
})

export default router
