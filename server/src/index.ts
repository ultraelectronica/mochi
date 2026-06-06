import http from 'node:http'

import express from 'express'
import type { Request, Response, NextFunction } from 'express'

import { startMoodDecayJob } from './jobs/mood-decay.ts'
import { startDailyCleanupJob } from './jobs/daily-cleanup.ts'
import { config } from './config/index.ts'
import db from './db/index.ts'
import { runMigrations } from './db/migrations.ts'
import { requireAccount, requireApiKey } from './middleware/auth.ts'
import { rateLimiter } from './middleware/rate-limiter.ts'
import authRoutes from './routes/auth.ts'
import chatRoutes from './routes/chat.ts'
import feedRoutes from './routes/feed.ts'
import healthRoutes from './routes/health.ts'
import membersRoutes from './routes/members.ts'
import moodRoutes from './routes/mood.ts'
import petRoutes from './routes/pet.ts'
import { initWS } from './ws/index.ts'

runMigrations()

const app = express()

app.use(express.json({ limit: '1mb' }))

app.use((request: Request, response: Response, next: NextFunction) => {
  const start = Date.now()
  response.on('finish', () => {
    const ms = Date.now() - start
    console.info(`${request.method} ${request.originalUrl} ${response.statusCode} ${ms}ms`)
  })
  next()
})

app.use((request, response, next) => {
  response.setHeader('Access-Control-Allow-Origin', '*')
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS')
  response.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Mochi-Session',
  )

  if (request.method === 'OPTIONS') {
    response.status(204).send()
    return
  }

  next()
})

app.use('/health', healthRoutes)

app.use(requireApiKey)
app.use(rateLimiter)
app.use('/auth', authRoutes)
app.use(requireAccount)
app.use('/pet', petRoutes)
app.use('/members', membersRoutes)
app.use('/chat', chatRoutes)
app.use('/mood', moodRoutes)
app.use('/feed', feedRoutes)

app.use((error: Error, _request: express.Request, response: express.Response, _next: express.NextFunction) => {
  console.error('Unhandled server error:', error)
  response.status(500).json({ error: 'Internal server error' })
})

const server = http.createServer(app)

initWS(server)
startMoodDecayJob()
startDailyCleanupJob()

function shutdown() {
  console.info('Shutting down gracefully…')
  db.close()
  server.close()
  process.exit(0)
}

process.on('SIGTERM', shutdown)
process.on('SIGINT', shutdown)

server.listen(config.port, config.host, () => {
  console.info(`Mochi server listening on ${config.host}:${config.port}`)
  if (config.apiKey) {
    console.info('API key auth is enabled (MOCHI_API_KEY). Send Authorization: Bearer … on API and WebSocket.')
  } else {
    console.warn(
      'MOCHI_API_KEY is not set: HTTP API (except GET /health) and WebSocket are open. Set MOCHI_API_KEY for local or LAN use.',
    )
  }
})
