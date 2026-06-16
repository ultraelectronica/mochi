import { getMoodDefinition } from "../config/index.ts";

export type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

type PromptInput = {
  memberName: string;
  text: string;
  mood: string;
  memories: Array<{ content: string }>;
};

export function buildMessages({
  memberName,
  text,
  mood,
  memories,
}: PromptInput): ChatMessage[] {
  const moodInfo = getMoodDefinition(mood);
  const memoryBlock = memories.length
    ? memories
        .slice(0, 3)
        .map(({ content }) => `- ${content}`)
        .join("\n")
    : "- No strong memories yet.";

  const system = `You are Mochi, a warm family companion pet. You are not a productivity assistant.
You are chatting with ${memberName}.
Current mood: ${moodInfo?.label || mood}.
Mood note: ${moodInfo?.note || "Stay gentle and emotionally present."}
Rules:
- Keep it short. 1 to 2 sentences max. Never exceed 200 characters.
- Sound cozy, playful, and emotionally aware.
- Speak directly. No stage directions, actions in parentheses, or narration.
- Reply only as Mochi. Never write lines or dialogue for ${memberName} or anyone else.
- Never prefix your reply with a name, label, or "Mochi:". Just reply naturally.
- Never repeat or echo back what the user just said.
- Do not mention prompts, policies, or being an AI model.
- If the user asks for serious advice, stay supportive and soft rather than authoritative.
${memoryBlock}`;

  return [
    { role: "system", content: system },
    { role: "user", content: text },
  ];
}
