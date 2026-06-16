import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_session.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../services/websocket_service.dart';

class PetProvider extends ChangeNotifier {
  PetProvider({ApiService? apiService, WebSocketService? webSocketService, TtsService? ttsService})
    : _apiService = apiService ?? ApiService(),
      _webSocketService = webSocketService ?? WebSocketService(),
      _ttsService = ttsService ?? TtsService();

  final ApiService _apiService;
  final WebSocketService _webSocketService;
  final TtsService _ttsService;

  StreamSubscription<Map<String, dynamic>>? _webSocketSubscription;

  Future<void>? _activeRefresh;
  DateTime _lastRefreshedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const Duration _minRefreshInterval = Duration(seconds: 5);

  Pet? _pet;
  List<ChatEntry> _chatEntries = <ChatEntry>[];
  List<ChatSession> _sessions = <ChatSession>[];
  int? _activeSessionId;
  List<ActivityEntry> _feedEntries = <ActivityEntry>[];
  List<MemorySnippet> _memories = <MemorySnippet>[];
  Map<int, MochiMood> _memberCheckIns = <int, MochiMood>{};

  bool _serverOnline = false;
  bool _llamaOnline = false;
  bool _ttsEnabled = true;
  bool _notificationsEnabled = true;
  bool _replyPending = false;
  bool _isLoading = true;
  String? _errorMessage;

  static const String _ttsPrefKey = 'mochi_tts_enabled';

  Pet get pet => _pet!;
  List<ChatEntry> get chatEntries => List<ChatEntry>.unmodifiable(_chatEntries);
  List<ChatSession> get sessions =>
      List<ChatSession>.unmodifiable(_sessions);
  int? get activeSessionId => _activeSessionId;
  bool get isActiveSessionNew => _activeSessionId == null;
  List<ActivityEntry> get feedEntries =>
      List<ActivityEntry>.unmodifiable(_feedEntries);
  List<MemorySnippet> get memories =>
      List<MemorySnippet>.unmodifiable(_memories);
  Map<int, MochiMood> get memberCheckIns =>
      Map<int, MochiMood>.unmodifiable(_memberCheckIns);
  bool get serverOnline => _serverOnline;
  bool get llamaOnline => _llamaOnline;
  bool get ttsEnabled => _ttsEnabled;
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
      notifyListeners();
    } catch (_) {}

    try {
      await refreshState(includeHealth: true, includeChat: true);
      await connectRealtime();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectRealtime() async {
    await _webSocketSubscription?.cancel();
    await _webSocketService.connect();
    _webSocketSubscription = _webSocketService.events.listen((
      Map<String, dynamic> event,
    ) {
      unawaited(_handleRealtimeEvent(event));
    });
  }

  Future<void> reconnectRealtime() async {
    await connectRealtime();
  }

  Future<void> refreshState({
    bool includeHealth = true,
    bool includeChat = true,
    bool force = false,
  }) async {
    if (_activeRefresh != null) {
      return _activeRefresh!;
    }

    if (!force &&
        DateTime.now().difference(_lastRefreshedAt) < _minRefreshInterval) {
      return;
    }

    _activeRefresh = _doRefresh(
      includeHealth: includeHealth,
      includeChat: includeChat,
    );
    try {
      await _activeRefresh!;
    } finally {
      _activeRefresh = null;
      _lastRefreshedAt = DateTime.now();
    }
  }

  Future<void> _doRefresh({
    bool includeHealth = true,
    bool includeChat = true,
  }) async {
    try {
      if (includeHealth) {
        final ({bool serverOnline, bool llamaOnline}) health = await _apiService
            .fetchHealth();
        _serverOnline = health.serverOnline;
        _llamaOnline = health.llamaOnline;
      }

      final List<Future<Object>> requests = <Future<Object>>[
        _apiService.fetchPet(),
        _apiService.fetchMemories(),
        _apiService.fetchFeed(),
        _apiService.fetchTodayMoodMap(),
      ];

      if (includeChat) {
        requests.add(_apiService.fetchChatHistory(sessionId: _activeSessionId));
        requests.add(_apiService.fetchChatSessions());
      }

      final List<Object> results = await Future.wait<Object>(requests);

      _pet = results[0] as Pet;
      _memories = results[1] as List<MemorySnippet>;
      _feedEntries = results[2] as List<ActivityEntry>;
      _memberCheckIns = results[3] as Map<int, MochiMood>;
      if (includeChat) {
        _chatEntries = results[4] as List<ChatEntry>;
        _sessions = results[5] as List<ChatSession>;
      }
      _serverOnline = true;
      _errorMessage = null;
    } catch (error) {
      _applyError(error);
      rethrow;
    } finally {
      notifyListeners();
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

    try {
      final ({String reply, Pet pet, int? sessionId}) result =
          await _apiService.sendMessage(
        memberId: member.id,
        text: text,
        sessionId: _activeSessionId,
        inputType: inputType,
      );

      _pet = result.pet;
      if (result.sessionId != null) {
        _activeSessionId = result.sessionId;
      }
      _chatEntries = <ChatEntry>[
        ..._chatEntries,
        ChatEntry.local(author: 'Mochi', text: result.reply, isPet: true),
      ];
      _serverOnline = true;
      _errorMessage = null;

      if (_ttsEnabled && result.reply.isNotEmpty) {
        unawaited(_ttsService.speak(result.reply));
      }

      try {
        final List<Object> results = await Future.wait<Object>([
          _apiService.fetchChatHistory(sessionId: _activeSessionId),
          _apiService.fetchChatSessions(),
        ]);
        _chatEntries = results[0] as List<ChatEntry>;
        _sessions = results[1] as List<ChatSession>;
      } catch (_) {
        notifyListeners();
      }
    } catch (error) {
      _chatEntries = List<ChatEntry>.from(_chatEntries)..remove(optimistic);
      _applyError(error);
      rethrow;
    } finally {
      _replyPending = false;
      notifyListeners();
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

    try {
      _chatEntries = await _apiService.fetchChatHistory(sessionId: sessionId);
      _serverOnline = true;
      _errorMessage = null;
    } catch (error) {
      _applyError(error);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteSession(int sessionId) async {
    await _apiService.deleteChatSession(sessionId);
    _sessions = List<ChatSession>.from(_sessions)
      ..removeWhere((ChatSession session) => session.id == sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
      _chatEntries = <ChatEntry>[];
    }
    notifyListeners();
  }

  Future<void> loadSessions() async {
    try {
      _sessions = await _apiService.fetchChatSessions();
      notifyListeners();
    } catch (error) {
      _applyError(error);
      rethrow;
    }
  }

  Future<bool> checkIn({
    required Member member,
    required MochiMood mood,
  }) async {
    try {
      final result = await _apiService.checkInMood(
        memberId: member.id,
        mood: mood,
      );
      _pet = result.pet;
      _serverOnline = true;
      _errorMessage = null;

      try {
        await refreshState(includeHealth: false, includeChat: false);
      } catch (_) {
        notifyListeners();
      }
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 409) {
        _errorMessage = null;
        _serverOnline = true;
        return false;
      }
      _applyError(error);
      rethrow;
    } catch (error) {
      _applyError(error);
      rethrow;
    }
  }

  Future<void> tapPet(Member member) async {
    try {
      final result = await _apiService.tapPet(memberId: member.id);
      _pet = result.pet;
      _serverOnline = true;
      _errorMessage = null;

      try {
        await refreshState(includeHealth: false, includeChat: false);
      } catch (_) {
        notifyListeners();
      }
    } catch (error) {
      _applyError(error);
      rethrow;
    }
  }

  Future<void> addMemory({required String content, int weight = 1}) async {
    await _apiService.createMemory(content: content, weight: weight);
    await refreshState(includeHealth: false, includeChat: false);
  }

  Future<void> updateMemory({
    required int id,
    String? content,
    int? weight,
  }) async {
    await _apiService.updateMemory(id: id, content: content, weight: weight);
    await refreshState(includeHealth: false, includeChat: false);
  }

  Future<void> removeMemory(int id) async {
    await _apiService.deleteMemory(id);
    _memories = List<MemorySnippet>.from(_memories)..removeWhere((m) => m.id == id);
    notifyListeners();
  }

  Future<void> clearSession() async {
    await _webSocketSubscription?.cancel();
    await _webSocketService.disconnect();
    _webSocketSubscription = null;
    _pet = null;
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

  Future<void> _handleRealtimeEvent(Map<String, dynamic> event) async {
    final Map<String, dynamic>? petJson = event['pet'] as Map<String, dynamic>?;
    if (petJson != null) {
      _pet = Pet.fromJson(petJson);
      notifyListeners();
    }

    try {
      await refreshState(includeHealth: false, includeChat: !_replyPending);
    } catch (_) {
      // Keep the last known state if the follow-up refresh fails.
    }
  }

  void _applyError(Object error) {
    if (error is ApiException) {
      _errorMessage = error.message;
      _serverOnline = error.statusCode != null;
      return;
    }

    _errorMessage = 'Failed to sync with the Mochi server';
    _serverOnline = false;
  }

  @override
  void dispose() {
    unawaited(_webSocketSubscription?.cancel());
    unawaited(_webSocketService.dispose());
    unawaited(_ttsService.dispose());
    super.dispose();
  }
}
