import { config, getMoodDefinition } from '../config/index.ts'
import db from '../db/index.ts'
import { getPet } from './pets.ts'

type AwardXpInput = {
  householdId: number
  memberId: number
  amount: number
}

export function awardXP({ householdId, memberId, amount }: AwardXpInput) {
  const pet = getPet(householdId) as { mood: string }
  const modifier = getMoodDefinition(pet.mood)?.xpModifier || 1
  const adjustedAmount = Math.max(1, Math.round(amount * modifier))
  const affectionGain = Math.max(1, Math.ceil(adjustedAmount / 2))
  const now = new Date().toISOString()

  db.transaction(() => {
    const member = db
      .prepare(
        `SELECT id
         FROM members
         WHERE id = ? AND household_id = ?`,
      )
      .get(memberId, householdId)

    if (!member) {
      throw new Error(`Member ${memberId} does not exist`)
    }

    db.prepare(
      'UPDATE members SET total_xp = total_xp + ?, last_seen_at = ? WHERE id = ? AND household_id = ?',
    ).run(adjustedAmount, now, memberId, householdId)

    db.prepare(
      'UPDATE pets SET total_xp = total_xp + ?, last_interaction_at = ? WHERE household_id = ?',
    ).run(adjustedAmount, now, householdId)

    db.prepare(
      `INSERT INTO affection (household_id, member_id, score, updated_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(member_id) DO UPDATE SET
          score = affection.score + excluded.score,
          updated_at = excluded.updated_at`,
    ).run(householdId, memberId, affectionGain, now)
  })()

  return adjustedAmount
}

export function checkStagePromotion(householdId: number) {
  const pet = db.prepare('SELECT stage, total_xp FROM pets WHERE household_id = ?').get(householdId) as {
    stage: number
    total_xp: number
  }

  let nextStage = pet.stage

  for (const stage of config.stages) {
    if (pet.total_xp >= stage.xpRequired) {
      nextStage = stage.stage
    }
  }

  if (nextStage <= pet.stage) {
    return false
  }

  const crossedStages = config.stages.filter(
    (stage) => stage.stage > pet.stage && stage.stage <= nextStage,
  )

  db.transaction(() => {
    db.prepare('UPDATE pets SET stage = ? WHERE household_id = ?').run(nextStage, householdId)

    for (const stage of crossedStages) {
      db.prepare('INSERT INTO stage_events (household_id, stage) VALUES (?, ?)').run(
        householdId,
        stage.stage,
      )
    }
  })()

  return true
}
