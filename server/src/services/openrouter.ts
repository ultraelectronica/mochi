import axios from 'axios'

import { config } from '../config/index.ts'
import { cleanReply } from './llama.ts'
import type { ChatMessage } from './prompt.ts'

export async function openrouterReply(messages: ChatMessage[]) {
  if (!config.openrouterKey) {
    throw new Error('OPENROUTER_API_KEY is missing')
  }

  const response = await axios.post(
    `${config.openrouterBaseUrl}/chat/completions`,
    {
      model: config.openrouterModel,
      messages,
      temperature: 0.75,
      max_tokens: 100,
      stream: false,
    },
    {
      timeout: 12_000,
      headers: {
        Authorization: `Bearer ${config.openrouterKey}`,
      },
    },
  )

  const rawReply =
    typeof response.data?.choices?.[0]?.message?.content === 'string'
      ? response.data.choices[0].message.content
      : ''

  if (!rawReply.trim()) {
    throw new Error('OpenRouter returned an empty reply')
  }

  const userMsg = messages.findLast((m) => m.role === 'user')
  return cleanReply(rawReply, userMsg?.content)
}
