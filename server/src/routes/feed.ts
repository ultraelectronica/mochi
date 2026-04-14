import express from 'express'

import { getStageDefinition } from '../config/index.ts'
import db from '../db/index.ts'

const router = express.Router()

router.get('/', (request, response) => {
  const requestedLimit = Number(request.query.limit)
  const limit = Number.isInteger(requestedLimit) && requestedLimit > 0 ? requestedLimit : 30

  const chatEvents = db
    .prepare(
      `SELECT interactions.id,
              interactions.created_at,
              members.id AS member_id,
              members.name AS member_name
       FROM interactions
       JOIN members ON members.id = interactions.member_id
       ORDER BY datetime(interactions.created_at) DESC
       LIMIT ?`,
    )
    .all(limit)
    .map((row: { id: number; created_at: string; member_id: number; member_name: string }) => ({
      id: `chat-${row.id}`,
      event_type: 'chat',
      created_at: row.created_at,
      member_id: row.member_id,
      member_name: row.member_name,
      detail: 'chatted with Mochi',
    }))

  const moodEvents = db
    .prepare(
      `SELECT mood_log.id,
              mood_log.created_at,
              mood_log.mood,
              members.id AS member_id,
              members.name AS member_name
       FROM mood_log
       JOIN members ON members.id = mood_log.member_id
       ORDER BY datetime(mood_log.created_at) DESC
       LIMIT ?`,
    )
    .all(limit)
    .map(
      (row: {
        id: number
        created_at: string
        mood: string
        member_id: number
        member_name: string
      }) => ({
        id: `mood-${row.id}`,
        event_type: 'mood_checkin',
        created_at: row.created_at,
        member_id: row.member_id,
        member_name: row.member_name,
        detail: `checked in as ${row.mood}`,
      }),
    )

  const stageEvents = db
    .prepare(
      `SELECT id, stage, created_at
       FROM stage_events
       ORDER BY datetime(created_at) DESC
       LIMIT ?`,
    )
    .all(limit)
    .map((row: { id: number; stage: number; created_at: string }) => ({
      id: `stage-${row.id}`,
      event_type: 'stage_up',
      created_at: row.created_at,
      detail: `Mochi reached ${getStageDefinition(row.stage)?.name || `stage ${row.stage}`}`,
    }))

  const events = [...chatEvents, ...moodEvents, ...stageEvents]
    .sort((left, right) => right.created_at.localeCompare(left.created_at))
    .slice(0, limit)

  response.json(events)
})

export default router
