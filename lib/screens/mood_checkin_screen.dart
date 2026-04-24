import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/mood.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../widgets/mood_checkin_content.dart';

/// Full-screen mood check-in; same content as the daily bottom sheet.
class MoodCheckinScreen extends StatelessWidget {
  const MoodCheckinScreen({
    super.key,
    required this.petProvider,
    required this.memberProvider,
    required this.onSubmitMood,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final Future<bool> Function(MochiMood mood) onSubmitMood;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[petProvider, memberProvider]),
      builder: (BuildContext context, Widget? child) {
        final pet = petProvider.pet;
        final currentMember = memberProvider.currentMember;
        final selectedMood = petProvider.moodForMember(currentMember.id);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mood check-in'),
            backgroundColor: MochiPalette.background,
            foregroundColor: MochiPalette.ink,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: MoodCheckinContent(
                currentMember: currentMember,
                selectedMood: selectedMood,
                familyCheckIns: petProvider.memberCheckIns,
                members: memberProvider.members,
                petMood: pet.mood,
                onSubmitMood: onSubmitMood,
              ),
            ),
          ),
        );
      },
    );
  }
}
