import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../providers/pet_provider.dart';
import 'member_avatar.dart';
import 'pet_sprite.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.entry,
    required this.currentMember,
    required this.petProvider,
    this.showAuthor = true,
    this.showTimestamp = true,
  });

  final ChatEntry entry;
  final Member currentMember;
  final PetProvider petProvider;
  final bool showAuthor;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    final bool petSide = entry.isPet;
    final Color accent = petSide
        ? petProvider.pet.mood.color
        : currentMember.color;
    final bool showMeta = showAuthor || showTimestamp;

    return Row(
      mainAxisAlignment: petSide
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (petSide) ...<Widget>[
          MochiPetAvatar(pet: petProvider.pet, size: 32),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(petSide ? 6 : 18),
                bottomRight: Radius.circular(petSide ? 18 : 6),
              ),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showMeta)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      <String>[
                        if (showAuthor) entry.author,
                        if (showTimestamp) entry.timestamp,
                      ].join(' \u00b7 '),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: MochiPalette.ink.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                Text(
                  entry.text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!petSide) ...<Widget>[
          const SizedBox(width: 8),
          MemberAvatar(member: currentMember, size: 32),
        ],
      ],
    );
  }
}

class MochiPetAvatar extends StatelessWidget {
  const MochiPetAvatar({
    super.key,
    required this.pet,
    this.size = 32,
    this.bordered = true,
  });

  final Pet pet;
  final double size;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pet.mood.color,
        shape: BoxShape.circle,
        border: bordered
            ? Border.all(color: MochiPalette.ink, width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        mochiSpriteAsset(pet),
        width: size * 0.82,
        height: size * 0.82,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      ),
    );
  }
}
