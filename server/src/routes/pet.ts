import express from 'express'

import { config } from '../config/index.ts'
import db from '../db/index.ts'
import { getRequestAuth } from '../middleware/auth.ts'
import { getPet } from '../services/pets.ts'
import { checkStagePromotion, awardXP } from '../services/xp.ts'
import { broadcastHousehold } from '../ws/index.ts'

const router = express.Router()

router.get('/', (request, response) => {
  const auth = getRequestAuth(request)
  response.json(getPet(auth.householdId))
})

router.patch('/name', (request, response) => {
  const auth = getRequestAuth(request)
  const name = typeof request.body?.name === 'string' ? request.body.name.trim() : ''

  if (!name) {
    response.status(400).json({ error: 'Name is required' })
    return
  }

  db.prepare('UPDATE pets SET name = ? WHERE household_id = ?').run(name, auth.householdId)
  response.json(getPet(auth.householdId))
})

router.get('/memories', (request, response) => {
  const auth = getRequestAuth(request)
  const memories = db
    .prepare(
      `SELECT memories.id,
              memories.member_id,
              members.name AS member_name,
              memories.content,
              memories.weight,
              memories.created_at
       FROM memories
       LEFT JOIN members ON members.id = memories.member_id
       WHERE memories.household_id = ?
       ORDER BY memories.weight DESC, datetime(memories.created_at) DESC
       LIMIT 10`,
    )
    .all(auth.householdId)

  response.json(memories)
})

router.post('/tap', (request, response) => {
  const auth = getRequestAuth(request)
  const member = db
    .prepare(
      `SELECT id
       FROM members
       WHERE id = ? AND household_id = ?`,
    )
    .get(auth.memberId, auth.householdId)

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const xpAwarded = awardXP({
    householdId: auth.householdId,
    memberId: auth.memberId,
    amount: config.xpPerTap,
  })

  db.transaction(() => {
    db.prepare(
      `INSERT INTO pet_taps (household_id, member_id, xp_awarded)
       VALUES (?, ?, ?)`,
    ).run(auth.householdId, auth.memberId, xpAwarded)
    db.prepare(
      `UPDATE pets
       SET mood = 'laughing',
           mood_score = CASE WHEN mood_score < 88 THEN 88 ELSE mood_score END
        WHERE household_id = ?`,
    ).run(auth.householdId)
  })()

  const promoted = checkStagePromotion(auth.householdId)
  const pet = getPet(auth.householdId)

  broadcastHousehold(auth.householdId, { type: 'pet.updated', pet, promoted })

  response.status(201).json({ pet, xpAwarded })
})

export default router
