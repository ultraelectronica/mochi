import { geminiReply } from './gemini.ts'
import { llamaReply } from './llama.ts'

export async function getReply(prompt: string) {
  try {
    const reply = await llamaReply(prompt)
    console.info('AI source: llama')
    return reply
  } catch (error) {
    console.warn(
      'Llama failed, falling back to Gemini:',
      error instanceof Error ? error.message : error,
    )
  }

  const reply = await geminiReply(prompt)
  console.info('AI source: gemini')
  return reply
}
