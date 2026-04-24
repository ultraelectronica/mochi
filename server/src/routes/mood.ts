import express from 'express'

import { config, validMoodKeys } from '../config/index.ts'
import db from '../db/index.ts'
import { getRequestAuth } from '../middleware/auth.ts'
import { recalculateMood } from '../services/mood-engine.ts'
import { getPet } from '../services/pets.ts'
import { awardXP, checkStagePromotion } from '../services/xp.ts'
import { broadcastHousehold } from '../ws/index.ts'

const router = express.Router()

router.post('/checkin', (request, response) => {
  const auth = getRequestAuth(request)
  const memberId = auth.memberId
  const mood = typeof request.body?.mood === 'string' ? request.body.mood.trim() : ''

  if (!validMoodKeys.has(mood)) {
    response.status(400).json({ error: 'Valid mood is required' })
    return
  }

  const member = db
    .prepare(
      `SELECT id
       FROM members
       WHERE id = ? AND household_id = ?`,
    )
    .get(memberId, auth.householdId)

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const existingCheckin = db
    .prepare(
      `SELECT id
       FROM mood_log
       WHERE household_id = ?
         AND member_id = ?
          AND date(created_at) = date('now')`,
    )
    .get(auth.householdId, memberId)

  if (existingCheckin) {
    response.status(409).json({ error: 'Mood already checked in today' })
    return
  }

  const xpAwarded = awardXP({
    householdId: auth.householdId,
    memberId,
    amount: config.xpPerCheckin,
  })
  db.prepare(
    `INSERT INTO mood_log (household_id, member_id, mood)
     VALUES (?, ?, ?)`,
  ).run(auth.householdId, memberId, mood)

  const promoted = checkStagePromotion(auth.householdId)
  recalculateMood(auth.householdId)

  const pet = getPet(auth.householdId)
  broadcastHousehold(auth.householdId, { type: 'pet.updated', pet, promoted })

  response.status(201).json({ pet, xpAwarded })
})

router.get('/log', (request, response) => {
  const auth = getRequestAuth(request)
  const logs = db
    .prepare(
      `SELECT mood_log.id,
              mood_log.member_id,
              members.name AS member_name,
              mood_log.mood,
              mood_log.created_at
       FROM mood_log
       JOIN members ON members.id = mood_log.member_id
       WHERE mood_log.household_id = ?
         AND date(mood_log.created_at) = date('now')
       ORDER BY datetime(mood_log.created_at) DESC`,
    )
    .all(auth.householdId)

  response.json(logs)
})

export default router
