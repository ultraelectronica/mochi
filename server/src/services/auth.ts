import crypto from 'node:crypto'

import db from '../db/index.ts'

const passwordKeyLength = 64
const householdCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const inviteCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const usernamePattern = /^[a-z0-9](?:[a-z0-9._-]{1,28}[a-z0-9])?$/

export const sessionHeaderName = 'x-mochi-session'

export type AuthContext = {
  accountId: number
  householdId: number
  householdName: string
  householdCode: string
  memberId: number
  memberName: string
  memberAvatarColor: string
  username: string
  isAdmin: boolean
}

type AuthRow = {
  account_id: number
  household_id: number
  household_name: string
  household_code: string
  member_id: number
  member_name: string
  member_avatar_color: string
  username: string
  is_admin: number
}

type SessionRow = AuthRow & {
  session_id: number
}

function buildCode(length: number, alphabet: string) {
  const bytes = crypto.randomBytes(length)
  let code = ''

  for (let index = 0; index < length; index += 1) {
    code += alphabet[bytes[index] % alphabet.length]
  }

  return code
}

function mapAuthRow(row: AuthRow): AuthContext {
  return {
    accountId: row.account_id,
    householdId: row.household_id,
    householdName: row.household_name,
    householdCode: row.household_code,
    memberId: row.member_id,
    memberName: row.member_name,
    memberAvatarColor: row.member_avatar_color,
    username: row.username,
    isAdmin: row.is_admin === 1,
  }
}

export function normalizeUsername(raw: string) {
  return raw.trim().toLowerCase()
}

export function normalizeHouseholdCode(raw: string) {
  return raw.trim().toUpperCase()
}

export function isValidUsername(raw: string) {
  return usernamePattern.test(normalizeUsername(raw))
}

export function isValidPassword(raw: string) {
  return raw.trim().length >= 8
}

export function fallbackUsername(raw: string, suffix: number) {
  const stripped = raw
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/^\.+|\.+$/g, '')
    .replace(/\.{2,}/g, '.')

  if (isValidUsername(stripped)) {
    return stripped
  }

  return `member${suffix}`
}

export function createHouseholdCode() {
  return buildCode(6, householdCodeAlphabet)
}

export function createInviteCode() {
  return buildCode(10, inviteCodeAlphabet)
}

export function hashPassword(password: string) {
  const salt = crypto.randomBytes(16).toString('hex')
  const hash = crypto.scryptSync(password, salt, passwordKeyLength).toString('hex')
  return { salt, hash }
}

export function verifyPassword(password: string, salt: string, expectedHash: string) {
  if (!salt || !expectedHash) {
    return false
  }

  const actualHash = crypto.scryptSync(password, salt, passwordKeyLength)
  const expected = Buffer.from(expectedHash, 'hex')

  if (actualHash.length !== expected.length) {
    return false
  }

  return crypto.timingSafeEqual(actualHash, expected)
}

export function hashToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex')
}

export function getAuthContextByAccountId(accountId: number) {
  const row = db
    .prepare(
      `SELECT accounts.id AS account_id,
              accounts.household_id,
              households.name AS household_name,
              households.code AS household_code,
              members.id AS member_id,
              members.name AS member_name,
              members.avatar_color AS member_avatar_color,
              accounts.username,
              accounts.is_admin
       FROM accounts
       JOIN households ON households.id = accounts.household_id
       JOIN members ON members.id = accounts.member_id
       WHERE accounts.id = ?`,
    )
    .get(accountId) as AuthRow | undefined

  return row ? mapAuthRow(row) : null
}

export function createSession(accountId: number) {
  const auth = getAuthContextByAccountId(accountId)

  if (!auth) {
    throw new Error(`Account ${accountId} does not exist`)
  }

  const token = `${crypto.randomUUID()}${crypto.randomUUID()}`
  const tokenHash = hashToken(token)
  db.prepare('INSERT INTO auth_sessions (account_id, token_hash) VALUES (?, ?)').run(accountId, tokenHash)
  return { token, auth }
}

export function clearSession(token: string) {
  db.prepare('DELETE FROM auth_sessions WHERE token_hash = ?').run(hashToken(token))
}

export function getAuthContextFromSessionToken(token: string) {
  const normalized = token.trim()

  if (!normalized) {
    return null
  }

  const tokenHash = hashToken(normalized)
  const row = db
    .prepare(
      `SELECT auth_sessions.id AS session_id,
              accounts.id AS account_id,
              accounts.household_id,
              households.name AS household_name,
              households.code AS household_code,
              members.id AS member_id,
              members.name AS member_name,
              members.avatar_color AS member_avatar_color,
              accounts.username,
              accounts.is_admin
       FROM auth_sessions
       JOIN accounts ON accounts.id = auth_sessions.account_id
       JOIN households ON households.id = accounts.household_id
       JOIN members ON members.id = accounts.member_id
       WHERE auth_sessions.token_hash = ?`,
    )
    .get(tokenHash) as SessionRow | undefined

  if (!row) {
    return null
  }

  db.prepare(
    `UPDATE auth_sessions
     SET last_used_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
     WHERE id = ?`,
  ).run(row.session_id)

  return mapAuthRow(row)
}

export function buildAuthPayload(sessionToken: string, auth: AuthContext) {
  return {
    session_token: sessionToken,
    household: {
      id: auth.householdId,
      name: auth.householdName,
      code: auth.householdCode,
    },
    account: {
      id: auth.accountId,
      username: auth.username,
      is_admin: auth.isAdmin,
    },
    member: {
      id: auth.memberId,
      name: auth.memberName,
      avatar_color: auth.memberAvatarColor,
    },
  }
}
