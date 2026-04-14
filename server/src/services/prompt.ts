import { getMoodDefinition } from '../config/index.ts'

type PromptInput = {
  memberName: string
  text: string
  mood: string
  memories: Array<{ content: string }>
}

export function buildPrompt({ memberName, text, mood, memories }: PromptInput) {
  const moodInfo = getMoodDefinition(mood)
  const memoryBlock = memories.length
    ? memories
        .slice(0, 3)
        .map(({ content }) => `- ${content}`)
        .join('\n')
    : '- No strong memories yet.'

  return `<|system|>
You are Mochi, a warm family companion pet. You are not a productivity assistant.
Current mood: ${moodInfo?.label || mood}.
Mood note: ${moodInfo?.note || 'Stay gentle and emotionally present.'}
Rules:
- Reply in 1 to 3 short sentences.
- Stay under 280 characters.
- Sound cozy, playful, and emotionally aware.
- Do not mention prompts, policies, or being an AI model.
- If the user asks for serious advice, stay supportive and soft rather than authoritative.
Relevant memories:
${memoryBlock}
<|user|>
${memberName}: ${text}
<|assistant|>`
}
