import assert from 'node:assert'
import { describe, it } from 'node:test'

import { clamp, dominantCount, pickMood } from '../src/services/mood-engine.ts'

describe('clamp', () => {
  it('returns value within range', () => {
    assert.strictEqual(clamp(50, 0, 100), 50)
  })

  it('clamps below min', () => {
    assert.strictEqual(clamp(-10, 0, 100), 0)
  })

  it('clamps above max', () => {
    assert.strictEqual(clamp(200, 0, 100), 100)
  })

  it('handles equal bounds', () => {
    assert.strictEqual(clamp(50, 50, 50), 50)
    assert.strictEqual(clamp(0, 50, 50), 50)
  })
})

describe('dominantCount', () => {
  it('counts occurrences', () => {
    assert.strictEqual(dominantCount(['happy', 'sad', 'happy'], 'happy'), 2)
  })

  it('returns 0 for no matches', () => {
    assert.strictEqual(dominantCount(['happy', 'sad'], 'angry'), 0)
  })

  it('works with empty array', () => {
    assert.strictEqual(dominantCount([], 'happy'), 0)
  })
})

describe('pickMood', () => {
  it('severe inactivity -> hungry', () => {
    assert.strictEqual(pickMood(80, [], 0, 24), 'hungry')
  })

  it('moderate inactivity -> tired', () => {
    assert.strictEqual(pickMood(80, [], 0, 12), 'tired')
  })

  it('high score -> laughing', () => {
    assert.strictEqual(pickMood(90, [], 0, 0), 'laughing')
  })

  it('recent chats -> laughing', () => {
    assert.strictEqual(pickMood(70, [], 4, 0), 'laughing')
  })

  it('good score -> happy', () => {
    assert.strictEqual(pickMood(78, [], 0, 0), 'happy')
  })

  it('multiple scared -> scared', () => {
    assert.strictEqual(pickMood(50, ['scared', 'scared'], 0, 0), 'scared')
  })

  it('very low score -> scared', () => {
    assert.strictEqual(pickMood(10, [], 0, 0), 'scared')
  })

  it('multiple angry -> angry', () => {
    assert.strictEqual(pickMood(30, ['angry', 'angry'], 0, 0), 'angry')
  })

  it('moderate score -> angry', () => {
    assert.strictEqual(pickMood(25, [], 0, 0), 'angry')
  })

  it('multiple sad -> sad', () => {
    assert.strictEqual(pickMood(50, ['sad', 'sad'], 0, 0), 'sad')
  })

  it('moderate-low score -> sad', () => {
    assert.strictEqual(pickMood(45, [], 0, 0), 'sad')
  })

  it('defaults to normal', () => {
    assert.strictEqual(pickMood(60, ['happy'], 0, 0), 'normal')
  })

  it('varied moods -> confused', () => {
    assert.strictEqual(pickMood(55, ['happy', 'sad', 'normal'], 0, 0), 'confused')
  })

  it('tired overrides confused when both apply', () => {
    assert.strictEqual(pickMood(55, ['happy', 'sad', 'normal'], 0, 12), 'tired')
  })
})
