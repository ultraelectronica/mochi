import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import 'session_store.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.kind = ApiErrorKind.generic,
  });

  final String message;
  final int? statusCode;
  final ApiErrorKind kind;

  bool get isOffline => kind == ApiErrorKind.offline;

  @override
  String toString() => message;
}

enum ApiErrorKind { generic, offline }

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> get _headers {
    final Map<String, String> base = <String, String>{};
    final String key = AppConfig.apiKey.trim();
    if (key.isNotEmpty) {
      base['Authorization'] = 'Bearer $key';
    }
    final String sessionToken = SessionStore.instance.sessionToken;
    if (sessionToken.isNotEmpty) {
      base['X-Mochi-Session'] = sessionToken;
    }
    return base;
  }

  Map<String, String> _jsonHeaders() => <String, String>{
    ..._headers,
    'Content-Type': 'application/json',
  };

  Future<({bool serverOnline, bool llamaOnline})> fetchHealth() async {
    final Map<String, dynamic> json = await _getMap('/health');
    return (
      serverOnline: json['status'] == 'ok',
      llamaOnline: json['llamaOnline'] == true,
    );
  }

  Future<AuthSession> bootstrap({
    required String householdName,
    required String adminName,
    required String username,
    required String password,
    required Color color,
  }) async {
    return AuthSession.fromJson(
      await _sendMap('POST', '/auth/bootstrap', <String, dynamic>{
        'household_name': householdName,
        'admin_name': adminName,
        'username': username,
        'password': password,
        'avatar_color': _hexFromColor(color),
      }),
    );
  }

  Future<AuthSession> login({
    required String householdCode,
    required String username,
    required String password,
  }) async {
    return AuthSession.fromJson(
      await _sendMap('POST', '/auth/login', <String, dynamic>{
        'household_code': householdCode,
        'username': username,
        'password': password,
      }),
    );
  }

  Future<AuthSession> acceptInvite({
    required String inviteCode,
    required String password,
  }) async {
    return AuthSession.fromJson(
      await _sendMap('POST', '/auth/accept-invite', <String, dynamic>{
        'invite_code': inviteCode,
        'password': password,
      }),
    );
  }

  Future<AuthSession> fetchSession() async {
    return AuthSession.fromJson(await _getMap('/auth/me'));
  }

  Future<void> logout() async {
    await _request('POST', '/auth/logout', body: <String, dynamic>{});
  }

  Future<Pet> fetchPet() async {
    return Pet.fromJson(await _getMap('/pet'));
  }

  Future<List<MemorySnippet>> fetchMemories() async {
    final List<dynamic> json = await _getList('/pet/memories');
    return json
        .whereType<Map<String, dynamic>>()
        .map(MemorySnippet.fromJson)
        .toList(growable: false);
  }

  Future<MemorySnippet> createMemory({
    required String content,
    int weight = 1,
  }) async {
    return MemorySnippet.fromJson(
      await _sendMap('POST', '/pet/memories', <String, dynamic>{
        'content': content,
        'weight': weight,
      }),
    );
  }

  Future<MemorySnippet> updateMemory({
    required int id,
    String? content,
    int? weight,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};
    if (content != null) {
      body['content'] = content;
    }
    if (weight != null) {
      body['weight'] = weight;
    }
    return MemorySnippet.fromJson(
      await _sendMap('PATCH', '/pet/memories/$id', body),
    );
  }

  Future<void> deleteMemory(int id) async {
    await _request('DELETE', '/pet/memories/$id');
  }

  Future<List<Member>> fetchMembers() async {
    final List<dynamic> json = await _getList('/members');
    return json
        .whereType<Map<String, dynamic>>()
        .map(Member.fromJson)
        .toList(growable: false);
  }

  Future<MemberDetail> fetchMemberDetail(int memberId) async {
    return MemberDetail.fromJson(await _getMap('/members/$memberId'));
  }

  Future<CreatedMemberInvite> createMember({
    required String name,
    required String username,
    required Color color,
  }) async {
    final Map<String, dynamic> json = await _sendMap(
      'POST',
      '/members',
      <String, dynamic>{
        'name': name,
        'username': username,
        'avatar_color': _hexFromColor(color),
      },
    );
    return CreatedMemberInvite(
      member: Member.fromJson(
        json['member'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      inviteCode: (json['invite_code'] as String? ?? '').trim(),
    );
  }

  Future<void> deleteMember(int memberId) async {
    await _request('DELETE', '/members/$memberId');
  }

  Future<List<ChatEntry>> fetchChatHistory({int limit = 30}) async {
    final List<dynamic> json = await _getList(
      '/chat',
      queryParameters: <String, String>{'limit': '$limit'},
    );

    return json
        .whereType<Map<String, dynamic>>()
        .expand(ChatEntry.fromInteractionJson)
        .toList(growable: false);
  }

  Future<({String reply, Pet pet})> sendMessage({
    required int memberId,
    required String text,
    String inputType = 'text',
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'text': text};
    if (inputType == 'voice') {
      body['input_type'] = 'voice';
    }
    final Map<String, dynamic> json = await _sendMap(
      'POST',
      '/chat',
      body,
    );

    return (
      reply: json['reply'] as String? ?? '',
      pet: Pet.fromJson(
        json['pet'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }

  Future<({Pet pet, int xpAwarded})> checkInMood({
    required int memberId,
    required MochiMood mood,
  }) async {
    final Map<String, dynamic> json = await _sendMap(
      'POST',
      '/mood/checkin',
      <String, dynamic>{'mood': mood.name},
    );

    return (
      pet: Pet.fromJson(
        json['pet'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      xpAwarded: _asInt(json['xpAwarded']),
    );
  }

  Future<({Pet pet, int xpAwarded})> tapPet({required int memberId}) async {
    final Map<String, dynamic> json = await _sendMap(
      'POST',
      '/pet/tap',
      <String, dynamic>{},
    );

    return (
      pet: Pet.fromJson(
        json['pet'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      xpAwarded: _asInt(json['xpAwarded']),
    );
  }

  Future<Map<int, MochiMood>> fetchTodayMoodMap() async {
    final List<dynamic> json = await _getList('/mood/log');
    final Map<int, MochiMood> moods = <int, MochiMood>{};

    for (final Map<String, dynamic> row
        in json.whereType<Map<String, dynamic>>()) {
      final int memberId = _asInt(row['member_id']);
      if (memberId <= 0) {
        continue;
      }
      moods[memberId] = mochiMoodFromString(row['mood'] as String? ?? 'normal');
    }

    return moods;
  }

  Future<List<ActivityEntry>> fetchFeed({int limit = 30}) async {
    final List<dynamic> json = await _getList(
      '/feed',
      queryParameters: <String, String>{'limit': '$limit'},
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(ActivityEntry.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final dynamic json = await _request(
      'GET',
      path,
      queryParameters: queryParameters,
    );
    if (json is Map<String, dynamic>) {
      return json;
    }
    throw const ApiException('Unexpected server response');
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final dynamic json = await _request(
      'GET',
      path,
      queryParameters: queryParameters,
    );
    if (json is List<dynamic>) {
      return json;
    }
    throw const ApiException('Unexpected server response');
  }

  Future<Map<String, dynamic>> _sendMap(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final dynamic json = await _request(method, path, body: body);
    if (json is Map<String, dynamic>) {
      return json;
    }
    throw const ApiException('Unexpected server response');
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = AppConfig.apiUri(path, queryParameters);
    debugPrint('[API] $method $uri');
    if (body != null) debugPrint('[API] body: $body');
    late final http.Response response;

    try {
      if (method == 'POST') {
        response = await _client.post(
          uri,
          headers: _jsonHeaders(),
          body: jsonEncode(body),
        );
      } else if (method == 'PATCH') {
        response = await _client.patch(
          uri,
          headers: _jsonHeaders(),
          body: jsonEncode(body),
        );
      } else if (method == 'DELETE') {
        response = await _client.delete(uri, headers: _headers);
      } else {
        response = await _client.get(uri, headers: _headers);
      }
    } catch (e) {
      debugPrint('[API] OFFLINE — $uri ($e)');
      throw const ApiException(
        'Unable to reach the Mochi server',
        kind: ApiErrorKind.offline,
      );
    }

    debugPrint('[API] $method $path → ${response.statusCode}');

    final String rawBody = response.body.trim();
    dynamic json;
    if (rawBody.isNotEmpty) {
      try {
        json = jsonDecode(rawBody);
      } catch (_) {
        json = rawBody;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String message =
          json is Map<String, dynamic> && json['error'] is String
          ? json['error'] as String
          : 'Server request failed';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return json;
  }
}

String _hexFromColor(Color color) {
  final int rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
