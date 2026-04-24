import express from 'express'

import db from '../db/index.ts'
import { getRequestAuth, getSessionToken, requireAccount } from '../middleware/auth.ts'
import {
  buildAuthPayload,
  clearSession,
  createHouseholdCode,
  createSession,
  hashPassword,
  isValidPassword,
  isValidUsername,
  normalizeHouseholdCode,
  normalizeUsername,
  verifyPassword,
} from '../services/auth.ts'
import { createPet } from '../services/pets.ts'

const router = express.Router()
const colorPattern = /^#[0-9a-f]{6}$/i

function readName(raw: unknown) {
  return typeof raw === 'string' ? raw.trim() : ''
}

function readColor(raw: unknown) {
  return typeof raw === 'string' && colorPattern.test(raw) ? raw : '#1D9E75'
}

function createUniqueHouseholdCode() {
  let code = createHouseholdCode()

  while (db.prepare('SELECT 1 FROM households WHERE code = ?').get(code)) {
    code = createHouseholdCode()
  }

  return code
}

router.post('/bootstrap', (request, response) => {
  const householdName = readName(request.body?.household_name)
  const adminName = readName(request.body?.admin_name)
  const username = normalizeUsername(request.body?.username ?? '')
  const password = typeof request.body?.password === 'string' ? request.body.password : ''
  const avatarColor = readColor(request.body?.avatar_color)

  if (!householdName || !adminName) {
    response.status(400).json({ error: 'Household and admin names are required' })
    return
  }

  if (!isValidUsername(username)) {
    response.status(400).json({ error: 'Username must be 3 to 30 characters using letters, numbers, dot, dash, or underscore' })
    return
  }

  if (!isValidPassword(password)) {
    response.status(400).json({ error: 'Password must be at least 8 characters' })
    return
  }

  const pendingAdmin = db
    .prepare(
      `SELECT accounts.id AS account_id,
              accounts.household_id,
              members.id AS member_id
       FROM accounts
       JOIN members ON members.id = accounts.member_id
       WHERE accounts.id = 1
         AND accounts.is_admin = 1
         AND accounts.password_hash = ''`,
    )
    .get() as
    | { account_id: number; household_id: number; member_id: number }
    | undefined

  try {
    if (pendingAdmin) {
      const usernameTaken = db
        .prepare(
          `SELECT 1
           FROM accounts
           WHERE household_id = ?
             AND username = ?
             AND id != ?`,
        )
        .get(pendingAdmin.household_id, username, pendingAdmin.account_id)

      if (usernameTaken) {
        response.status(409).json({ error: 'That username is already in use for this household' })
        return
      }

      const { salt, hash } = hashPassword(password)
      const householdCode = createUniqueHouseholdCode()

      db.transaction(() => {
        db.prepare(
          `UPDATE households
           SET name = ?, code = ?
           WHERE id = ?`,
        ).run(householdName, householdCode, pendingAdmin.household_id)

        db.prepare(
          `UPDATE members
           SET name = ?, avatar_color = ?
           WHERE id = ?`,
        ).run(adminName, avatarColor, pendingAdmin.member_id)

        db.prepare(
          `UPDATE accounts
           SET username = ?, password_hash = ?, password_salt = ?
           WHERE id = ?`,
        ).run(username, hash, salt, pendingAdmin.account_id)

        db.prepare('DELETE FROM account_invites WHERE account_id = ?').run(pendingAdmin.account_id)
      })()

      const session = createSession(pendingAdmin.account_id)
      response.status(201).json(buildAuthPayload(session.token, session.auth))
      return
    }

    const householdCode = createUniqueHouseholdCode()
    const usernameTaken = db
      .prepare(
        `SELECT 1
         FROM accounts
         JOIN households ON households.id = accounts.household_id
         WHERE households.code = ? AND accounts.username = ?`,
      )
      .get(householdCode, username)

    if (usernameTaken) {
      response.status(409).json({ error: 'That username is already in use for this household' })
      return
    }

    const { salt, hash } = hashPassword(password)
    let accountId = 0

    db.transaction(() => {
      const householdResult = db
        .prepare(
          `INSERT INTO households (name, code)
           VALUES (?, ?)`,
        )
        .run(householdName, householdCode)

      const householdId = Number(householdResult.lastInsertRowid)

      createPet(householdId)

      const memberResult = db
        .prepare(
          `INSERT INTO members (household_id, name, avatar_color)
           VALUES (?, ?, ?)`,
        )
        .run(householdId, adminName, avatarColor)

      const memberId = Number(memberResult.lastInsertRowid)
      db.prepare(
        `INSERT INTO affection (household_id, member_id)
         VALUES (?, ?)`,
      ).run(householdId, memberId)

      const accountResult = db
        .prepare(
          `INSERT INTO accounts (
             household_id,
             member_id,
             username,
             password_hash,
             password_salt,
             is_admin
           )
           VALUES (?, ?, ?, ?, ?, 1)`,
        )
        .run(householdId, memberId, username, hash, salt)

      accountId = Number(accountResult.lastInsertRowid)
    })()

    const session = createSession(accountId)
    response.status(201).json(buildAuthPayload(session.token, session.auth))
  } catch (error) {
    if (error instanceof Error && /UNIQUE constraint failed: accounts.household_id, accounts.username/.test(error.message)) {
      response.status(409).json({ error: 'That username is already in use for this household' })
      return
    }

    throw error
  }
})

router.post('/login', (request, response) => {
  const householdCode = normalizeHouseholdCode(request.body?.household_code ?? '')
  const username = normalizeUsername(request.body?.username ?? '')
  const password = typeof request.body?.password === 'string' ? request.body.password : ''

  if (!householdCode || !username || !password) {
    response.status(400).json({ error: 'Household code, username, and password are required' })
    return
  }

  const account = db
    .prepare(
      `SELECT accounts.id,
              accounts.password_hash,
              accounts.password_salt
       FROM accounts
       JOIN households ON households.id = accounts.household_id
       WHERE households.code = ?
         AND accounts.username = ?`,
    )
    .get(householdCode, username) as
    | { id: number; password_hash: string; password_salt: string }
    | undefined

  if (!account || !verifyPassword(password, account.password_salt, account.password_hash)) {
    response.status(401).json({ error: 'Invalid login details' })
    return
  }

  const session = createSession(account.id)
  response.json(buildAuthPayload(session.token, session.auth))
})

router.post('/accept-invite', (request, response) => {
  const inviteCode = normalizeHouseholdCode(request.body?.invite_code ?? '')
  const password = typeof request.body?.password === 'string' ? request.body.password : ''

  if (!inviteCode) {
    response.status(400).json({ error: 'Invite code is required' })
    return
  }

  if (!isValidPassword(password)) {
    response.status(400).json({ error: 'Password must be at least 8 characters' })
    return
  }

  const invite = db
    .prepare(
      `SELECT account_invites.account_id,
              account_invites.accepted_at,
              accounts.password_hash
       FROM account_invites
       JOIN accounts ON accounts.id = account_invites.account_id
       WHERE account_invites.code = ?`,
    )
    .get(inviteCode) as
    | { account_id: number; accepted_at: string | null; password_hash: string }
    | undefined

  if (!invite) {
    response.status(404).json({ error: 'Invite not found' })
    return
  }

  if (invite.accepted_at || invite.password_hash) {
    response.status(409).json({ error: 'Invite has already been used' })
    return
  }

  const { salt, hash } = hashPassword(password)

  db.transaction(() => {
    db.prepare(
      `UPDATE accounts
       SET password_hash = ?, password_salt = ?
       WHERE id = ?`,
    ).run(hash, salt, invite.account_id)

    db.prepare(
      `UPDATE account_invites
       SET accepted_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
       WHERE account_id = ?`,
    ).run(invite.account_id)
  })()

  const session = createSession(invite.account_id)
  response.json(buildAuthPayload(session.token, session.auth))
})

router.get('/me', requireAccount, (request, response) => {
  const auth = getRequestAuth(request)
  const sessionToken = getSessionToken(request)
  response.json(buildAuthPayload(sessionToken, auth))
})

router.post('/logout', requireAccount, (request, response) => {
  const sessionToken = getSessionToken(request)

  if (sessionToken) {
    clearSession(sessionToken)
  }

  response.status(204).send()
})

router.get('/household/:code', (request, response) => {
  const code = normalizeHouseholdCode(request.params.code)
  const household = db
    .prepare(
      `SELECT id, name, code
       FROM households
       WHERE code = ?`,
    )
    .get(code) as { id: number; name: string; code: string } | undefined

  if (!household) {
    response.status(404).json({ error: 'Household not found' })
    return
  }

  response.json(household)
})

export default router
