import type { NextFunction, Request, Response } from 'express'

import { config } from '../config/index.ts'
import {
  type AuthContext,
  getAuthContextFromSessionToken,
  sessionHeaderName,
} from '../services/auth.ts'

export type AuthenticatedRequest = Request & {
  auth?: AuthContext
}

function readSessionToken(request: Request) {
  const header = request.headers[sessionHeaderName]

  if (typeof header === 'string') {
    return header.trim()
  }

  if (Array.isArray(header)) {
    return header[0]?.trim() || ''
  }

  return ''
}

/**
 * When `MOCHI_API_KEY` is set in the environment, require
 * `Authorization: Bearer <same value>` on all routes that use this middleware.
 * When unset, this is a no-op (backward-compatible local dev).
 */
export function requireApiKey(request: Request, response: Response, next: NextFunction) {
  if (!config.apiKey) {
    next()
    return
  }

  const token = request.headers.authorization?.split(' ').pop()

  if (token !== config.apiKey) {
    response.status(401).json({ error: 'Unauthorized' })
    return
  }

  next()
}

export function requireAccount(request: Request, response: Response, next: NextFunction) {
  const token = readSessionToken(request)

  if (!token) {
    response.status(401).json({ error: 'Login required' })
    return
  }

  const auth = getAuthContextFromSessionToken(token)

  if (!auth) {
    response.status(401).json({ error: 'Session expired or invalid' })
    return
  }

  ;(request as AuthenticatedRequest).auth = auth
  next()
}

export function requireAdmin(request: Request, response: Response, next: NextFunction) {
  const auth = (request as AuthenticatedRequest).auth

  if (!auth?.isAdmin) {
    response.status(403).json({ error: 'Admin access required' })
    return
  }

  next()
}

export function getRequestAuth(request: Request) {
  const auth = (request as AuthenticatedRequest).auth

  if (!auth) {
    throw new Error('Missing authenticated request context')
  }

  return auth
}

export function getSessionToken(request: Request) {
  return readSessionToken(request)
}
