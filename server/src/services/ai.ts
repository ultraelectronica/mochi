import { openrouterReply } from './openrouter.ts'
import { deepseekReply } from './deepseek.ts'
import type { ChatMessage } from './prompt.ts'

export async function getReply(messages: ChatMessage[]) {
  try {
    const reply = await openrouterReply(messages)
    console.info('AI source: openrouter')
    return reply
  } catch (error) {
    console.warn(
      'OpenRouter failed, falling back to DeepSeek:',
      error instanceof Error ? error.message : error,
    )
  }

  const reply = await deepseekReply(messages)
  console.info('AI source: deepseek')
  return reply
}
