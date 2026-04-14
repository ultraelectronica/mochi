import 'dart:async';

import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/api_service.dart';

class MemberProvider extends ChangeNotifier {
  MemberProvider({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  final List<Member> _members = <Member>[];
  int _selectedIndex = 0;
  int? _selectedMemberId;
  bool _isLoading = true;
  bool _isCreating = false;
  int? _deletingMemberId;
  bool _isLoadingSelectedMemberDetail = false;
  MemberDetail? _selectedMemberDetail;
  String? _errorMessage;

  List<Member> get members => List<Member>.unmodifiable(_members);

  int get selectedIndex => _selectedIndex;

  bool get isLoading => _isLoading;

  bool get isCreating => _isCreating;

  int? get deletingMemberId => _deletingMemberId;

  bool get isLoadingSelectedMemberDetail => _isLoadingSelectedMemberDetail;

  bool get hasMembers => _members.isNotEmpty;

  String? get errorMessage => _errorMessage;

  MemberDetail? get selectedMemberDetail => _selectedMemberDetail;

  Member get currentMember => _members[_selectedIndex];

  Member? get currentMemberOrNull =>
      _members.isEmpty ? null : _members[_selectedIndex];

  Future<void> loadMembers({
    bool setLoading = true,
    int? preferredMemberId,
  }) async {
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
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Member> createMember({
    required String name,
    required Color color,
  }) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Member created = await _apiService.createMember(
        name: name,
        color: color,
      );
      await loadMembers(setLoading: false, preferredMemberId: created.id);
      return currentMember;
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

    final int? preferredMemberId = currentMemberOrNull?.id == member.id
        ? null
        : currentMemberOrNull?.id;

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
      _selectedMemberId = null;
      _selectedMemberDetail = null;
      return;
    }

    final int? targetMemberId = preferredMemberId ?? _selectedMemberId;
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

    final int maxIndex = _members.length - 1;
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    } else if (_selectedIndex > maxIndex) {
      _selectedIndex = maxIndex;
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
