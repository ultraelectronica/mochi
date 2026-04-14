import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<({bool serverOnline, bool llamaOnline})> fetchHealth() async {
    final Map<String, dynamic> json = await _getMap('/health');
    return (
      serverOnline: json['status'] == 'ok',
      llamaOnline: json['llamaOnline'] == true,
    );
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

  Future<List<Member>> fetchMembers() async {
    final List<dynamic> json = await _getList('/members');
    return json
        .whereType<Map<String, dynamic>>()
        .map(Member.fromJson)
        .toList(growable: false);
  }

  Future<Member> createMember({
    required String name,
    required Color color,
  }) async {
    final Map<String, dynamic> json = await _sendMap(
      'POST',
      '/members',
      <String, dynamic>{'name': name, 'avatar_color': _hexFromColor(color)},
    );
    return Member.fromJson(json);
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
  }) async {
    final Map<String, dynamic> json = await _sendMap(
      'POST',
      '/chat',
      <String, dynamic>{'member_id': memberId, 'text': text},
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
      <String, dynamic>{'member_id': memberId, 'mood': mood.name},
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
      <String, dynamic>{'member_id': memberId},
    );

    return (
      pet: Pet.fromJson(
        json['pet'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      xpAwarded: _asInt(json['xpAwarded']),
    );
  }

  Future<Map<String, MochiMood>> fetchTodayMoodMap() async {
    final List<dynamic> json = await _getList('/mood/log');
    final Map<String, MochiMood> moods = <String, MochiMood>{};

    for (final Map<String, dynamic> row
        in json.whereType<Map<String, dynamic>>()) {
      final String? memberName = (row['member_name'] as String?)?.trim();
      if (memberName == null || memberName.isEmpty) {
        continue;
      }
      moods[memberName] = mochiMoodFromString(
        row['mood'] as String? ?? 'normal',
      );
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
    late final http.Response response;

    try {
      if (method == 'POST') {
        response = await _client.post(
          uri,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else if (method == 'PATCH') {
        response = await _client.patch(
          uri,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
      } else if (method == 'DELETE') {
        response = await _client.delete(uri);
      } else {
        response = await _client.get(uri);
      }
    } catch (_) {
      throw const ApiException('Unable to reach the Mochi server');
    }

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
