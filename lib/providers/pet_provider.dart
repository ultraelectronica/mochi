import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/game_config.dart';
import '../db/mochi_db.dart';
import '../db/mochi_repository.dart';
import '../games/mini_game.dart';
import '../models/chat_session.dart';
import '../models/food.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../services/local_llm/llm_service.dart';
import '../services/local_llm/local_models.dart';
import '../services/local_llm/model_manager.dart';
import '../services/local_llm/prompt_builder.dart';
import '../services/local_llm/scope_guard.dart';
import '../services/tts_service.dart';

class PetProvider extends ChangeNotifier {
  PetProvider({TtsService? ttsService}) : _ttsService = ttsService ?? TtsService();

  final TtsService _ttsService;

  late MochiRepository _repo;

  Pet? _pet;
  Member? _profile;
  List<ChatEntry> _chatEntries = <ChatEntry>[];
  List<ChatSession> _sessions = <ChatSession>[];
  int? _activeSessionId;
  List<ActivityEntry> _feedEntries = <ActivityEntry>[];
  List<MemorySnippet> _memories = <MemorySnippet>[];
  Map<int, MochiMood> _memberCheckIns = <int, MochiMood>{};

  bool _llamaOnline = false;
  bool _ttsEnabled = true;
  bool _thinkEnabled = false;
  bool _notificationsEnabled = true;
  bool _replyPending = false;
  bool _isLoading = true;
  String? _errorMessage;

  static const String _ttsPrefKey = 'mochi_tts_enabled';
  static const String _thinkPrefKey = 'mochi_think_enabled';

  Pet get pet => _pet!;
  Member get profile => _profile!;
  List<ChatEntry> get chatEntries => List<ChatEntry>.unmodifiable(_chatEntries);
  List<ChatSession> get sessions => List<ChatSession>.unmodifiable(_sessions);
  int? get activeSessionId => _activeSessionId;
  bool get isActiveSessionNew => _activeSessionId == null;
  List<ActivityEntry> get feedEntries =>
      List<ActivityEntry>.unmodifiable(_feedEntries);
  List<MemorySnippet> get memories =>
      List<MemorySnippet>.unmodifiable(_memories);
  Map<int, MochiMood> get memberCheckIns =>
      Map<int, MochiMood>.unmodifiable(_memberCheckIns);
  bool get serverOnline => _pet != null;
  bool get llamaOnline => _llamaOnline;
  bool get ttsEnabled => _ttsEnabled;
  bool get thinkEnabled => _thinkEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get replyPending => _replyPending;
  bool get isLoading => _isLoading;
  bool get hasPet => _pet != null;
  String? get errorMessage => _errorMessage;

  MochiMood? moodForMember(int memberId) => _memberCheckIns[memberId];

  String greetingFor(String memberName) => switch (pet.mood) {
    MochiMood.happy => 'Hi $memberName. I kept the room bright for you.',
    MochiMood.laughing =>
      'Hi $memberName. I am wiggly today and ready to play.',
    MochiMood.normal => 'Hi $memberName. Tell me the small thing on your mind.',
    MochiMood.tired =>
      'Hi $memberName. Quiet company sounds perfect right now.',
    MochiMood.sad => 'Hi $memberName. Stay near me for a minute.',
    MochiMood.angry =>
      'Hi $memberName. I need a soft reset, but I am still here.',
    MochiMood.scared => 'Hi $memberName. A gentle hello helps a lot.',
    MochiMood.hungry => 'Hi $memberName. I am collecting snack stories today.',
    MochiMood.confused =>
      'Hi $memberName. I am curious and still figuring things out.',
  };

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    _activeSessionId = null;
    _chatEntries = <ChatEntry>[];
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _ttsEnabled = prefs.getBool(_ttsPrefKey) ?? true;
      _thinkEnabled = prefs.getBool(_thinkPrefKey) ?? false;
      notifyListeners();
    } catch (_) {}

    try {
      final MochiDb db = await MochiDb.instance();
      _repo = MochiRepository(db);
      _repo.pruneStaleMemories();
      await _reloadLocal();
      unawaited(_warmModel());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _warmModel() async {
    try {
      final bool installed =
          await ModelManager.instance.selectedInstalled();
      if (!installed) {
        return;
      }
      await LlmService.instance.ensureLoaded(ModelManager.instance.selected);
      _llamaOnline = LlmService.instance.isReady;
      notifyListeners();
    } catch (error) {
      debugPrint('[PetProvider] model warm-up failed: $error');
      _llamaOnline = false;
      notifyListeners();
    }
  }

  /// Local state refresh — cheap DB re-reads, no network.
  Future<void> refreshState({
    bool includeHealth = true,
    bool includeChat = true,
    bool force = false,
  }) async {
    unawaited(_reloadLocal(includeChat: includeChat));
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _reloadLocal({bool includeChat = true}) async {
    _pet = _repo.getPet();
    _profile = _repo.getProfile();
    _memories = _repo.listMemories();
    _feedEntries = _repo.feed();
    _memberCheckIns = _repo.todayMoodMap();

    if (includeChat) {
      if (_activeSessionId != null) {
        _chatEntries = _repo.chatHistory(sessionId: _activeSessionId!);
      }
      _sessions = _repo.listSessions();
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> connectRealtime() async {}

  Future<void> reconnectRealtime() async {}

  /// Called on app resume: recompute mood (inactivity decay), prune stale
  /// memories, and re-sync everything from the local DB.
  Future<void> brushUp() async {
    try {
      _repo.pruneStaleMemories();
      _repo.recalculateMood();
      await _reloadLocal();
      _llamaOnline = LlmService.instance.isReady;
      notifyListeners();
    } catch (error) {
      debugPrint('[PetProvider] brushUp failed: $error');
    }
  }

  Future<void> sendMessage({
    required Member member,
    required String text,
    String inputType = 'text',
  }) async {
    final ChatEntry optimistic = ChatEntry.local(
      author: member.name,
      text: text,
      isPet: false,
    );

    _chatEntries = <ChatEntry>[..._chatEntries, optimistic];
    _replyPending = true;
    _errorMessage = null;
    notifyListeners();

    final ChatEntry streamEntry = ChatEntry.local(
      author: 'Mochi',
      text: '',
      isPet: true,
    );
    _chatEntries = <ChatEntry>[..._chatEntries, streamEntry];
    notifyListeners();

    try {
      if (ScopeGuard.isOutOfScope(text)) {
        await _commitReply(
          member: member,
          text: text,
          reply: ScopeGuard.deflection(),
          inputType: inputType,
          reward: false,
        );
        return;
      }

      LocalModel model = ModelManager.instance.selected;
      if (!await ModelManager.instance.isInstalled(model)) {
        throw const _LocalModelMissingException();
      }

      if (!LlmService.instance.isReady) {
        await LlmService.instance.ensureLoaded(model);
      }
      _llamaOnline = LlmService.instance.isReady;
      notifyListeners();

      final Pet pet = _repo.getPet()!;
      final List<String> memoryContents = _repo.memoriesForPrompt();
      final List<String> relevant = _repo.retrieveRelevantMemories(
        text,
        k: GameConfig.memoryRetrievalLimit,
      );
      final int? chatSessionId = _activeSessionId;
      final List<LlmChatMessage> history = chatSessionId == null
          ? const <LlmChatMessage>[]
          : <LlmChatMessage>[
              for (final ChatEntry entry in _repo.chatHistory(
                sessionId: chatSessionId,
                limit: GameConfig.chatHistoryLimit,
              ))
                LlmChatMessage(
                  role: entry.isPet ? 'assistant' : 'user',
                  content: entry.text,
                ),
            ];
      final List<LlmChatMessage> messages = PromptBuilder.buildMessages(
        memberName: member.name,
        text: text,
        mood: pet.mood,
        memories: memoryContents,
        history: history,
        relevant: relevant,
        bio: member.bio,
        birthdate: member.birthdate,
        hungerLine: _hungerLineFor(pet),
        think: _thinkEnabled,
      );

      String reply = '';
      void streamToken(String token) {
        reply += token;
        if (_chatEntries.isNotEmpty) {
          _chatEntries = <ChatEntry>[
            ..._chatEntries.sublist(0, _chatEntries.length - 1),
            ChatEntry(
              id: null,
              author: 'Mochi',
              text: reply,
              isPet: true,
              timestamp: streamEntry.timestamp,
              createdAt: streamEntry.createdAt,
            ),
          ];
          notifyListeners();
        }
      }

      final String? rawReply = await LlmService.instance.reply(
        messages: messages,
        userText: text,
        think: _thinkEnabled,
        onToken: streamToken,
      );
      reply = rawReply ?? pet.mood.reaction;

      await _commitReply(
        member: member,
        text: text,
        reply: reply,
        inputType: inputType,
      );
    } on _LocalModelMissingException {
      if (_chatEntries.isNotEmpty) {
        _chatEntries = _chatEntries.sublist(0, _chatEntries.length - 1);
      }
      _errorMessage =
          "Mochi's brain is not downloaded. Open Settings to add it.";
    } catch (error) {
      _chatEntries = <ChatEntry>[
        for (final ChatEntry entry in _chatEntries)
          if (entry != optimistic && !identical(entry, streamEntry)) entry,
      ];
      _applyError(error);
      rethrow;
    } finally {
      _replyPending = false;
      notifyListeners();
    }
  }

  /// Persists a finished Mochi reply: session, interaction log, mood, and UI.
  /// Deflected turns pass [reward] as false — logged, but no XP and no
  /// auto-memory, so out-of-scope questions can't feed the pet.
  Future<void> _commitReply({
    required Member member,
    required String text,
    required String reply,
    required String inputType,
    bool reward = true,
  }) async {
    final int sessionId =
        _repo.resolveSession(memberId: member.id, requestedSessionId: _activeSessionId);
    final int xpAwarded = reward
        ? _repo.awardXp(memberId: member.id, amount: GameConfig.xpPerChat)
        : 0;

    _repo.insertInteraction(
      memberId: member.id,
      sessionId: sessionId,
      inputText: text,
      responseText: reply,
      inputType: inputType,
      xpAwarded: xpAwarded,
    );
    _repo.deriveSessionTitle(sessionId, text);
    _repo.touchSession(sessionId);
    if (reward && _shouldRemember(text)) {
      _repo.upsertMemory(memberId: member.id, content: text);
    }
    _repo.checkStagePromotion();
    _repo.recalculateMood();

    _activeSessionId = sessionId;
    if (_chatEntries.isNotEmpty) {
      _chatEntries = _chatEntries.sublist(0, _chatEntries.length - 1);
    }
    _chatEntries = <ChatEntry>[
      ..._chatEntries,
      ChatEntry.local(author: 'Mochi', text: reply, isPet: true),
    ];
    _errorMessage = null;
    await _reloadLocal();
    if (_ttsEnabled && reply.isNotEmpty) {
      unawaited(_ttsService.speak(reply));
    }
  }

  void startNewSession() {
    _activeSessionId = null;
    _chatEntries = <ChatEntry>[];
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> selectSession(int sessionId) async {
    if (_activeSessionId == sessionId) {
      return;
    }
    _activeSessionId = sessionId;
    _chatEntries = <ChatEntry>[];
    _errorMessage = null;
    notifyListeners();
    _chatEntries = _repo.chatHistory(sessionId: sessionId);
    notifyListeners();
  }

  Future<void> deleteSession(int sessionId) async {
    _repo.deleteSession(sessionId);
    _sessions = _repo.listSessions();
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
      _chatEntries = <ChatEntry>[];
    }
    notifyListeners();
  }

  Future<void> loadSessions() async {
    _sessions = _repo.listSessions();
    notifyListeners();
  }

  Future<bool> checkIn({
    required Member member,
    required MochiMood mood,
  }) async {
    if (_repo.memberCheckedInToday(member.id)) {
      return false;
    }
    _repo.recordMoodCheckIn(memberId: member.id, mood: mood.name);
    _repo.awardXp(memberId: member.id, amount: GameConfig.xpPerCheckin);
    _repo.checkStagePromotion();
    _repo.recalculateMood();
    await _reloadLocal(includeChat: false);
    return true;
  }

  int tapCooldownRemaining(int memberId) {
    return _repo.tapCooldownRemainingSeconds(memberId: memberId);
  }

  Future<int> tapPet(Member member) async {
    final int xpAwarded = _repo.tapPet(memberId: member.id);
    await _reloadLocal(includeChat: false);
    return xpAwarded;
  }

  int feedCooldownRemaining(int memberId) {
    return _repo.feedCooldownRemainingSeconds(memberId: memberId);
  }

  Future<FeedResult> feed(Food food) async {
    final FeedResult result = _repo.feedPet(memberId: _profile!.id, food: food);
    await _reloadLocal(includeChat: false);
    return result;
  }

  int miniGameCooldownRemaining() {
    return _repo.miniGameCooldownRemainingSeconds(memberId: _profile!.id);
  }

  int dailyMiniGamePlays() {
    return _repo.dailyMiniGamePlays(memberId: _profile!.id);
  }

  Map<MiniGame, int> miniGameBestScores() {
    return _repo.miniGameBestScores(memberId: _profile!.id);
  }

  Future<MiniGameResult> playMiniGame({
    required MiniGame game,
    int score = 0,
    int bestCombo = 0,
    int moves = 0,
    bool finished = true,
  }) async {
    final MiniGameResult result = _repo.recordMiniGamePlay(
      memberId: _profile!.id,
      game: game,
      score: score,
      bestCombo: bestCombo,
      moves: moves,
      finished: finished,
    );
    await _reloadLocal(includeChat: false);
    return result;
  }

  /// Prompt line describing current hunger and the last meal, so Mochi can
  /// talk about food naturally.
  String _hungerLineFor(Pet pet) {
    final ({Food food, DateTime createdAt})? last = _repo.lastMeal();
    final String lastPart = last == null
        ? ''
        : ' Last meal: ${last.food.label} ${_relativeShort(last.createdAt)} ago.';
    return 'Hunger: ${pet.hungerLabel}.$lastPart';
  }

  static String _relativeShort(DateTime value) {
    final Duration delta = DateTime.now().difference(value);
    if (delta.inMinutes < 1) {
      return 'just now';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes}m';
    }
    if (delta.inHours < 48) {
      return '${delta.inHours}h';
    }
    return '${delta.inDays}d';
  }

  Future<void> addMemory({required String content, int weight = 1}) async {
    _repo.addMemory(memberId: _profile!.id, content: content, weight: weight);
    await _reloadLocal(includeChat: false);
  }

  Future<void> updateMemory({
    required int id,
    String? content,
    int? weight,
  }) async {
    _repo.updateMemory(id: id, content: content, weight: weight);
    await _reloadLocal(includeChat: false);
  }

  Future<void> removeMemory(int id) async {
    _repo.deleteMemory(id);
    _memories = _repo.listMemories();
    notifyListeners();
  }

  Future<void> clearSession() async {
    _pet = null;
    _profile = null;
    _chatEntries = <ChatEntry>[];
    _sessions = <ChatSession>[];
    _activeSessionId = null;
    _feedEntries = <ActivityEntry>[];
    _memories = <MemorySnippet>[];
    _memberCheckIns = <int, MochiMood>{};
    _replyPending = false;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  void setTtsEnabled(bool value) {
    if (_ttsEnabled == value) {
      return;
    }
    _ttsEnabled = value;
    if (!value) {
      unawaited(_ttsService.stop());
    }
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_ttsPrefKey, value);
    });
  }

  void setThinkEnabled(bool value) {
    if (_thinkEnabled == value) {
      return;
    }
    _thinkEnabled = value;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_thinkPrefKey, value);
    });
  }

  void setNotificationsEnabled(bool value) {
    if (_notificationsEnabled == value) {
      return;
    }
    _notificationsEnabled = value;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void _applyError(Object error) {
    _errorMessage = 'Failed to save this conversation on this device';
    debugPrint('[PetProvider] $error');
  }

  /// Noise filter for auto-memories: only save messages that are substantial
  /// AND about the user (personal-signal heuristic) so memory storage stays
  /// high-signal.
  bool _shouldRemember(String text) {
    final String trimmed = text.trim();
    if (trimmed.length <= GameConfig.memoryUpsertMinLength) {
      return false;
    }
    return _personalSignal.hasMatch(trimmed);
  }

  static final RegExp _personalSignal = RegExp(
    r"\b(i|i'm|i am|my|me|mine)\b",
    caseSensitive: false,
  );

  @override
  void dispose() {
    unawaited(_ttsService.dispose());
    super.dispose();
  }
}

class _LocalModelMissingException implements Exception {
  const _LocalModelMissingException();
}
