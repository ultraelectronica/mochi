import cron from 'node-cron'

import db from '../db/index.ts'
import { recalculateMood } from '../services/mood-engine.ts'
import { getPet } from '../services/pets.ts'
import { broadcastHousehold } from '../ws/index.ts'

export function startMoodDecayJob() {
  cron.schedule('0 * * * *', () => {
    try {
      const pets = db.prepare('SELECT household_id, mood FROM pets').all() as Array<{
        household_id: number
        mood: string
      }>

      for (const pet of pets) {
        const nextMood = recalculateMood(pet.household_id)

        if (pet.mood !== nextMood) {
          broadcastHousehold(pet.household_id, {
            type: 'pet.updated',
            pet: getPet(pet.household_id),
          })
        }
      }
    } catch (error) {
      console.error('Mood decay job failed:', error)
    }
  })
}
