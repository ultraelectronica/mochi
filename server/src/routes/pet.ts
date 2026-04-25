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

router.post('/memories', (request, response) => {
  const auth = getRequestAuth(request)
  const content = typeof request.body?.content === 'string' ? request.body.content.trim() : ''
  const weight = typeof request.body?.weight === 'number' ? request.body.weight : 1

  if (!content) {
    response.status(400).json({ error: 'content is required' })
    return
  }

  if (!Number.isInteger(weight) || weight < 1 || weight > 5) {
    response.status(400).json({ error: 'weight must be an integer between 1 and 5' })
    return
  }

  const result = db
    .prepare(
      `INSERT INTO memories (household_id, member_id, content, weight)
       VALUES (?, ?, ?, ?)`,
    )
    .run(auth.householdId, auth.memberId, content, weight)

  const memory = db
    .prepare(
      `SELECT memories.id,
              memories.member_id,
              members.name AS member_name,
              memories.content,
              memories.weight,
              memories.created_at
       FROM memories
       LEFT JOIN members ON members.id = memories.member_id
       WHERE memories.id = ?`,
    )
    .get(result.lastInsertRowid)

  response.status(201).json(memory)
})

router.patch('/memories/:id', (request, response) => {
  const auth = getRequestAuth(request)
  const id = Number(request.params.id)

  if (!Number.isInteger(id) || id < 1) {
    response.status(400).json({ error: 'Invalid memory id' })
    return
  }

  const existing = db
    .prepare('SELECT id FROM memories WHERE id = ? AND household_id = ?')
    .get(id, auth.householdId)

  if (!existing) {
    response.status(404).json({ error: 'Memory not found' })
    return
  }

  const content = request.body?.content
  const weight = request.body?.weight

  if (content !== undefined && typeof content !== 'string') {
    response.status(400).json({ error: 'content must be a string' })
    return
  }

  if (weight !== undefined && (!Number.isInteger(weight) || weight < 1 || weight > 5)) {
    response.status(400).json({ error: 'weight must be an integer between 1 and 5' })
    return
  }

  const trimmedContent = typeof content === 'string' ? content.trim() : undefined

  if (content !== undefined && !trimmedContent) {
    response.status(400).json({ error: 'content cannot be empty' })
    return
  }

  const sets: string[] = []
  const values: (string | number)[] = []

  if (trimmedContent !== undefined) {
    sets.push('content = ?')
    values.push(trimmedContent)
  }
  if (weight !== undefined) {
    sets.push('weight = ?')
    values.push(weight)
  }

  if (sets.length === 0) {
    response.status(400).json({ error: 'No fields to update' })
    return
  }

  values.push(id)

  db.prepare(`UPDATE memories SET ${sets.join(', ')} WHERE id = ?`).run(...values)

  const memory = db
    .prepare(
      `SELECT memories.id,
              memories.member_id,
              members.name AS member_name,
              memories.content,
              memories.weight,
              memories.created_at
       FROM memories
       LEFT JOIN members ON members.id = memories.member_id
       WHERE memories.id = ?`,
    )
    .get(id)

  response.json(memory)
})

router.delete('/memories/:id', (request, response) => {
  const auth = getRequestAuth(request)
  const id = Number(request.params.id)

  if (!Number.isInteger(id) || id < 1) {
    response.status(400).json({ error: 'Invalid memory id' })
    return
  }

  const existing = db
    .prepare('SELECT id FROM memories WHERE id = ? AND household_id = ?')
    .get(id, auth.householdId)

  if (!existing) {
    response.status(404).json({ error: 'Memory not found' })
    return
  }

  db.prepare('DELETE FROM memories WHERE id = ?').run(id)
  response.status(204).send()
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
