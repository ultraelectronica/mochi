import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/member.dart';
import '../services/api_service.dart';

class MemberProvider extends ChangeNotifier {
  MemberProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  DateTime _lastLoadedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minLoadInterval = Duration(seconds: 5);

  final List<Member> _members = <Member>[];
  int _selectedIndex = 0;
  int? _currentMemberId;
  int? _selectedMemberId;
  bool _isLoading = true;
  bool _isCreating = false;
  int? _deletingMemberId;
  bool _isLoadingSelectedMemberDetail = false;
  MemberDetail? _selectedMemberDetail;
  bool _isAdmin = false;
  String? _errorMessage;

  List<Member> get members => List<Member>.unmodifiable(_members);

  int get selectedIndex => _selectedIndex;

  bool get isLoading => _isLoading;

  bool get isCreating => _isCreating;

  int? get deletingMemberId => _deletingMemberId;

  bool get isLoadingSelectedMemberDetail => _isLoadingSelectedMemberDetail;

  bool get hasMembers => _members.isNotEmpty;
  bool get isAdmin => _isAdmin;

  String? get errorMessage => _errorMessage;

  MemberDetail? get selectedMemberDetail => _selectedMemberDetail;

  Member get currentMember => currentMemberOrNull ?? _members[_selectedIndex];

  Member? get currentMemberOrNull {
    if (_members.isEmpty) {
      return null;
    }

    for (final Member member in _members) {
      if (member.id == _currentMemberId) {
        return member;
      }
    }

    return _members[_selectedIndex];
  }

  void configureSession(AuthSession session) {
    _currentMemberId = session.member.id;
    _selectedMemberId ??= session.member.id;
    _isAdmin = session.account.isAdmin;
  }

  void clearSession() {
    _members.clear();
    _selectedIndex = 0;
    _currentMemberId = null;
    _selectedMemberId = null;
    _selectedMemberDetail = null;
    _isAdmin = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadMembers({
    bool setLoading = true,
    int? preferredMemberId,
    bool force = false,
  }) async {
    if (!setLoading && !force &&
        DateTime.now().difference(_lastLoadedAt) < _minLoadInterval) {
      return;
    }

    if (setLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final List<Member> members = await _apiService.fetchMembers();
      _members
        ..clear()
        ..addAll(members);
      _syncSelection(preferredMemberId: preferredMemberId);
      await _refreshSelectedMemberDetail(setLoading: false);
      _errorMessage = null;
      _lastLoadedAt = DateTime.now();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CreatedMemberInvite> createMember({
    required String name,
    required String username,
    required Color color,
  }) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final CreatedMemberInvite created = await _apiService.createMember(
        name: name,
        username: username,
        color: color,
      );
      await loadMembers(setLoading: false, preferredMemberId: created.member.id);
      return created;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<void> deleteMember(Member member) async {
    _deletingMemberId = member.id;
    _errorMessage = null;
    notifyListeners();

    final int? preferredMemberId =
        currentMemberOrNull?.id == member.id ? null : _selectedMemberId;

    try {
      await _apiService.deleteMember(member.id);
      await loadMembers(
        setLoading: false,
        preferredMemberId: preferredMemberId,
      );
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _deletingMemberId = null;
      notifyListeners();
    }
  }

  void selectMember(int index) {
    if (index < 0 || index >= _members.length || index == _selectedIndex) {
      return;
    }

    _selectedIndex = index;
    _selectedMemberId = _members[index].id;
    _selectedMemberDetail = null;
    notifyListeners();
    unawaited(_refreshSelectedMemberDetail());
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void _syncSelection({int? preferredMemberId}) {
    if (_members.isEmpty) {
      _selectedIndex = 0;
      _currentMemberId = null;
      _selectedMemberId = null;
      _selectedMemberDetail = null;
      return;
    }

    _currentMemberId ??= _members.first.id;
    if (_members.every((Member member) => member.id != _currentMemberId)) {
      _currentMemberId = _members.first.id;
    }

    final int? targetMemberId = preferredMemberId ?? _selectedMemberId ?? _currentMemberId;
    if (targetMemberId != null) {
      final int preservedIndex = _members.indexWhere(
        (Member member) => member.id == targetMemberId,
      );
      if (preservedIndex >= 0) {
        _selectedIndex = preservedIndex;
        _selectedMemberId = _members[preservedIndex].id;
        return;
      }
    }

    _selectedIndex = _members.indexWhere((Member member) => member.id == _currentMemberId);
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }
    _selectedMemberId = _members[_selectedIndex].id;
  }

  Future<void> _refreshSelectedMemberDetail({bool setLoading = true}) async {
    final Member? member = currentMemberOrNull;
    if (member == null) {
      _selectedMemberDetail = null;
      _isLoadingSelectedMemberDetail = false;
      return;
    }

    if (setLoading) {
      _isLoadingSelectedMemberDetail = true;
      notifyListeners();
    }

    try {
      _selectedMemberDetail = await _apiService.fetchMemberDetail(member.id);
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _selectedMemberDetail = null;
    } finally {
      _isLoadingSelectedMemberDetail = false;
      notifyListeners();
    }
  }
}
