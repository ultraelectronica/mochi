class AuthSession {
  const AuthSession({
    required this.sessionToken,
    required this.household,
    required this.account,
    required this.member,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      sessionToken: (json['session_token'] as String? ?? '').trim(),
      household: AuthHousehold.fromJson(
        json['household'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      account: AuthAccount.fromJson(
        json['account'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      member: AuthMember.fromJson(
        json['member'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }

  final String sessionToken;
  final AuthHousehold household;
  final AuthAccount account;
  final AuthMember member;
}

class AuthHousehold {
  const AuthHousehold({
    required this.id,
    required this.name,
    required this.code,
  });

  factory AuthHousehold.fromJson(Map<String, dynamic> json) {
    return AuthHousehold(
      id: _asInt(json['id']),
      name: (json['name'] as String? ?? 'Household').trim(),
      code: (json['code'] as String? ?? '').trim(),
    );
  }

  final int id;
  final String name;
  final String code;
}

class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.username,
    required this.isAdmin,
  });

  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    return AuthAccount(
      id: _asInt(json['id']),
      username: (json['username'] as String? ?? '').trim(),
      isAdmin: json['is_admin'] == true || json['is_admin'] == 1,
    );
  }

  final int id;
  final String username;
  final bool isAdmin;
}

class AuthMember {
  const AuthMember({
    required this.id,
    required this.name,
    required this.avatarColor,
  });

  factory AuthMember.fromJson(Map<String, dynamic> json) {
    return AuthMember(
      id: _asInt(json['id']),
      name: (json['name'] as String? ?? 'Member').trim(),
      avatarColor: (json['avatar_color'] as String? ?? '#1D9E75').trim(),
    );
  }

  final int id;
  final String name;
  final String avatarColor;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
