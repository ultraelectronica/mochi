/// Game constants that used to live in `server/src/config/index.ts`.
class GameConfig {
  GameConfig._();

  static const int xpPerChat = 10;
  static const int xpPerCheckin = 5;
  static const int xpPerTap = 2;
  static const int tapCooldownSeconds = 10;
  static const double moodDecayHours = 12;

  // Mini-games stay a side dish: below chat XP, capped per run and per day.
  static const int xpPerMiniGameMax = 8;
  static const int miniGameDailyCap = 5;
  static const int miniGameCooldownSeconds = 90;
  static const int snackCatchDurationSeconds = 60;
  static const int snackCatchLives = 3;
  static const int ticklePopDurationSeconds = 30;
  static const int moodMatchParMoves = 10;
  static const int moodMatchSeconds = 90;

  static const int satietyMax = 100;
  static const int satietyDefault = 70;
  static const double satietyDecayPerHour = 4;
  static const int hungrySatietyThreshold = 25;
  static const int fullSatietyThreshold = 90;

  // Feeding is stock-limited, not time-limited: items are earned from chats,
  // mini-games, and the daily check-in.
  static const int foodInventoryCap = 9;
  static const int chatFoodEveryN = 4;
  static const int chatFoodDailyCap = 3;
  static const int gameFoodDailyCap = 5;
  static const int checkInFoodDailyCap = 1;
  static const int starterMochiBites = 5;
  static const int starterOnigiri = 2;

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
