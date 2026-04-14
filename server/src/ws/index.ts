import { WebSocket, WebSocketServer } from 'ws'

import db from '../db/index.ts'

const clients = new Set<WebSocket>()

const petSelect = `
  SELECT id, name, stage, total_xp, mood, mood_score, last_interaction_at, created_at
  FROM pet
  WHERE id = 1
`

export function initWS(server: Parameters<typeof WebSocketServer>[0]['server']) {
  const wsServer = new WebSocketServer({ server })

  wsServer.on('connection', (socket) => {
    clients.add(socket)
    socket.send(JSON.stringify({ type: 'welcome', pet: db.prepare(petSelect).get() }))

    socket.on('close', () => {
      clients.delete(socket)
    })

    socket.on('error', () => {
      clients.delete(socket)
    })
  })

  return wsServer
}

export function broadcast(payload: unknown) {
  const message = JSON.stringify(payload)

  for (const client of clients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message)
      continue
    }

    clients.delete(client)
  }
}
