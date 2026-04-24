import express from 'express'

import { config } from '../config/index.ts'
import db from '../db/index.ts'
import { getRequestAuth } from '../middleware/auth.ts'
import { getReply } from '../services/ai.ts'
import { recalculateMood } from '../services/mood-engine.ts'
import { getPet } from '../services/pets.ts'
import { buildPrompt } from '../services/prompt.ts'
import { awardXP, checkStagePromotion } from '../services/xp.ts'
import { broadcastHousehold } from '../ws/index.ts'

const router = express.Router()

router.post('/', async (request, response) => {
  const auth = getRequestAuth(request)
  const memberId = auth.memberId
  const text = typeof request.body?.text === 'string' ? request.body.text.trim() : ''
  const inputType = request.body?.input_type === 'voice' ? 'voice' : 'text'

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

  const prompt = buildPrompt({
    memberName: member.name,
    text,
    mood: pet.mood,
    memories,
  })

  try {
    const reply = await getReply(prompt)
    const xpAwarded = awardXP({ householdId: auth.householdId, memberId, amount: config.xpPerChat })

    db.prepare(
      `INSERT INTO interactions (household_id, member_id, input_text, response_text, input_type, xp_awarded)
       VALUES (?, ?, ?, ?, ?, ?)`,
    ).run(auth.householdId, memberId, text, reply, inputType, xpAwarded)

    const promoted = checkStagePromotion(auth.householdId)
    recalculateMood(auth.householdId)

    const updatedPet = getPet(auth.householdId)
    broadcastHousehold(auth.householdId, { type: 'pet.updated', pet: updatedPet, promoted })

    response.json({ reply, pet: updatedPet })
  } catch (error) {
    console.error('Chat request failed:', error)
    response.status(503).json({ error: 'Chat service unavailable' })
  }
})

router.get('/', (request, response) => {
  const auth = getRequestAuth(request)
  const requestedLimit = Number(request.query.limit)
  const limit = Number.isInteger(requestedLimit) && requestedLimit > 0 ? requestedLimit : 30

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
         WHERE household_id = ?
         ORDER BY datetime(created_at) DESC, id DESC
         LIMIT ?
       ) AS recent
        JOIN members ON members.id = recent.member_id
       ORDER BY datetime(recent.created_at) ASC, recent.id ASC`,
    )
    .all(auth.householdId, limit)

  response.json(interactions)
})

export default router
