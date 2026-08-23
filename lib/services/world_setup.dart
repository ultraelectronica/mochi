import 'package:flutter/material.dart';

import '../db/mochi_db.dart';
import '../db/mochi_repository.dart';

/// One-time local world creation: the user profile and their pet.
class WorldSetup {
  WorldSetup._();

  static Future<void> createWorld({
    required String userName,
    required String petName,
    required Color avatarColor,
  }) async {
    final MochiDb db = await MochiDb.instance();
    final MochiRepository repo = MochiRepository(db);
    final String colorHex =
        '#${(avatarColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    repo.createProfile(userName.trim(), colorHex);
    repo.createPet(petName.trim().isEmpty ? 'Mochi' : petName.trim());
    repo.touchProfileSeen(DateTime.now());
  }
}
