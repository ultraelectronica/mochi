import { WebSocket, WebSocketServer } from 'ws'

import { config } from '../config/index.ts'
import { getAuthContextFromSessionToken, sessionHeaderName } from '../services/auth.ts'
import { getPet } from '../services/pets.ts'

const clients = new Map<WebSocket, number>()

function readSessionHeader(headers: Record<string, string | string[] | undefined>) {
  const header = headers[sessionHeaderName]

  if (typeof header === 'string') {
    return header.trim()
  }

  if (Array.isArray(header)) {
    return header[0]?.trim() || ''
  }

  return ''
}

export function initWS(server: Parameters<typeof WebSocketServer>[0]['server']) {
  const wsServer = new WebSocketServer({
    server,
    verifyClient: (info) => {
      const auth = info.req.headers['authorization']?.trim()

      if (config.apiKey && auth !== `Bearer ${config.apiKey}`) {
        return false
      }

      const sessionToken = readSessionHeader(info.req.headers)
      return Boolean(sessionToken && getAuthContextFromSessionToken(sessionToken))
    },
  })

  wsServer.on('connection', (socket, request) => {
    const sessionToken = readSessionHeader(request.headers)
    const auth = getAuthContextFromSessionToken(sessionToken)

    if (!auth) {
      socket.close()
      return
    }

    clients.set(socket, auth.householdId)
    socket.send(JSON.stringify({ type: 'welcome', pet: getPet(auth.householdId) }))

    socket.on('close', () => {
      clients.delete(socket)
    })

    socket.on('error', () => {
      clients.delete(socket)
    })
  })

  return wsServer
}

export function broadcastHousehold(householdId: number, payload: unknown) {
  const message = JSON.stringify(payload)

  for (const [client, clientHouseholdId] of clients) {
    if (clientHouseholdId !== householdId) {
      continue
    }

    if (client.readyState === WebSocket.OPEN) {
      client.send(message)
      continue
    }

    clients.delete(client)
  }
}
