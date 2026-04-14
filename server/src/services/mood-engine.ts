import { config } from '../config/index.ts'
import db from '../db/index.ts'

const moodDelta: Record<string, number> = {
  happy: 12,
  sad: -14,
  angry: -20,
  normal: 0,
  tired: -10,
  confused: -6,
  laughing: 16,
  hungry: -12,
  scared: -22,
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value))
}

function dominantCount(moods: string[], target: string) {
  return moods.filter((mood) => mood === target).length
}

function pickMood(score: number, recentMoods: string[], recentChats: number, inactivityHours: number) {
  if (inactivityHours >= config.moodDecayHours * 2) {
    return 'hungry'
  }

  if (inactivityHours >= config.moodDecayHours) {
    return 'tired'
  }

  if (new Set(recentMoods.slice(0, 3)).size >= 3 && score >= 35 && score <= 75) {
    return 'confused'
  }

  if (score >= 90 || recentChats >= 4) {
    return 'laughing'
  }

  if (score >= 78) {
    return 'happy'
  }

  if (dominantCount(recentMoods, 'scared') >= 2 || score <= 10) {
    return 'scared'
  }

  if (dominantCount(recentMoods, 'angry') >= 2 || score <= 25) {
    return 'angry'
  }

  if (dominantCount(recentMoods, 'sad') >= 2 || score <= 45) {
    return 'sad'
  }

  return 'normal'
}

export function recalculateMood() {
  const pet = db
    .prepare('SELECT mood, mood_score, last_interaction_at FROM pet WHERE id = 1')
    .get() as { mood: string; mood_score: number; last_interaction_at: string | null }

  const recentMoodRows = db
    .prepare(
      `SELECT mood
       FROM mood_log
       WHERE datetime(created_at) >= datetime('now', '-3 hours')
       ORDER BY datetime(created_at) DESC`,
    )
    .all() as Array<{ mood: string }>

  const recentChats = Number(
    (
      db
        .prepare(
          `SELECT COUNT(*) AS count
           FROM interactions
           WHERE datetime(created_at) >= datetime('now', '-1 hour')`,
        )
        .get() as { count: number }
    ).count,
  )

  let score = 70

  for (const row of recentMoodRows) {
    score += moodDelta[row.mood] || 0
  }

  score += Math.min(recentChats * 4, 20)

  const inactivityHours = pet.last_interaction_at
    ? (Date.now() - Date.parse(pet.last_interaction_at)) / 3_600_000
    : 0

  if (inactivityHours >= config.moodDecayHours * 2) {
    score = Math.min(score, 28)
  } else if (inactivityHours >= config.moodDecayHours) {
    score = Math.min(score, 42)
  }

  score = clamp(Math.round(score), 0, 100)

  const mood = pickMood(
    score,
    recentMoodRows.map(({ mood: recentMood }) => recentMood),
    recentChats,
    inactivityHours,
  )

  db.prepare('UPDATE pet SET mood = ?, mood_score = ? WHERE id = 1').run(mood, score)

  return mood
}
