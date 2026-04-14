import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../widgets/member_avatar.dart';
import '../widgets/mood_tile.dart';
import '../widgets/pet_sprite.dart';
import '../widgets/xp_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.petProvider,
    required this.memberProvider,
    required this.onPetTap,
    required this.onCheckInMood,
    required this.onOpenChat,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final VoidCallback onPetTap;
  final ValueChanged<MochiMood> onCheckInMood;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final Pet pet = petProvider.pet;
    final Member currentMember = memberProvider.currentMember;
    final MochiMood? selectedMood = petProvider.moodForMember(
      currentMember.name,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 920;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
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
              _MoodPanel(
                currentMember: currentMember,
                selectedMood: selectedMood,
                familyCheckIns: petProvider.memberCheckIns,
                members: memberProvider.members,
                petMood: pet.mood,
                onSelectMood: onCheckInMood,
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
        const SizedBox(height: 14),
        Text(
          'One shared pet, one bright family room.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          petProvider.greetingFor(currentMember.name),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 14),
        XpBar(
          value: pet.stageProgress,
          color: MochiPalette.sky,
          label: pet.nextStage == null
              ? 'Max growth reached - ${pet.xp} XP total'
              : '${pet.xp} XP of ${pet.nextStageXp} XP toward ${pet.nextStage!.label}',
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        Text(
          'Profile details, memories, check-ins, and feed previews now live directly on Home for this draft.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onOpenChat,
          icon: const Icon(Icons.chat_bubble_rounded),
          label: const Text('Open Chat'),
        ),
      ],
    );

    final Widget petBlock = Column(
      children: <Widget>[
        PetSprite(pet: pet, size: 250, onTap: onPetTap),
        const SizedBox(height: 8),
        Text(
          'Tap Mochi for a tiny reaction burst.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: pixelCardDecoration(MochiPalette.lightPink),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 700;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                textBlock,
                const SizedBox(height: 18),
                Center(child: petBlock),
              ],
            );
          }

          return Row(
            children: <Widget>[
              Expanded(flex: 5, child: textBlock),
              const SizedBox(width: 18),
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: pixelCardDecoration(MochiPalette.yellow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PanelTitle(
            title: 'Pet profile on Home',
            subtitle:
                'Growth, memories, and affection are folded into the main hub.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: PetStage.values.map((PetStage stage) {
              final bool unlocked =
                  PetStage.values.indexOf(stage) <=
                  PetStage.values.indexOf(pet.stage);
              final bool current = stage == pet.stage;
              return Container(
                width: 132,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: current
                      ? MochiPalette.yellow
                      : unlocked
                      ? MochiPalette.cloudBlue
                      : MochiPalette.ink.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MochiPalette.ink, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      current ? Icons.star_rounded : Icons.adjust_rounded,
                      color: MochiPalette.ink,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stage.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.note,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Remembered snippets',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (memories.isEmpty)
            Text(
              'Mochi will save favorite family moments here after a few conversations.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...memories.take(2).map((MemorySnippet memory) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemoryTile(memory: memory),
              );
            }),
          const SizedBox(height: 6),
          Text(
            'Affection leaderboard',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ...ranked.take(4).map((Member member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: member.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: MochiPalette.ink, width: 2),
                ),
                child: Row(
                  children: <Widget>[
                    MemberAvatar(member: member, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            member.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${member.affection} affection and ${member.xp} XP',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MoodPanel extends StatelessWidget {
  const _MoodPanel({
    required this.currentMember,
    required this.selectedMood,
    required this.familyCheckIns,
    required this.members,
    required this.petMood,
    required this.onSelectMood,
  });

  final Member currentMember;
  final MochiMood? selectedMood;
  final Map<String, MochiMood> familyCheckIns;
  final List<Member> members;
  final MochiMood petMood;
  final ValueChanged<MochiMood> onSelectMood;

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
                : 'Pick one of the 9 moods to nudge Mochi\'s shared state.',
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
                onTap: () => onSelectMood(mood),
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
        ],
      ),
    );
  }
}

class _FeedPanel extends StatelessWidget {
  const _FeedPanel({required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: pixelCardDecoration(MochiPalette.mint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _PanelTitle(
            title: 'Family activity feed',
            subtitle:
                'Chats, check-ins, and milestones stay visible from Home in this draft.',
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              'The feed wakes up after the first chat, mood check-in, or pet tap.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...entries.take(4).map((ActivityEntry entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FeedTile(entry: entry),
              );
            }),
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

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory});

  final MemorySnippet memory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: memory.accent.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(memory.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(memory.body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 6),
          Text(memory.timestamp, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
