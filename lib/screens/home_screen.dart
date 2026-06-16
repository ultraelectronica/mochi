import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../widgets/member_avatar.dart';
import '../widgets/pet_sprite.dart';
import '../widgets/mochi_bottom_nav_bar.dart';
import '../widgets/xp_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.petProvider,
    required this.memberProvider,
    required this.onPetTap,
    required this.onOpenMoodCheckInSheet,
    required this.onOpenMoodCheckInFullScreen,
    required this.onOpenChat,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final VoidCallback onPetTap;
  final VoidCallback onOpenMoodCheckInSheet;
  final VoidCallback onOpenMoodCheckInFullScreen;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final Pet pet = petProvider.pet;
    final Member currentMember = memberProvider.currentMember;
    final MochiMood? selectedMood = petProvider.moodForMember(currentMember.id);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MochiBottomNavBar.overlayPadding(context) + 24,
      ),
      child: Column(
            children: <Widget>[
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 7,
                      child: _HeroPanel(
                        pet: pet,
                        petProvider: petProvider,
                        currentMember: currentMember,
                        totalMembers: memberProvider.members.length,
                        onPetTap: onPetTap,
                        onOpenChat: onOpenChat,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: _ProfilePanel(
                        pet: pet,
                        members: memberProvider.members,
                        memories: petProvider.memories,
                      ),
                    ),
                  ],
                )
              else ...<Widget>[
                _HeroPanel(
                  pet: pet,
                  petProvider: petProvider,
                  currentMember: currentMember,
                  totalMembers: memberProvider.members.length,
                  onPetTap: onPetTap,
                  onOpenChat: onOpenChat,
                ),
                const SizedBox(height: 16),
                _ProfilePanel(
                  pet: pet,
                  members: memberProvider.members,
                  memories: petProvider.memories,
                ),
              ],
              const SizedBox(height: 16),
              _MoodSummaryPanel(
                currentMember: currentMember,
                selectedMood: selectedMood,
                familyCheckIns: petProvider.memberCheckIns,
                members: memberProvider.members,
                petMood: pet.mood,
                onOpenSheet: onOpenMoodCheckInSheet,
                onOpenFullScreen: onOpenMoodCheckInFullScreen,
              ),
              const SizedBox(height: 16),
              _FeedPanel(entries: petProvider.feedEntries),
            ],
          ),
        );
      },
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.pet,
    required this.petProvider,
    required this.currentMember,
    required this.totalMembers,
    required this.onPetTap,
    required this.onOpenChat,
  });

  final Pet pet;
  final PetProvider petProvider;
  final Member currentMember;
  final int totalMembers;
  final VoidCallback onPetTap;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _Badge(
              label: pet.stage.label,
              color: MochiPalette.yellow,
              icon: Icons.timeline_rounded,
            ),
            _Badge(
              label: pet.mood.label,
              color: pet.mood.color.withValues(alpha: 0.28),
              icon: pet.mood.icon,
            ),
            _Badge(
              label: petProvider.serverOnline ? 'Live sync' : 'Gemini fallback',
              color: petProvider.serverOnline
                  ? MochiPalette.mint
                  : MochiPalette.peach,
              icon: petProvider.serverOnline
                  ? Icons.sync_rounded
                  : Icons.offline_bolt_rounded,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'One shared pet, one bright family room.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          petProvider.greetingFor(currentMember.name),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        XpBar(
          value: pet.stageProgress,
          color: MochiPalette.sky,
          label: pet.nextStage == null
              ? 'Max growth reached - ${pet.xp} XP total'
              : '${pet.xp} XP of ${pet.nextStageXp} XP toward ${pet.nextStage!.label}',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            const _MiniStatCard(label: 'Motion', value: 'Smooth'),
            _MiniStatCard(
              label: 'Affinity',
              value: '${currentMember.affection}%',
            ),
            _MiniStatCard(label: 'Family', value: '$totalMembers members'),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onOpenChat,
          icon: const Icon(Icons.chat_bubble_rounded),
          label: const Text('Open Chat'),
        ),
      ],
    );

    final Widget petBlock = Column(
      children: <Widget>[
        PetSprite(pet: pet, size: 200, onTap: onPetTap),
        const SizedBox(height: 6),
        Text(
          'Tap Mochi for a tiny reaction burst.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: pixelCardDecoration(MochiPalette.lightPink),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 700;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                textBlock,
                const SizedBox(height: 14),
                Center(child: petBlock),
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(flex: 5, child: textBlock),
              const SizedBox(width: 14),
              Expanded(flex: 4, child: Center(child: petBlock)),
            ],
          );
        },
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.pet,
    required this.members,
    required this.memories,
  });

  final Pet pet;
  final List<Member> members;
  final List<MemorySnippet> memories;

  @override
  Widget build(BuildContext context) {
    final List<Member> ranked = List<Member>.from(members)
      ..sort((Member a, Member b) => b.affection.compareTo(a.affection));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: pixelCardDecoration(MochiPalette.yellow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Pet profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StagePill(stage: pet.stage.label),
            ],
          ),
          const SizedBox(height: 10),
          _StageTimeline(pet: pet),
          const SizedBox(height: 12),
          Text(
            'Memories',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          if (memories.isEmpty)
            Text(
              'Mochi will save favorite family moments here after a few conversations.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...memories.take(2).map((MemorySnippet memory) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CompactMemoryTile(memory: memory),
              );
            }),
          const SizedBox(height: 4),
          Text(
            'Affection',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ranked.take(4).map((Member member) {
              return _CompactMemberChip(member: member);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StagePill extends StatelessWidget {
  const _StagePill({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MochiPalette.yellow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, size: 14, color: MochiPalette.ink),
          const SizedBox(width: 4),
          Text(stage, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _StageTimeline extends StatelessWidget {
  const _StageTimeline({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    final int currentIndex = PetStage.values.indexOf(pet.stage);

    for (int index = 0; index < PetStage.values.length; index++) {
      final PetStage stage = PetStage.values[index];
      final bool unlocked = index <= currentIndex;
      final bool current = stage == pet.stage;

      children.add(
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: current
                  ? MochiPalette.yellow
                  : unlocked
                  ? MochiPalette.cloudBlue
                  : MochiPalette.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: current ? MochiPalette.ink : MochiPalette.ink.withValues(alpha: 0.25),
                width: current ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  current ? Icons.star_rounded : Icons.adjust_rounded,
                  size: 16,
                  color: MochiPalette.ink,
                ),
                const SizedBox(height: 3),
                Text(
                  stage.label,
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );

      if (index < PetStage.values.length - 1) {
        final bool nextUnlocked = index + 1 <= currentIndex;
        children.addAll(<Widget>[
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 2,
            color: nextUnlocked
                ? MochiPalette.ink.withValues(alpha: 0.35)
                : MochiPalette.ink.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 6),
        ]);
      }
    }

    return Row(children: children);
  }
}

class _CompactMemoryTile extends StatelessWidget {
  const _CompactMemoryTile({required this.memory});

  final MemorySnippet memory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: memory.accent.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  memory.title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                memory.timestamp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            memory.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CompactMemberChip extends StatelessWidget {
  const _CompactMemberChip({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: member.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MemberAvatar(member: member, size: 26),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                member.name,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                '${member.affection}% · ${member.xp} XP',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodSummaryPanel extends StatelessWidget {
  const _MoodSummaryPanel({
    required this.currentMember,
    required this.selectedMood,
    required this.familyCheckIns,
    required this.members,
    required this.petMood,
    required this.onOpenSheet,
    required this.onOpenFullScreen,
  });

  final Member currentMember;
  final MochiMood? selectedMood;
  final Map<int, MochiMood> familyCheckIns;
  final List<Member> members;
  final MochiMood petMood;
  final VoidCallback onOpenSheet;
  final VoidCallback onOpenFullScreen;

  @override
  Widget build(BuildContext context) {
    final bool locked = selectedMood != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: pixelCardDecoration(MochiPalette.cloudBlue),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PanelTitle(
            title: 'Mood check-in',
            subtitle: locked
                ? '${currentMember.name} already checked in today.'
                : 'Tap below to pick one of the 9 moods and nudge Mochi\'s shared state.',
          ),
          const SizedBox(height: 10),
          _Badge(
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: members.map((Member member) {
              final MochiMood? mood = familyCheckIns[member.id];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenSheet,
            icon: Icon(locked ? Icons.visibility_rounded : Icons.mood_rounded),
            label: Text(locked ? 'View family check-ins' : 'Check in'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpenFullScreen,
              style: TextButton.styleFrom(
                foregroundColor: MochiPalette.ink,
              ),
              child: const Text('Open full screen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPanel extends StatefulWidget {
  const _FeedPanel({required this.entries});

  final List<ActivityEntry> entries;

  @override
  State<_FeedPanel> createState() => _FeedPanelState();
}

class _FeedPanelState extends State<_FeedPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final String summary = widget.entries.isEmpty
        ? 'No activity yet'
        : '${widget.entries.length} recent event${widget.entries.length == 1 ? '' : 's'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pixelCardDecoration(MochiPalette.mint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Family activity feed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (!_expanded)
                      Text(
                        summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: MochiPalette.ink,
                ),
                tooltip: _expanded ? 'Minimize feed' : 'Expand feed',
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 10),
                      if (widget.entries.isEmpty)
                        Text(
                          'The feed wakes up after the first chat, mood check-in, or pet tap.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        ...widget.entries.take(4).map((ActivityEntry entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FeedTile(entry: entry),
                          );
                        }),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.subtitle});

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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

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

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: entry.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: Icon(entry.icon, color: MochiPalette.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  entry.detail,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  entry.timestamp,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


