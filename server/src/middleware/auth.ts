import type { NextFunction, Request, Response } from 'express'

import { config } from '../config/index.ts'

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

  const header = request.headers.authorization?.trim()
  const expected = `Bearer ${config.apiKey}`

  if (header !== expected) {
    response.status(401).json({ error: 'Unauthorized' })
    return
  }

  next()
}
