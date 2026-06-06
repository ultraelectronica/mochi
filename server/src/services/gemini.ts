import axios from 'axios'

import { config } from '../config/index.ts'

function cleanReply(text: string) {
  const compact = text
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

export async function geminiReply(prompt: string) {
  if (!config.geminiKey) {
    throw new Error('GEMINI_API_KEY is missing')
  }

  const response = await axios.post(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${config.geminiKey}`,
    {
      contents: [
        {
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        temperature: 0.75,
        maxOutputTokens: 160,
      },
    },
    {
      timeout: 10_000,
    },
  )

  const rawReply = response.data?.candidates?.[0]?.content?.parts
    ?.map((part: { text?: string }) => part.text || '')
    .join(' ')
    .trim()

  if (!rawReply) {
    throw new Error('Gemini returned an empty reply')
  }

  return cleanReply(rawReply)
}
