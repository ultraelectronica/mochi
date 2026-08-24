import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/config/game_config.dart';
import 'package:mochi/models/member.dart';
import 'package:mochi/models/mood.dart';
import 'package:mochi/services/local_llm/prompt_builder.dart';
import 'package:mochi/services/local_llm/reply_sanitizer.dart';

void main() {
  group('PromptBuilder', () {
    test('builds system and user messages', () {
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.happy,
        memories: <String>['Sam loves rainy days'],
      );

      expect(messages, hasLength(2));
      expect(messages[0].role, 'system');
      expect(messages[1].role, 'user');
      expect(messages[1].content, 'hi');
    });

    test('system prompt includes member, mood, memories, and rules', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.scared,
        memories: <String>['First birthday together'],
      ).first.content;

      expect(system, contains('chatting with Sam'));
      expect(system, contains('Current mood: Scared'));
      expect(system, contains('First birthday together'));
      expect(system, contains('Never exceed 200 characters'));
      expect(system, contains('Never prefix your reply'));
    });

    test('empty memories produce the fallback block', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
      ).first.content;

      expect(system, contains('No strong memories yet'));
    });

    test('only the top-3 memories are used', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>['one', 'two', 'three', 'four'],
      ).first.content;

      expect(system, contains('- one'));
      expect(system, contains('- two'));
      expect(system, contains('- three'));
      expect(system, isNot(contains('- four')));
    });

    test('think mode adds the reasoning directive', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
        think: true,
      ).first.content;

      expect(system, contains('silently reason'));
      expect(system, contains('Never show your reasoning'));
    });

    test('think mode is off by default', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
      ).first.content;

      expect(system, isNot(contains('Deep think')));
    });

    test('system prompt includes bio when present', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
        bio: 'Loves jazz and rainy days',
      ).first.content;

      expect(system, contains('About Sam: Loves jazz and rainy days'));
    });

    test('system prompt includes birthdate and computed age', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
        birthdate: DateTime(2000, 5, 15),
      ).first.content;

      final int? expectedAge = ageFromBirthdate(DateTime(2000, 5, 15));
      expect(system, contains('Birthday: 2000-05-15'));
      expect(system, contains('(age $expectedAge)'));
    });

    test('identity block omitted when bio and birthdate are empty', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
      ).first.content;

      expect(system, isNot(contains('About Sam:')));
      expect(system, isNot(contains('Birthday:')));
    });
  });

  group('PromptBuilder conversation history', () {
    test('history is serialized as user/assistant before the current turn', () {
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'and then?',
        mood: MochiMood.normal,
        memories: <String>[],
        history: const <LlmChatMessage>[
          LlmChatMessage(role: 'user', content: 'tell me a story'),
          LlmChatMessage(role: 'assistant', content: 'The sky was blue.'),
        ],
      );

      expect(messages, hasLength(4));
      expect(messages[0].role, 'system');
      expect(messages[1].role, 'user');
      expect(messages[1].content, 'tell me a story');
      expect(messages[2].role, 'assistant');
      expect(messages[2].content, 'The sky was blue.');
      expect(messages[3].role, 'user');
      expect(messages[3].content, 'and then?');
    });

    test('skips blank and greeting-only history entries with their reply', () {
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'tell me more',
        mood: MochiMood.normal,
        memories: <String>[],
        history: const <LlmChatMessage>[
          LlmChatMessage(role: 'user', content: '   '),
          LlmChatMessage(role: 'user', content: 'hi'),
          LlmChatMessage(role: 'assistant', content: 'Hi Sam!'),
          LlmChatMessage(role: 'user', content: 'Hi there, I got a new dog'),
          LlmChatMessage(role: 'assistant', content: 'Ooh, a new dog!'),
        ],
      );

      expect(messages, hasLength(4));
      expect(messages[1].content, 'Hi there, I got a new dog');
      expect(messages[2].content, 'Ooh, a new dog!');
    });

    test('overflow truncates oldest first and keeps the newest turns', () {
      final List<LlmChatMessage> history = <LlmChatMessage>[
        for (int i = 0; i < 14; i++) ...<LlmChatMessage>[
          LlmChatMessage(role: 'user', content: 'turn $i ${'a' * 200}'),
          LlmChatMessage(role: 'assistant', content: 'reply $i ${'b' * 200}'),
        ],
      ];
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'x',
        mood: MochiMood.normal,
        memories: <String>[],
        history: history,
      );

      int estimated = 0;
      for (final LlmChatMessage message
          in messages.sublist(1, messages.length - 1)) {
        estimated += (message.content.length + 3) ~/ 4;
      }
      expect(estimated, lessThanOrEqualTo(GameConfig.chatHistoryMaxTokens));
      expect(messages[1].content, isNot(contains('turn 0')));
      expect(messages[messages.length - 2].content, contains('reply 13'));
    });

    test('history defaults to empty, keeping the classic two-message shape',
        () {
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
      );

      expect(messages, hasLength(2));
      expect(messages[1].role, 'user');
      expect(messages[1].content, 'hi');
    });
  });

  group('PromptBuilder relevant recall', () {
    test('relevant past moments block is inserted when hits exist', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'do you remember the rain?',
        mood: MochiMood.normal,
        memories: <String>[],
        relevant: const <String>['Rainy days are cozy.'],
      ).first.content;

      expect(system, contains('Relevant past moments (use only if helpful):'));
      expect(system, contains('- Rainy days are cozy.'));
    });

    test('block is omitted when there are no hits', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'hi',
        mood: MochiMood.normal,
        memories: <String>[],
      ).first.content;

      expect(system, isNot(contains('Relevant past moments')));
    });

    test('dedups retrieved content from the general memory block', () {
      final String system = PromptBuilder.buildMessages(
        memberName: 'Sam',
        text: 'tell me more',
        mood: MochiMood.normal,
        memories: const <String>['Sam loves rainy days'],
        relevant: const <String>['Sam loves rainy days'],
      ).first.content;

      final int memoryBlockCount = RegExp('- Sam loves rainy days')
          .allMatches(system)
          .length;
      expect(memoryBlockCount, 1);
      expect(system, contains('Relevant past moments (use only if helpful):'));
    });
  });

  group('ReplySanitizer', () {
    test('keeps a clean reply untouched', () {
      expect(ReplySanitizer.clean('I am right here. Tell me everything.'), 'I am right here. Tell me everything.');
    });

    test('cuts at the first hallucinated turn', () {
      const String raw =
          'A warm hello!\n<|user|>what did I say?';
      expect(
        ReplySanitizer.clean(raw),
        'A warm hello!',
      );
    });

    test('strips a Mochi: prefix', () {
      expect(
        ReplySanitizer.clean('Mochi: I snuggle the sky.'),
        'I snuggle the sky.',
      );
    });

    test('strips an echoed user line', () {
      expect(
        ReplySanitizer.clean('I love rainy days I love rainy days', userText: 'I love rainy days'),
        'I love rainy days',
      );
    });

    test('returns empty for token-only text', () {
      expect(ReplySanitizer.clean('</s>'), '');
    });

    test('strips a completed think block', () {
      expect(
        ReplySanitizer.clean(
          '<think>Sam seems tired, keep it soft</think>Stay near me tonight.',
        ),
        'Stay near me tonight.',
      );
    });

    test('strips an unterminated think block', () {
      expect(ReplySanitizer.clean('<think>pondering the mood'), '');
    });

    test('truncates long replies at a sentence boundary', () {
      final String long = '${List<String>.generate(
        40,
        (int i) => 'word${i + 1}',
      ).join(' ')}!';
      final String result = ReplySanitizer.clean(long);

      expect(result.length, lessThanOrEqualTo(203));
    });

    test('truncates long replies with ellipsis, never a run-on', () {
      final String long = 'a' * 400;
      final String result = ReplySanitizer.clean(long);
      expect(result, endsWith('...'));
      expect(result.length, lessThanOrEqualTo(203));
    });

  });
}
