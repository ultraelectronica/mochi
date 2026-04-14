import axios from 'axios'

import { config } from '../config/index.ts'

function withTrailingSlash(url: string) {
  return url.endsWith('/') ? url : `${url}/`
}

function cleanReply(text: string) {
  const compact = text
    .replace(/<\|assistant\|>/g, '')
    .replace(/<\|user\|>/g, '')
    .replace(/<\|system\|>/g, '')
    .replace(/^mochi:\s*/i, '')
    .replace(/\s+/g, ' ')
    .trim()

  if (compact.length <= 280) {
    return compact
  }

  const slice = compact.slice(0, 280)
  const boundary = Math.max(slice.lastIndexOf('.'), slice.lastIndexOf('!'), slice.lastIndexOf('?'))

  if (boundary >= 80) {
    return slice.slice(0, boundary + 1).trim()
  }

  return `${slice.trimEnd()}...`
}

export async function pingLlama() {
  try {
    await axios.get(new URL('health', withTrailingSlash(config.llamaUrl)).toString(), {
      timeout: 1500,
    })
    return true
  } catch {
    return false
  }
}

export async function llamaReply(prompt: string) {
  const response = await axios.post(
    new URL('completion', withTrailingSlash(config.llamaUrl)).toString(),
    {
      prompt,
      n_predict: 150,
      temp: 0.75,
      temperature: 0.75,
      stop: ['<|user|>', '<|system|>'],
    },
    {
      timeout: 10_000,
    },
  )

  const rawReply =
    typeof response.data?.content === 'string'
      ? response.data.content
      : typeof response.data?.response === 'string'
        ? response.data.response
        : typeof response.data?.choices?.[0]?.text === 'string'
          ? response.data.choices[0].text
          : ''

  if (!rawReply.trim()) {
    throw new Error('Llama returned an empty reply')
  }

  return cleanReply(rawReply)
}
