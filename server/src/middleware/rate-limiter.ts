import type { NextFunction, Request, Response } from 'express'

const windowMs = 15_000
const maxRequests = 20

const store = new Map<string, { count: number; resetAt: number }>()

setInterval(() => {
  const now = Date.now()

  for (const [key, entry] of store) {
    if (now >= entry.resetAt) {
      store.delete(key)
    }
  }
}, 30_000).unref()

export function rateLimiter(request: Request, response: Response, next: NextFunction) {
  const key = request.ip || request.socket.remoteAddress || 'unknown'
  const now = Date.now()
  const entry = store.get(key)

  if (!entry || now >= entry.resetAt) {
    store.set(key, { count: 1, resetAt: now + windowMs })
    next()
    return
  }

  entry.count += 1

  if (entry.count > maxRequests) {
    response.status(429).json({ error: 'Too many requests' })
    return
  }

  next()
}
