import express from 'express'

import { config } from '../config/index.ts'
import db from '../db/index.ts'
import { getReply } from '../services/ai.ts'
import { recalculateMood } from '../services/mood-engine.ts'
import { buildPrompt } from '../services/prompt.ts'
import { awardXP, checkStagePromotion } from '../services/xp.ts'
import { broadcast } from '../ws/index.ts'

const router = express.Router()

const petSelect = `
  SELECT id, name, stage, total_xp, mood, mood_score, last_interaction_at, created_at
  FROM pet
  WHERE id = 1
`

router.post('/', async (request, response) => {
  const memberId = Number(request.body?.member_id)
  const text = typeof request.body?.text === 'string' ? request.body.text.trim() : ''
  const inputType = request.body?.input_type === 'voice' ? 'voice' : 'text'

  if (!Number.isInteger(memberId) || memberId <= 0 || !text) {
    response.status(400).json({ error: 'member_id and text are required' })
    return
  }

  const member = db.prepare('SELECT id, name FROM members WHERE id = ?').get(memberId) as
    | { id: number; name: string }
    | undefined

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const pet = db.prepare(petSelect).get() as { mood: string }
  const memories = db
    .prepare(
      `SELECT content
       FROM memories
       WHERE member_id = ?
       ORDER BY weight DESC, datetime(created_at) DESC
       LIMIT 3`,
    )
    .all(memberId) as Array<{ content: string }>

  const prompt = buildPrompt({
    memberName: member.name,
    text,
    mood: pet.mood,
    memories,
  })

  try {
    const reply = await getReply(prompt)
    const xpAwarded = awardXP({ memberId, amount: config.xpPerChat })

    db.prepare(
      `INSERT INTO interactions (member_id, input_text, response_text, input_type, xp_awarded)
       VALUES (?, ?, ?, ?, ?)`,
    ).run(memberId, text, reply, inputType, xpAwarded)

    const promoted = checkStagePromotion()
    recalculateMood()

    const updatedPet = db.prepare(petSelect).get()
    broadcast({ type: 'pet.updated', pet: updatedPet, promoted })

    response.json({ reply, pet: updatedPet })
  } catch (error) {
    console.error('Chat request failed:', error)
    response.status(503).json({ error: 'Chat service unavailable' })
  }
})

export default router
