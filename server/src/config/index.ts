import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

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

/** Expand a leading `~` to the user's home directory (spawned processes don't). */
function expandHome(value: string) {
  if (!value) {
    return ''
  }
  if (value === '~') {
    return os.homedir()
  }
  if (value.startsWith('~/') || value.startsWith('~\\')) {
    return path.join(os.homedir(), value.slice(2))
  }
  return value
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

function envBool(name: string, fallback: boolean): boolean {
  const raw = (process.env[name] ?? '').trim().toLowerCase()
  if (raw === '') {
    return fallback
  }
  return ['1', 'true', 'yes', 'on'].includes(raw)
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
  /** Auto-spawn a local llama.cpp server so `pnpm dev` is self-sufficient. */
  llamaSpawn: envBool('LLAMA_SPAWN', true),
  llamaBinary: expandHome(process.env.LLAMA_BINARY?.trim() || ''),
  llamaModel: expandHome(process.env.LLAMA_MODEL?.trim() || ''),
  llamaHost: process.env.LLAMA_HOST?.trim() || '127.0.0.1',
  llamaPort: envNumber('LLAMA_PORT', 8080),
  llamaCtxSize: envNumber('LLAMA_CTX_SIZE', 2048),
  llamaThreads: envNumber('LLAMA_THREADS', 0),
  /** Primary AI backend. */
  openrouterKey: process.env.OPENROUTER_API_KEY?.trim() || '',
  openrouterModel: process.env.OPENROUTER_MODEL?.trim() || 'openrouter/owl-alpha',
  openrouterBaseUrl: process.env.OPENROUTER_BASE_URL?.trim() || 'https://openrouter.ai/api/v1',
  /** Cloud fallback when the primary backend is unavailable. */
  deepseekKey: process.env.DEEPSEEK_API_KEY?.trim() || '',
  deepseekModel: process.env.DEEPSEEK_MODEL?.trim() || 'deepseek-chat',
  deepseekBaseUrl: process.env.DEEPSEEK_BASE_URL?.trim() || 'https://api.deepseek.com',
  host: process.env.HOST?.trim() || '0.0.0.0',
  port: envNumber('PORT', 3000),
  xpPerChat: envNumber('XP_PER_CHAT', 10),
  xpPerCheckin: envNumber('XP_PER_CHECKIN', 5),
  xpPerTap: envNumber('XP_PER_TAP', 2),
  moodDecayHours: envNumber('MOOD_DECAY_HOURS', 12),
  sessionMaxAgeDays: envNumber('SESSION_MAX_AGE_DAYS', 30),
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
