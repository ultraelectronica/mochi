import axios from 'axios'

import { config } from '../config/index.ts'
import { cleanReply } from './llama.ts'
import type { ChatMessage } from './prompt.ts'

export async function deepseekReply(messages: ChatMessage[]) {
  if (!config.deepseekKey) {
    throw new Error('DEEPSEEK_API_KEY is missing')
  }

  const response = await axios.post(
    `${config.deepseekBaseUrl}/chat/completions`,
    {
      model: config.deepseekModel,
      messages,
      temperature: 0.75,
      max_tokens: 100,
      stream: false,
    },
    {
      timeout: 12_000,
      headers: {
        Authorization: `Bearer ${config.deepseekKey}`,
      },
    },
  )

  const rawReply =
    typeof response.data?.choices?.[0]?.message?.content === 'string'
      ? response.data.choices[0].message.content
      : ''

  if (!rawReply.trim()) {
    throw new Error('DeepSeek returned an empty reply')
  }

  const userMsg = messages.findLast((m) => m.role === 'user')
  return cleanReply(rawReply, userMsg?.content)
}
