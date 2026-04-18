import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import 'member_avatar.dart';
import 'mood_tile.dart';

/// Shared mood check-in body: status, mood grid, family chips.
class MoodCheckinContent extends StatelessWidget {
  const MoodCheckinContent({
    super.key,
    required this.currentMember,
    required this.selectedMood,
    required this.familyCheckIns,
    required this.members,
    required this.petMood,
    required this.onSubmitMood,
  });

  final Member currentMember;
  final MochiMood? selectedMood;
  final Map<String, MochiMood> familyCheckIns;
  final List<Member> members;
  final MochiMood petMood;
  final Future<bool> Function(MochiMood mood) onSubmitMood;

  @override
  Widget build(BuildContext context) {
    final bool locked = selectedMood != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _MoodPanelTitle(
          title: 'Mood check-in',
          subtitle: locked
              ? '${currentMember.name} already checked in today.'
              : 'Pick one of the 9 moods to nudge Mochi\'s shared state.',
        ),
        const SizedBox(height: 10),
        _MoodBadge(
          label: selectedMood?.label ?? 'Not checked in yet',
          color: (selectedMood ?? petMood).color.withValues(alpha: 0.25),
          icon: (selectedMood ?? petMood).icon,
        ),
        const SizedBox(height: 12),
        Text(
          selectedMood?.reaction ?? petMood.reaction,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: MochiMood.values.map((MochiMood mood) {
            return MoodTile(
              mood: mood,
              selected: selectedMood == mood,
              enabled: !locked,
              onTap: () async {
                await onSubmitMood(mood);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: members.map((Member member) {
            final MochiMood? mood = familyCheckIns[member.name];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    (mood?.color.withValues(alpha: 0.2) ??
                    member.color.withValues(alpha: 0.14)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MochiPalette.ink, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  MemberAvatar(member: member, size: 30),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        member.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        mood?.label ?? 'Waiting',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MoodPanelTitle extends StatelessWidget {
  const _MoodPanelTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MoodBadge extends StatelessWidget {
  const _MoodBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: MochiPalette.ink),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
