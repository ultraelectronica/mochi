import 'package:flutter_test/flutter_test.dart';
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
