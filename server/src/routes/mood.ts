import express from 'express'

import { config, validMoodKeys } from '../config/index.ts'
import db from '../db/index.ts'
import { recalculateMood } from '../services/mood-engine.ts'
import { awardXP, checkStagePromotion } from '../services/xp.ts'
import { broadcast } from '../ws/index.ts'

const router = express.Router()

const petSelect = `
  SELECT id, name, stage, total_xp, mood, mood_score, last_interaction_at, created_at
  FROM pet
  WHERE id = 1
`

router.post('/checkin', (request, response) => {
  const memberId = Number(request.body?.member_id)
  const mood = typeof request.body?.mood === 'string' ? request.body.mood.trim() : ''

  if (!Number.isInteger(memberId) || memberId <= 0 || !validMoodKeys.has(mood)) {
    response.status(400).json({ error: 'Valid member_id and mood are required' })
    return
  }

  const member = db.prepare('SELECT id FROM members WHERE id = ?').get(memberId)

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const existingCheckin = db
    .prepare(
      `SELECT id
       FROM mood_log
       WHERE member_id = ?
         AND date(created_at) = date('now')`,
    )
    .get(memberId)

  if (existingCheckin) {
    response.status(409).json({ error: 'Mood already checked in today' })
    return
  }

  const xpAwarded = awardXP({ memberId, amount: config.xpPerCheckin })
  db.prepare('INSERT INTO mood_log (member_id, mood) VALUES (?, ?)').run(memberId, mood)

  const promoted = checkStagePromotion()
  recalculateMood()

  const pet = db.prepare(petSelect).get()
  broadcast({ type: 'pet.updated', pet, promoted })

  response.status(201).json({ pet, xpAwarded })
})

router.get('/log', (_request, response) => {
  const logs = db
    .prepare(
      `SELECT mood_log.id,
              mood_log.member_id,
              members.name AS member_name,
              mood_log.mood,
              mood_log.created_at
       FROM mood_log
       JOIN members ON members.id = mood_log.member_id
       WHERE date(mood_log.created_at) = date('now')
       ORDER BY datetime(mood_log.created_at) DESC`,
    )
    .all()

  response.json(logs)
})

export default router
