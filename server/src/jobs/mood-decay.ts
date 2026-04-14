import cron from 'node-cron'

import db from '../db/index.ts'
import { recalculateMood } from '../services/mood-engine.ts'
import { broadcast } from '../ws/index.ts'

const petSelect = `
  SELECT id, name, stage, total_xp, mood, mood_score, last_interaction_at, created_at
  FROM pet
  WHERE id = 1
`

export function startMoodDecayJob() {
  cron.schedule('0 * * * *', () => {
    try {
      const previousPet = db.prepare(petSelect).get() as { mood: string }
      const nextMood = recalculateMood()

      if (previousPet.mood !== nextMood) {
        broadcast({ type: 'pet.updated', pet: db.prepare(petSelect).get() })
      }
    } catch (error) {
      console.error('Mood decay job failed:', error)
    }
  })
}
