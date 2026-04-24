import 'dart:async';

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class PetProvider extends ChangeNotifier {
  PetProvider({ApiService? apiService, WebSocketService? webSocketService})
    : _apiService = apiService ?? ApiService(),
      _webSocketService = webSocketService ?? WebSocketService();

  final ApiService _apiService;
  final WebSocketService _webSocketService;

  StreamSubscription<Map<String, dynamic>>? _webSocketSubscription;

  Pet? _pet;
  List<ChatEntry> _chatEntries = <ChatEntry>[];
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

  Pet get pet => _pet!;
  List<ChatEntry> get chatEntries => List<ChatEntry>.unmodifiable(_chatEntries);
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
    notifyListeners();

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
        requests.add(_apiService.fetchChatHistory());
      }

      final List<Object> results = await Future.wait<Object>(requests);

      _pet = results[0] as Pet;
      _memories = results[1] as List<MemorySnippet>;
      _feedEntries = results[2] as List<ActivityEntry>;
      _memberCheckIns = results[3] as Map<int, MochiMood>;
      if (includeChat) {
        _chatEntries = results[4] as List<ChatEntry>;
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
      final ({String reply, Pet pet}) result = await _apiService.sendMessage(
        memberId: member.id,
        text: text,
      );

      _pet = result.pet;
      _chatEntries = <ChatEntry>[
        ..._chatEntries,
        ChatEntry.local(author: 'Mochi', text: result.reply, isPet: true),
      ];
      _serverOnline = true;
      _errorMessage = null;

      try {
        await refreshState(includeHealth: false, includeChat: true);
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

  Future<void> clearSession() async {
    await _webSocketSubscription?.cancel();
    await _webSocketService.disconnect();
    _webSocketSubscription = null;
    _pet = null;
    _chatEntries = <ChatEntry>[];
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
    notifyListeners();
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
      await refreshState(includeHealth: false, includeChat: true);
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
    super.dispose();
  }
}
