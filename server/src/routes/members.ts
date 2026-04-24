import express from 'express'

import db from '../db/index.ts'
import { getRequestAuth, requireAdmin } from '../middleware/auth.ts'
import { createInviteCode, isValidUsername, normalizeUsername } from '../services/auth.ts'

const router = express.Router()
const colorPattern = /^#[0-9a-f]{6}$/i

const memberSelect = `
  SELECT members.id,
         members.name,
         members.avatar_color,
         members.total_xp,
         members.created_at,
         members.last_seen_at,
         COALESCE(affection.score, 0) AS affection_score,
         accounts.username,
         COALESCE(accounts.is_admin, 0) AS is_admin,
         CASE
           WHEN account_invites.id IS NOT NULL AND account_invites.accepted_at IS NULL THEN 1
           ELSE 0
         END AS invite_pending
  FROM members
  LEFT JOIN affection ON affection.member_id = members.id
  LEFT JOIN accounts ON accounts.member_id = members.id
  LEFT JOIN account_invites ON account_invites.account_id = accounts.id
`

function parseId(raw: string) {
  const id = Number(raw)
  return Number.isInteger(id) && id > 0 ? id : null
}

router.get('/', (request, response) => {
  const auth = getRequestAuth(request)
  const members = db
    .prepare(
      `${memberSelect}
       WHERE members.household_id = ?
       ORDER BY datetime(members.created_at) ASC, members.id ASC`,
    )
    .all(auth.householdId)

  response.json(members)
})

router.post('/', requireAdmin, (request, response) => {
  const auth = getRequestAuth(request)
  const name = typeof request.body?.name === 'string' ? request.body.name.trim() : ''
  const username = normalizeUsername(request.body?.username ?? '')
  const avatarColor =
    typeof request.body?.avatar_color === 'string' && colorPattern.test(request.body.avatar_color)
      ? request.body.avatar_color
      : '#1D9E75'

  if (!name) {
    response.status(400).json({ error: 'Name is required' })
    return
  }

  if (!isValidUsername(username)) {
    response.status(400).json({ error: 'Username must be 3 to 30 characters using letters, numbers, dot, dash, or underscore' })
    return
  }

  const usernameTaken = db
    .prepare(
      `SELECT 1
       FROM accounts
       WHERE household_id = ? AND username = ?`,
    )
    .get(auth.householdId, username)

  if (usernameTaken) {
    response.status(409).json({ error: 'That username is already in use for this household' })
    return
  }

  const inviteCode = createInviteCode()
  let memberId = 0

  db.transaction(() => {
    const memberResult = db
      .prepare(
        `INSERT INTO members (household_id, name, avatar_color)
         VALUES (?, ?, ?)`,
      )
      .run(auth.householdId, name, avatarColor)

    memberId = Number(memberResult.lastInsertRowid)

    db.prepare(
      `INSERT INTO affection (household_id, member_id)
       VALUES (?, ?)`,
    ).run(auth.householdId, memberId)

    const accountResult = db
      .prepare(
        `INSERT INTO accounts (household_id, member_id, username)
         VALUES (?, ?, ?)`,
      )
      .run(auth.householdId, memberId, username)

    db.prepare(
      `INSERT INTO account_invites (account_id, household_id, created_by_account_id, code)
       VALUES (?, ?, ?, ?)`,
    ).run(accountResult.lastInsertRowid, auth.householdId, auth.accountId, inviteCode)
  })()

  const member = db
    .prepare(
      `${memberSelect}
       WHERE members.household_id = ?
         AND members.id = ?`,
    )
    .get(auth.householdId, memberId)

  response.status(201).json({ member, invite_code: inviteCode })
})

router.get('/:id', (request, response) => {
  const auth = getRequestAuth(request)
  const memberId = parseId(request.params.id)

  if (!memberId) {
    response.status(400).json({ error: 'Invalid member id' })
    return
  }

  const member = db
    .prepare(
      `${memberSelect}
       WHERE members.household_id = ?
         AND members.id = ?`,
    )
    .get(auth.householdId, memberId)

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  const recentMoodLogs = db
    .prepare(
      `SELECT id, mood, created_at
       FROM mood_log
       WHERE household_id = ?
         AND member_id = ?
       ORDER BY datetime(created_at) DESC
       LIMIT 10`,
    )
    .all(auth.householdId, memberId)

  response.json({
    ...member,
    recent_mood_logs: recentMoodLogs,
  })
})

router.delete('/:id', requireAdmin, (request, response) => {
  const auth = getRequestAuth(request)
  const memberId = parseId(request.params.id)

  if (!memberId) {
    response.status(400).json({ error: 'Invalid member id' })
    return
  }

  const member = db
    .prepare(
      `SELECT members.id,
              COALESCE(accounts.is_admin, 0) AS is_admin
       FROM members
       LEFT JOIN accounts ON accounts.member_id = members.id
       WHERE members.household_id = ?
         AND members.id = ?`,
    )
    .get(auth.householdId, memberId) as { id: number; is_admin: number } | undefined

  if (!member) {
    response.status(404).json({ error: 'Member not found' })
    return
  }

  if (member.id === auth.memberId) {
    response.status(403).json({ error: 'You cannot remove your own account' })
    return
  }

  if (member.is_admin === 1) {
    response.status(403).json({ error: 'Admin accounts cannot be removed' })
    return
  }

  db.prepare(
    `DELETE FROM members
     WHERE id = ? AND household_id = ?`,
  ).run(memberId, auth.householdId)

  response.status(204).send()
})

export default router
