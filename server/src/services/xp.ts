import { config, getMoodDefinition } from '../config/index.ts'
import db from '../db/index.ts'

type AwardXpInput = {
  memberId: number
  amount: number
}

export function awardXP({ memberId, amount }: AwardXpInput) {
  const pet = db.prepare('SELECT mood FROM pet WHERE id = 1').get() as { mood: string }
  const modifier = getMoodDefinition(pet.mood)?.xpModifier || 1
  const adjustedAmount = Math.max(1, Math.round(amount * modifier))
  const affectionGain = Math.max(1, Math.ceil(adjustedAmount / 2))
  const now = new Date().toISOString()

  db.transaction(() => {
    const member = db.prepare('SELECT id FROM members WHERE id = ?').get(memberId)

    if (!member) {
      throw new Error(`Member ${memberId} does not exist`)
    }

    db.prepare(
      'UPDATE members SET total_xp = total_xp + ?, last_seen_at = ? WHERE id = ?',
    ).run(adjustedAmount, now, memberId)

    db.prepare(
      'UPDATE pet SET total_xp = total_xp + ?, last_interaction_at = ? WHERE id = 1',
    ).run(adjustedAmount, now)

    db.prepare(
      `INSERT INTO affection (member_id, score, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(member_id) DO UPDATE SET
         score = affection.score + excluded.score,
         updated_at = excluded.updated_at`,
    ).run(memberId, affectionGain, now)
  })()

  return adjustedAmount
}

export function checkStagePromotion() {
  const pet = db.prepare('SELECT stage, total_xp FROM pet WHERE id = 1').get() as {
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
    db.prepare('UPDATE pet SET stage = ? WHERE id = 1').run(nextStage)

    for (const stage of crossedStages) {
      db.prepare('INSERT INTO stage_events (stage) VALUES (?)').run(stage.stage)
    }
  })()

  return true
}
