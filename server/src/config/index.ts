import fs from 'node:fs'

export type StageDefinition = {
  stage: number
  name: string
  xpRequired: number
  note: string
}

export type MoodDefinition = {
  key: string
  label: string
  note: string
  reaction: string
  xpModifier: number
}

function loadEnvFile() {
  const envFile = new URL('../../.env', import.meta.url)

  if (!fs.existsSync(envFile)) {
    return
  }

  const raw = fs.readFileSync(envFile, 'utf8')

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim()

    if (!trimmed || trimmed.startsWith('#')) {
      continue
    }

    const separator = trimmed.indexOf('=')

    if (separator === -1) {
      continue
    }

    const key = trimmed.slice(0, separator).trim()
    const value = trimmed.slice(separator + 1).trim().replace(/^['"]|['"]$/g, '')

    if (!(key in process.env)) {
      process.env[key] = value
    }
  }
}

function loadTson<T>(file: URL): T {
  return JSON.parse(fs.readFileSync(file, 'utf8')) as T
}

function envNumber(name: string, fallback: number): number {
  const value = Number(process.env[name])
  return Number.isFinite(value) ? value : fallback
}

loadEnvFile()

const stages = loadTson<StageDefinition[]>(
  new URL('../../../shared/stages.tson', import.meta.url),
).sort((left, right) => left.stage - right.stage)

const moods = loadTson<MoodDefinition[]>(
  new URL('../../../shared/moods.tson', import.meta.url),
)

export const config = {
  /** When non-empty, HTTP (except `/health`) and WebSocket require `Authorization: Bearer …`. */
  apiKey: process.env.MOCHI_API_KEY?.trim() || '',
  llamaUrl: process.env.LLAMA_URL?.trim() || 'http://127.0.0.1:8080',
  geminiKey: process.env.GEMINI_API_KEY?.trim() || '',
  port: envNumber('PORT', 3000),
  xpPerChat: envNumber('XP_PER_CHAT', 10),
  xpPerCheckin: envNumber('XP_PER_CHECKIN', 5),
  xpPerTap: envNumber('XP_PER_TAP', 2),
  moodDecayHours: envNumber('MOOD_DECAY_HOURS', 12),
  stages,
  moods,
}

export const validMoodKeys = new Set(config.moods.map(({ key }) => key))

export function getMoodDefinition(mood: string) {
  return config.moods.find(({ key }) => key === mood)
}

export function getStageDefinition(stage: number) {
  return config.stages.find((entry) => entry.stage === stage)
}
