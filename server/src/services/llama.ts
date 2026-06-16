import axios from 'axios'

import { config } from '../config/index.ts'
import type { ChatMessage } from './prompt.ts'

function withTrailingSlash(url: string) {
  return url.endsWith('/') ? url.slice(0, -1) : url
}

/** Shared reply tidy-up used by every model backend. */
export function cleanReply(text: string, userText?: string) {
  const firstTurn = text
    .split(/<\|user\|>|<\|system\|>|<\/s>|<\|end\|>|\bMochi:|\bUser:|\bHuman:|\bAssistant:|\bMochi\s+response:|\bMochi\s+says:/i)[0]

  let compact = firstTurn
    .replace(/<\|assistant\|>/g, '')
    .replace(/^mochi[\s']*(response|says|replied)?:\s*/i, '')
    .replace(/\s+/g, ' ')
    .trim()

  if (userText) {
    const escaped = userText.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    compact = compact.replace(new RegExp(`^${escaped}\\s*`, 'i'), '').trim()
  }

  if (!compact || !/[a-z0-9]/i.test(compact)) {
    return ''
  }

  if (compact.length <= 200) {
    return compact
  }

  const slice = compact.slice(0, 200)
  const boundary = Math.max(slice.lastIndexOf('.'), slice.lastIndexOf('!'), slice.lastIndexOf('?'))

  if (boundary >= 40) {
    return slice.slice(0, boundary + 1).trim()
  }

  return `${slice.trimEnd()}...`
}

export async function pingLlama() {
  try {
    await axios.get(`${withTrailingSlash(config.llamaUrl)}/health`, {
      timeout: 1500,
    })
    return true
  } catch {
    return false
  }
}

/**
 * TinyLlama often ignores EOS and invents extra turns, so we pass explicit
 * stop strings — the chat-template markers plus the member's name faking the
 * next user turn. DeepSeek does not need these.
 */
export async function llamaReply(messages: ChatMessage[], stops: string[] = []) {
  const response = await axios.post(
    `${withTrailingSlash(config.llamaUrl)}/v1/chat/completions`,
    {
      model: 'local',
      messages,
      temperature: 0.75,
      max_tokens: 80,
      stream: false,
      stop: ['<|user|>', '<|system|>', '</s>', ...stops],
    },
    {
      timeout: 12_000,
    },
  )

  const rawReply =
    typeof response.data?.choices?.[0]?.message?.content === 'string'
      ? response.data.choices[0].message.content
      : typeof response.data?.choices?.[0]?.text === 'string'
        ? response.data.choices[0].text
        : ''

  if (!rawReply.trim()) {
    throw new Error('Llama returned an empty reply')
  }

  const userMsg = messages.findLast((m) => m.role === 'user')
  const cleaned = cleanReply(rawReply, userMsg?.content)
  if (!cleaned) {
    throw new Error('Llama reply was unusable')
  }

  return cleaned
}
