import http from 'node:http'

import express from 'express'

import { startMoodDecayJob } from './jobs/mood-decay.ts'
import { config } from './config/index.ts'
import { runMigrations } from './db/migrations.ts'
import { requireApiKey } from './middleware/auth.ts'
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
app.use((request, response, next) => {
  response.setHeader('Access-Control-Allow-Origin', '*')
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS')
  response.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization',
  )

  if (request.method === 'OPTIONS') {
    response.status(204).send()
    return
  }

  next()
})

app.use('/health', healthRoutes)

app.use(requireApiKey)
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

server.listen(config.port, () => {
  console.info(`Mochi server listening on port ${config.port}`)
  if (config.apiKey) {
    console.info('API key auth is enabled (MOCHI_API_KEY). Send Authorization: Bearer … on API and WebSocket.')
  } else {
    console.warn(
      'MOCHI_API_KEY is not set: HTTP API (except GET /health) and WebSocket are open. Set MOCHI_API_KEY for local or LAN use.',
    )
  }
})
