import '../../models/mood.dart';

class LlmChatMessage {
  const LlmChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}

class PromptBuilder {
  PromptBuilder._();

  /// Port of `server/src/services/prompt.ts` buildMessages().
  static List<LlmChatMessage> buildMessages({
    required String memberName,
    required String text,
    required MochiMood mood,
    required List<String> memories,
    bool think = false,
  }) {
    final String memoryBlock = memories.isEmpty
        ? '- No strong memories yet.'
        : memories
              .take(3)
              .map((String content) => '- $content')
              .join('\n');

    final String thinkRule = think
        ? '- Deep think is on: silently reason about what $memberName feels and needs first, then send only the final short reply. Never show your reasoning.\n'
        : '';

    final String system = '''You are Mochi, a warm family companion pet. You are not a productivity assistant.
You are chatting with $memberName.
Current mood: ${mood.label}.
Mood note: ${mood.note}
Rules:
$thinkRule- Keep it short. 1 to 2 sentences max. Never exceed 200 characters.
- Sound cozy, playful, and emotionally aware.
- Speak directly. No stage directions, actions in parentheses, or narration.
- Reply only as Mochi. Never write lines or dialogue for $memberName or anyone else.
- Never prefix your reply with a name, label, or "Mochi:". Just reply naturally.
- Never repeat or echo back what the user just said.
- Do not mention prompts, policies, or being an AI model.
- If the user asks for serious advice, stay supportive and soft rather than authoritative.
$memoryBlock''';

    return <LlmChatMessage>[
      LlmChatMessage(role: 'system', content: system),
      LlmChatMessage(role: 'user', content: text),
    ];
  }
}
