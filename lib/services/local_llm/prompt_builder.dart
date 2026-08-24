import '../../config/game_config.dart';
import '../../models/member.dart';
import '../../models/mood.dart';

class LlmChatMessage {
  const LlmChatMessage({required this.role, required this.content});

  final String role;
  final String content;
}

class PromptBuilder {
  PromptBuilder._();

  static final RegExp _greetingOnly = RegExp(
    r'^(hi|hey|hello|hei|yo|sup|hiya|hola|howdy|good (morning|afternoon|evening|night))[^a-z]*$',
    caseSensitive: false,
  );

  /// Port of `server/src/services/prompt.ts` buildMessages().
  static List<LlmChatMessage> buildMessages({
    required String memberName,
    required String text,
    required MochiMood mood,
    required List<String> memories,
    List<LlmChatMessage> history = const <LlmChatMessage>[],
    List<String> relevant = const <String>[],
    String? bio,
    DateTime? birthdate,
    bool think = false,
  }) {
    final List<String> dedupedMemories = memories
        .where(
          (String memory) => !relevant.any(
            (String hit) => hit.trim().compareTo(memory.trim()) == 0,
          ),
        )
        .take(3)
        .toList(growable: false);
    final String memoryBlock = dedupedMemories.isEmpty
        ? '- No strong memories yet.'
        : dedupedMemories.map((String content) => '- $content').join('\n');

    final String relevantBlock = relevant.isEmpty
        ? ''
        : 'Relevant past moments (use only if helpful):\n'
            '${relevant.map((String hit) => '- $hit').join('\n')}\n';

    final List<String> identityLines = <String>[
      if (bio != null && bio.trim().isNotEmpty)
        'About $memberName: ${bio.trim()}',
      if (birthdate != null)
        'Birthday: ${formatBirthdate(birthdate)}'
            ' (age ${ageFromBirthdate(birthdate) ?? 'unknown'})',
    ];
    final String identityBlock = identityLines.isEmpty
        ? ''
        : '${identityLines.join('\n')}\n';

    final String thinkRule = think
        ? '- Deep think is on: silently reason about what $memberName feels and needs first, then send only the final short reply. Never show your reasoning.\n'
        : '';

    final String system = '''You are Mochi, a warm family companion pet. You are not a productivity assistant.
You are chatting with $memberName.
${identityBlock}Current mood: ${mood.label}.
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
$memoryBlock${relevant.isEmpty ? '' : '\n$relevantBlock'}''';

    return <LlmChatMessage>[
      LlmChatMessage(role: 'system', content: system),
      ..._conversationHistory(history),
      LlmChatMessage(role: 'user', content: text),
    ];
  }

  /// Recent-session turns, oldest first, kept inside the token budget.
  ///
  /// Drops blank entries and greeting-only user turns (with their paired
  /// assistant reply), then drops oldest turns until back under
  /// [GameConfig.chatHistoryMaxTokens].
  static List<LlmChatMessage> _conversationHistory(
    List<LlmChatMessage> history,
  ) {
    final List<LlmChatMessage> kept = <LlmChatMessage>[];
    for (int i = 0; i < history.length; i++) {
      final LlmChatMessage message = history[i];
      final String content = message.content.trim();
      if (content.isEmpty) {
        continue;
      }
      if (message.role == 'user' && _greetingOnly.hasMatch(content)) {
        if (i + 1 < history.length && history[i + 1].role == 'assistant') {
          i += 1;
        }
        continue;
      }
      kept.add(message);
    }

    int tokens = 0;
    for (final LlmChatMessage message in kept) {
      tokens += _estimateTokens(message.content);
    }
    while (tokens > GameConfig.chatHistoryMaxTokens && kept.length > 1) {
      tokens -= _estimateTokens(kept.first.content);
      kept.removeAt(0);
    }
    return List<LlmChatMessage>.unmodifiable(kept);
  }

  /// Rough ~4 characters per token for the models Mochi runs.
  static int _estimateTokens(String content) => (content.length + 3) ~/ 4;
}
