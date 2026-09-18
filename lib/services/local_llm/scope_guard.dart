import 'dart:math';

/// Deterministic scope filter: Mochi is a pet, not an assistant.
///
/// Out-of-scope requests (math, code, science, homework, trivia, how-tos)
/// are deflected with a canned pet reply before the model is ever invoked.
class ScopeGuard {
  ScopeGuard._();

  static final Random _random = Random();

  static const List<String> deflections = <String>[
    "Hmm, numbers make my ears wiggle! I'm much better at feelings — tell me how your day is going?",
    "That smells like homework! My paws are too small for that one. Want to talk about your day instead?",
    "I'm just a little pet — that question is beyond my paws! Tell me something fun that happened today?",
    "Ooh, that's a big-brain question! I'd rather hear about you. What made you smile lately?",
    "Not a calculator, just a cozy pet! How about we trade stories instead?",
  ];

  static String deflection() =>
      deflections[_random.nextInt(deflections.length)];

  /// Pet-safe "how ..." phrasings that must never count as how-to requests.
  static final RegExp _petSafeHow = RegExp(
    r'\bhow (are you|about you|do you feel|do you like|do you see|do you hear|do you remember|do you know me|do you sleep|do you do all day|does it feel|does your|is your day|was your day)\b',
  );

  /// Request-shaped how-to phrasings.
  static final List<RegExp> _howTo = <RegExp>[
    RegExp(r'\bhow (to|do i|do you|can i|does)\b'),
  ];

  /// Always out of scope, regardless of phrasing.
  static final List<RegExp> _always = <RegExp>[
    // Bare arithmetic: "what's 1 + 3?", "15 * 2"
    RegExp(r'\d\s*[+\-*/×÷]\s*\d'),
    RegExp(
      r'\b(one|two|three|four|five|six|seven|eight|nine|ten)\s+(plus|minus|times)\s+\w+',
    ),
    // Math terms and verbs
    RegExp(
      r'\b(calculat\w+|comput(e|es|ed|ing|ation)|equation|algebra|calculus|geometry|trigonometry|derivative|integral|theorem|square root|prime number|arithmetic)\b',
    ),
    RegExp(r'\d+\s*%\s*of\b'),
    // Code requests: verb ... noun within a short span
    RegExp(
      r'\b(write|fix|build|create|make|implement|generate|explain|refactor|optimize|debug|give|show)\b[\s\S]{0,40}?\b(program|function|method|script|code|snippet|algorithm|api|query|regex|database|server|website|app|unit tests?|hello world)\b',
    ),
    RegExp(
      r'\b(dart|python|javascript|typescript|java|kotlin|swift|ruby|php|rust|sql|html|css|json|yaml|xml|git|flutter|react|vue|angular|node|docker)\b',
    ),
    // Symbol-suffixed languages: \b can't follow + or #, so no trailing boundary
    RegExp(r'\b(c\+\+|c#|objective-c)'),
    // Classic code-request marker; safe to treat as always code talk
    RegExp(r'\bhello world\b'),
    RegExp(r'\b(compile|deploy|stack trace|syntax error|code review)\b'),
    // Science
    RegExp(
      r'\b(physics|chemistry|biology|quantum|molecule|photosynthesis|gravity|thermodynamics|electron|neutron|proton|periodic table|relativity|mitochondria)\b',
    ),
    // Anatomy/body trivia: key on framing, never bare words ("my heart feels
    // heavy" is pet talk, "main organ of the body" is trivia)
    RegExp(
      r'\b(main|largest|biggest|smallest|longest|strongest|fastest)\s+(organ|muscle|bone|artery|vein|nerve|planet|animal|mammal)\b',
    ),
    RegExp(r'\bwhat is the (main|largest|biggest|smallest|longest|strongest|fastest)\b'),
    RegExp(r'\bwhich (organ|muscle|bone|artery|vein|nerve|planet|element|gas|acid)\b'),
    RegExp(r'\bfunction of (the|a|an|your)\b'),
    RegExp(r'\bhow (does|do) (the|a|an)\b'),
    RegExp(r'\borgans? of the (body|human)\b'),
    // Homework-shaped requests (sharing school news stays allowed)
    RegExp(
      r'\b(help me (with|on)|do my|check my|solve)\b[\s\S]{0,30}?\b(homework|assignment|essay|thesis|dissertation|exercise|equation|system)\b',
    ),
    RegExp(r'\bwrite (my |an |a )?(essay|thesis|dissertation)\b'),
    // Factual trivia
    RegExp(
      r'\b(capital of|who (invented|discovered|wrote|painted)|population of|definition of|translate|synonym|antonym)\b',
    ),
    RegExp(r'(?:^|[.!?]\s*)define\b'),
  ];

  static bool isOutOfScope(String text) {
    final String t = text.trim().toLowerCase();
    if (t.isEmpty) {
      return false;
    }
    if (t.contains('```')) {
      return true;
    }
    for (final RegExp pattern in _always) {
      if (pattern.hasMatch(t)) {
        return true;
      }
    }
    if (_petSafeHow.hasMatch(t)) {
      return false;
    }
    for (final RegExp pattern in _howTo) {
      if (pattern.hasMatch(t)) {
        return true;
      }
    }
    return false;
  }
}
