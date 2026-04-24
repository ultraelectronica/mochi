import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/mood.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import 'mood_checkin_content.dart';

Future<void> showMoodCheckinSheet(
  BuildContext context, {
  required PetProvider petProvider,
  required MemberProvider memberProvider,
  required Future<bool> Function(MochiMood mood) onSubmitMood,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[petProvider, memberProvider]),
        builder: (BuildContext context, Widget? child) {
          final pet = petProvider.pet;
          final currentMember = memberProvider.currentMember;
          final selectedMood = petProvider.moodForMember(currentMember.id);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                    return Material(
                      color: MochiPalette.card.withValues(alpha: 0.98),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        side: BorderSide(color: MochiPalette.ink, width: 3),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: <Widget>[
                          const SizedBox(height: 10),
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: MochiPalette.ink.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                24,
                              ),
                              children: <Widget>[
                                MoodCheckinContent(
                                  currentMember: currentMember,
                                  selectedMood: selectedMood,
                                  familyCheckIns: petProvider.memberCheckIns,
                                  members: memberProvider.members,
                                  petMood: pet.mood,
                                  onSubmitMood: (MochiMood mood) async {
                                    final bool applied = await onSubmitMood(
                                      mood,
                                    );
                                    if (applied &&
                                        sheetContext.mounted &&
                                        Navigator.of(sheetContext).canPop()) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    return applied;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
            ),
          );
        },
      );
    },
  );
}
