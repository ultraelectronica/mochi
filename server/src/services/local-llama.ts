import { spawn, type ChildProcess } from 'node:child_process'
import fs from 'node:fs'

import { config } from '../config/index.ts'
import { pingLlama } from './llama.ts'

let child: ChildProcess | null = null
let spawnAttempted = false

function resolveUrl() {
  const url = config.llamaUrl.trim() || `http://${config.llamaHost}:${config.llamaPort}`
  return url.endsWith('/') ? url.slice(0, -1) : url
}

/**
 * Ensure a local llama.cpp HTTP server is reachable. If one is already running
 * (e.g. a manually started `llama-server`), we use it. Otherwise, when
 * `LLAMA_SPAWN` is enabled and the binary + model exist, we spawn one as a
 * child process so `pnpm dev` is self-sufficient.
 *
 * Never throws — local inference is best-effort, with DeepSeek as the cloud
 * fallback when it is unavailable.
 */
export async function ensureLocalLlama() {
  if (await pingLlama()) {
    console.info(`Local llama already reachable at ${resolveUrl()}`)
    return
  }

  if (!config.llamaSpawn) {
    console.warn('LLAMA_SPAWN is disabled; skipping local llama startup.')
    return
  }

  if (spawnAttempted) {
    return
  }
  spawnAttempted = true

  if (!config.llamaBinary || !fs.existsSync(config.llamaBinary)) {
    console.warn(
      `LLAMA_BINARY not found at "${config.llamaBinary}". Local model disabled; DeepSeek will be used.`,
    )
    return
  }

  if (!config.llamaModel || !fs.existsSync(config.llamaModel)) {
    console.warn(
      `LLAMA_MODEL not found at "${config.llamaModel}". Local model disabled; DeepSeek will be used.`,
    )
    return
  }

  const args = [
    '-m', config.llamaModel,
    '--host', config.llamaHost,
    '--port', String(config.llamaPort),
    '--ctx-size', String(config.llamaCtxSize),
    '-np', '4',
  ]

  if (config.llamaThreads > 0) {
    args.push('-t', String(config.llamaThreads))
  }

  console.info(`Spawning local llama-server: ${config.llamaBinary} ${args.join(' ')}`)

  child = spawn(config.llamaBinary, args, {
    stdio: ['ignore', 'pipe', 'pipe'],
  })

  child.stdout?.on('data', (chunk: Buffer) => process.stdout.write(`[llama] ${chunk}`))
  child.stderr?.on('data', (chunk: Buffer) => process.stderr.write(`[llama] ${chunk}`))

  child.on('exit', (code, signal) => {
    console.info(`Local llama-server exited (code=${code} signal=${signal})`)
    child = null
  })

  child.on('error', (error) => {
    console.warn('Local llama-server failed to spawn:', error.message)
    child = null
  })

  await waitForHealth()
}

async function waitForHealth() {
  const deadline = Date.now() + 30_000
  while (Date.now() < deadline) {
    if (await pingLlama()) {
      console.info(`Local llama-server is ready at ${resolveUrl()}`)
      return
    }
    await new Promise((resolve) => setTimeout(resolve, 500))
  }
  console.warn('Local llama-server did not become healthy in 30s; DeepSeek will be used.')
}

export function stopLocalLlama() {
  if (!child) {
    return
  }
  try {
    child.kill('SIGTERM')
  } catch {
    // ignore
  }
  child = null
}
