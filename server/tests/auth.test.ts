import assert from 'node:assert'
import { describe, it } from 'node:test'

import {
  createHouseholdCode,
  createInviteCode,
  fallbackUsername,
  hashPassword,
  hashToken,
  isValidPassword,
  isValidUsername,
  normalizeHouseholdCode,
  normalizeUsername,
  verifyPassword,
} from '../src/services/auth.ts'

describe('normalizeUsername', () => {
  it('trims and lowercases', () => {
    assert.strictEqual(normalizeUsername('  HelloWorld  '), 'helloworld')
  })

  it('handles empty', () => {
    assert.strictEqual(normalizeUsername(''), '')
  })
})

describe('normalizeHouseholdCode', () => {
  it('trims and uppercases', () => {
    assert.strictEqual(normalizeHouseholdCode('  abcde1  '), 'ABCDE1')
  })
})

describe('isValidUsername', () => {
  it('accepts lowercase alphanumeric', () => {
    assert.strictEqual(isValidUsername('hello'), true)
    assert.strictEqual(isValidUsername('hello123'), true)
  })

  it('accepts dots dashes underscores in middle', () => {
    assert.strictEqual(isValidUsername('hello.world'), true)
    assert.strictEqual(isValidUsername('hello-world'), true)
    assert.strictEqual(isValidUsername('hello_world'), true)
  })

  it('rejects too short', () => {
    assert.strictEqual(isValidUsername('a'), true)
    assert.strictEqual(isValidUsername(''), false)
  })

  it('rejects too long', () => {
    assert.strictEqual(isValidUsername('a'.repeat(31)), false)
  })

  it('rejects leading/trailing special chars', () => {
    assert.strictEqual(isValidUsername('.hello'), false)
    assert.strictEqual(isValidUsername('hello.'), false)
    assert.strictEqual(isValidUsername('-hello'), false)
  })

  it('normalizes uppercase to lowercase', () => {
    assert.strictEqual(isValidUsername('Hello'), true)
    assert.strictEqual(isValidUsername('HELLO'), true)
  })

  it('rejects spaces', () => {
    assert.strictEqual(isValidUsername('hello world'), false)
  })
})

describe('isValidPassword', () => {
  it('requires at least 8 chars', () => {
    assert.strictEqual(isValidPassword('12345678'), true)
    assert.strictEqual(isValidPassword('1234567'), false)
  })

  it('trims before checking', () => {
    assert.strictEqual(isValidPassword('  1234567  '), false)
  })
})

describe('fallbackUsername', () => {
  it('sanitizes common inputs', () => {
    assert.strictEqual(fallbackUsername('John Doe', 1), 'john.doe')
  })

  it('falls back to memberN for all-special input', () => {
    assert.strictEqual(fallbackUsername('!!!', 42), 'member42')
  })

  it('strips leading/trailing dots', () => {
    assert.strictEqual(fallbackUsername('  john doe  ', 1), 'john.doe')
  })

  it('collapses multiple dots', () => {
    assert.strictEqual(fallbackUsername('john   doe', 1), 'john.doe')
  })
})

describe('hashPassword / verifyPassword', () => {
  it('verifies a correct password', () => {
    const { salt, hash } = hashPassword('mysecret123')
    assert.strictEqual(verifyPassword('mysecret123', salt, hash), true)
  })

  it('rejects an incorrect password', () => {
    const { salt, hash } = hashPassword('mysecret123')
    assert.strictEqual(verifyPassword('wrongpass', salt, hash), false)
  })

  it('rejects empty salt or hash', () => {
    assert.strictEqual(verifyPassword('test', '', 'hash'), false)
    assert.strictEqual(verifyPassword('test', 'salt', ''), false)
  })
})

describe('hashToken', () => {
  it('produces consistent output', () => {
    assert.strictEqual(hashToken('test-token'), hashToken('test-token'))
  })

  it('produces different output for different input', () => {
    assert.notStrictEqual(hashToken('a'), hashToken('b'))
  })
})

describe('createHouseholdCode', () => {
  it('produces 6-char code', () => {
    assert.strictEqual(createHouseholdCode().length, 6)
  })
})

describe('createInviteCode', () => {
  it('produces 10-char code', () => {
    assert.strictEqual(createInviteCode().length, 10)
  })
})
