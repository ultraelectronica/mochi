import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../providers/pet_provider.dart';
import 'member_avatar.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.entry,
    required this.currentMember,
    required this.petProvider,
  });

  final ChatEntry entry;
  final Member currentMember;
  final PetProvider petProvider;

  @override
  Widget build(BuildContext context) {
    final bool petSide = entry.isPet;
    final Member petAvatar = Member(
      id: 0,
      name: 'Mochi',
      color: petProvider.pet.mood.color,
      affection: 0,
      xp: 0,
      note: '',
    );

    return Row(
      mainAxisAlignment: petSide
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (petSide) ...<Widget>[
          MemberAvatar(
            member: petAvatar,
            size: 34,
            child: const Icon(
              Icons.pets_rounded,
              size: 18,
              color: MochiPalette.ink,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: petSide
                  ? petProvider.pet.mood.color.withValues(alpha: 0.2)
                  : currentMember.color.withValues(alpha: 0.24),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(petSide ? 6 : 20),
                bottomRight: Radius.circular(petSide ? 20 : 6),
              ),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.author,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(entry.text, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  entry.timestamp,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        if (!petSide) ...<Widget>[
          const SizedBox(width: 8),
          MemberAvatar(member: currentMember, size: 34),
        ],
      ],
    );
  }
}
