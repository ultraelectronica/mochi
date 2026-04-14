import express from 'express'

import { config } from '../config/index.ts'
import db from '../db/index.ts'
import { checkStagePromotion, awardXP } from '../services/xp.ts'
import { broadcast } from '../ws/index.ts'

const router = express.Router()

const petSelect = `
  SELECT id, name, stage, total_xp, mood, mood_score, last_interaction_at, created_at
  FROM pet
  WHERE id = 1
`

router.get('/', (_request, response) => {
  response.json(db.prepare(petSelect).get())
})

router.patch('/name', (request, response) => {
  const name = typeof request.body?.name === 'string' ? request.body.name.trim() : ''

  if (!name) {
    response.status(400).json({ error: 'Name is required' })
    return
  }

  db.prepare('UPDATE pet SET name = ? WHERE id = 1').run(name)
  response.json(db.prepare(petSelect).get())
})

router.get('/memories', (_request, response) => {
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
       ORDER BY memories.weight DESC, datetime(memories.created_at) DESC
       LIMIT 10`,
    )
    .all()

  response.json(memories)
})

router.post('/tap', (request, response) => {
  const memberId = Number(request.body?.member_id)

  if (!Number.isInteger(memberId) || memberId <= 0) {
    response.status(400).json({ error: 'Valid member_id is required' })
    return
  }

  const member = db.prepare('SELECT id FROM members WHERE id = ?').get(memberId)

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const xpAwarded = awardXP({ memberId, amount: config.xpPerTap })

  db.transaction(() => {
    db.prepare('INSERT INTO pet_taps (member_id, xp_awarded) VALUES (?, ?)').run(memberId, xpAwarded)
    db.prepare(
      `UPDATE pet
       SET mood = 'laughing',
           mood_score = CASE WHEN mood_score < 88 THEN 88 ELSE mood_score END
       WHERE id = 1`,
    ).run()
  })()

  const promoted = checkStagePromotion()
  const pet = db.prepare(petSelect).get()

  broadcast({ type: 'pet.updated', pet, promoted })

  response.status(201).json({ pet, xpAwarded })
})

export default router
