import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/services/local_llm/scope_guard.dart';

void main() {
  group('ScopeGuard.isOutOfScope', () {
    test('deflects arithmetic and math requests', () {
      const List<String> inputs = <String>[
        "What's 1 + 3?",
        'what is 1+3',
        'calculate 15% of 80',
        'five plus two?',
        'Give me an example of a linear algebra computation',
        'solve this equation for x',
        'what is the square root of 144',
      ];
      for (final String input in inputs) {
        expect(ScopeGuard.isOutOfScope(input), isTrue, reason: input);
      }
    });

    test('deflects code and technical requests', () {
      const List<String> inputs = <String>[
        'Write a Dart program',
        'write me a python function that reverses a string',
        'can you fix this javascript snippet for me',
        'how do I set up docker',
        'explain this sql query',
        'review my flutter app code',
        'what is react',
        'debug this for me please ```void main() {}```',
        'write a program that sorts numbers',
        'Can you write a hello world on C++?',
        'write hello world in c#',
        'what is c++',
        'hello world program in c',
        'give me a hello world function',
      ];
      for (final String input in inputs) {
        expect(ScopeGuard.isOutOfScope(input), isTrue, reason: input);
      }
    });

    test('deflects science, homework, trivia, and how-tos', () {
      const List<String> inputs = <String>[
        'explain quantum physics',
        'how does photosynthesis work',
        'help me with my homework',
        'do my assignment for me',
        'write an essay about the industrial revolution',
        "what's the capital of France",
        'who invented the telephone',
        'translate this to spanish',
        'how to make bread',
        'how do I tie a tie',
        'define photosynthesis',
      ];
      for (final String input in inputs) {
        expect(ScopeGuard.isOutOfScope(input), isTrue, reason: input);
      }
    });

    test('allows pet chat: greetings, feelings, identity, memories', () {
      const List<String> inputs = <String>[
        'hello!',
        'who am I?',
        'how are you?',
        'how do you feel today?',
        'how was your day?',
        'i had a rough day at work',
        "i'm feeling a bit sad",
        'do you remember when we talked about my garden?',
        "what's your favorite snack?",
        'how about you?',
        'i love you 100%',
        'i finished my math class project today!',
        'tell me a story',
        'can you cheer me up?',
      ];
      for (final String input in inputs) {
        expect(ScopeGuard.isOutOfScope(input), isFalse, reason: input);
      }
    });

    test('deflects anatomy and body trivia but not health feelings', () {
      const List<String> blocked = <String>[
        'What is the main organ of the body?',
        'how does the heart work',
        'what is the largest bone in the body',
        'what is the function of the liver',
        'which organ filters blood',
        'how do the kidneys work',
        'what is the smallest bone',
      ];
      for (final String input in blocked) {
        expect(ScopeGuard.isOutOfScope(input), isTrue, reason: input);
      }

      const List<String> allowed = <String>[
        'my heart feels heavy today',
        'my heart is racing',
        'i think i pulled a muscle',
        'how does it feel to be loved?',
      ];
      for (final String input in allowed) {
        expect(ScopeGuard.isOutOfScope(input), isFalse, reason: input);
      }
    });

    test('empty text is never out of scope', () {
      expect(ScopeGuard.isOutOfScope(''), isFalse);
      expect(ScopeGuard.isOutOfScope('   '), isFalse);
    });
  });

  group('ScopeGuard.deflection', () {
    test('returns a non-empty short pet-voice reply', () {
      for (int i = 0; i < 10; i++) {
        final String reply = ScopeGuard.deflection();
        expect(reply, isNotEmpty);
        expect(reply.length, lessThanOrEqualTo(200));
      }
    });

    test('every canned variant obeys the reply contract', () {
      for (final String line in ScopeGuard.deflections) {
        expect(line, isNotEmpty);
        expect(line.length, lessThanOrEqualTo(200));
      }
    });
  });
}
