/// Slim port of `server/src/services/llama.ts` cleanReply().
class ReplySanitizer {
  ReplySanitizer._();

  static String clean(String raw, {String? userText}) {
    // Models sometimes leak a reasoning block even when told not to.
    final String noThink = raw
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .replaceFirst(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '');

    final String debranded = noThink.replaceFirst(
      RegExp(
        r"^\s*mochi[\s']*(response|says|replied)?:\s*",
        caseSensitive: false,
      ),
      '',
    );

    final String firstTurn = debranded
        .split(
          RegExp(
            r'<\|user\|>|<\|system\|>|</s>|<\|end\|>|\bUser:|\bHuman:|\bAssistant:|\bMochi\s+response:|\bMochi\s+says:',
            caseSensitive: false,
          ),
        )
        .first;

    String compact = firstTurn
        .replaceAll(RegExp(r'<\|assistant\|>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (userText != null && userText.isNotEmpty) {
      final String escaped = RegExp.escape(userText);
      compact = compact
          .replaceFirst(RegExp('^$escaped\\s*', caseSensitive: false), '')
          .trim();
    }

    if (compact.isEmpty || !RegExp('[a-z0-9]', caseSensitive: false).hasMatch(compact)) {
      return '';
    }

    if (compact.length <= 200) {
      return compact;
    }

    final String slice = compact.substring(0, 200);
    final int boundary =
        slice.lastIndexOf('.') >= slice.lastIndexOf('!')
        ? (slice.lastIndexOf('?') >= slice.lastIndexOf('.')
            ? slice.lastIndexOf('?')
            : slice.lastIndexOf('.'))
        : (slice.lastIndexOf('?') >= slice.lastIndexOf('!')
            ? slice.lastIndexOf('?')
            : slice.lastIndexOf('!'));

    if (boundary >= 40) {
      return slice.substring(0, boundary + 1).trim();
    }

    return '${slice.trimRight()}...';
  }
}
