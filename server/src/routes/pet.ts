import express from 'express'

import db from '../db/index.ts'

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

export default router
