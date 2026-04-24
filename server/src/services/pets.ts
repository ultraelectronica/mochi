import db from '../db/index.ts'

export const petSelect = `
  SELECT id,
         household_id,
         name,
         stage,
         total_xp,
         mood,
         mood_score,
         last_interaction_at,
         created_at
  FROM pets
  WHERE household_id = ?
`

export function getPet(householdId: number) {
  return db.prepare(petSelect).get(householdId)
}

export function createPet(householdId: number, name = 'Mochi') {
  db.prepare('INSERT INTO pets (household_id, name) VALUES (?, ?)').run(householdId, name)
  return getPet(householdId)
}
