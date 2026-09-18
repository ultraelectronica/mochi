import 'dart:async';

import 'package:flutter/material.dart';

import '../db/mochi_db.dart';
import '../db/mochi_repository.dart';
import '../models/member.dart';

/// Single-user local profile. No accounts, no households, no server.
class MemberProvider extends ChangeNotifier {
  late MochiRepository _repo;

  Member? _profile;
  Member? _currentMember;
  bool _isLoading = true;
  String? _errorMessage;

  List<Member> get members => _profile == null
      ? <Member>[]
      : <Member>[_profile!];

  bool get isLoading => _isLoading;
  bool get hasMembers => _profile != null;
  bool get isAdmin => true;
  String? get errorMessage => _errorMessage;

  Member get currentMember => currentMemberOrNull!;

  Member? get currentMemberOrNull {
    if (_profile == null) {
      return null;
    }
    if (_currentMember?.id == _profile!.id) {
      return _currentMember;
    }
    _currentMember = _profile;
    return _currentMember;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      final MochiDb db = await MochiDb.instance();
      _repo = MochiRepository(db);
      _profile = _repo.getProfile();
      _currentMember = _profile;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMembers({
    bool setLoading = true,
    int? preferredMemberId,
    bool force = false,
  }) async {
    _profile = _repo.getProfile();
    _currentMember = _profile;
    notifyListeners();
  }

  Future<void> updateProfile({String? bio, DateTime? birthdate}) async {
    _repo.updateProfile(bio: bio, birthdate: birthdate);
    _profile = _repo.getProfile();
    _currentMember = null;
    notifyListeners();
  }

  Future<void> clearSession() async {
    _profile = null;
    _currentMember = null;
    _errorMessage = null;
    notifyListeners();
  }

  void selectMember(int index) {
    // Single-user: nothing to switch.
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }
}
