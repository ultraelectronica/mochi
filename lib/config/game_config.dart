/// Game constants that used to live in `server/src/config/index.ts`.
class GameConfig {
  GameConfig._();

  static const int xpPerChat = 10;
  static const int xpPerCheckin = 5;
  static const int xpPerTap = 2;
  static const int tapCooldownSeconds = 10;
  static const double moodDecayHours = 12;

  static const int maxMemoriesPerMember = 12;
  static const int memoryPruneDays = 30;
  static const int maxBioLength = 500;

  static const int memoryRetrievalLimit = 3;
  static const int memoryUpsertMinLength = 12;

  static const int chatHistoryLimit = 8;
  static const int chatHistoryMaxTokens = 900;

  static const int defaultContextSize = 2048;
  static const int maxReplyTokens = 100;
  static const int thinkMaxReplyTokens = 320;
  static const double temperature = 0.75;
}

const List<String> validMoodKeys = <String>[
  'happy',
  'sad',
  'angry',
  'normal',
  'tired',
  'confused',
  'laughing',
  'hungry',
  'scared',
];
