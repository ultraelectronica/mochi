import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'models/member.dart';
import 'models/mood.dart';
import 'providers/member_provider.dart';
import 'providers/pet_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/mochi_bottom_nav_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MochiApp());
}

class MochiApp extends StatelessWidget {
  const MochiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appTitle,
      theme: buildMochiTheme(),
      home: const MochiShell(),
    );
  }
}

class MochiShell extends StatefulWidget {
  const MochiShell({super.key});

  @override
  State<MochiShell> createState() => _MochiShellState();
}

class _MochiShellState extends State<MochiShell> {
  late final PetProvider _petProvider;
  late final MemberProvider _memberProvider;

  int _selectedTabIndex = 1;

  @override
  void initState() {
    super.initState();
    _petProvider = PetProvider();
    _memberProvider = MemberProvider.seeded();
  }

  @override
  void dispose() {
    _petProvider.dispose();
    _memberProvider.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage(String text) async {
    final Member member = _memberProvider.currentMember;
    _memberProvider.rewardCurrentMember(xp: 10, affection: 5);
    await _petProvider.sendMessage(member: member, text: text);
  }

  void _handleMoodCheckIn(MochiMood mood) {
    final Member member = _memberProvider.currentMember;
    final bool applied = _petProvider.checkIn(member: member, mood: mood);
    if (applied) {
      _memberProvider.rewardCurrentMember(xp: 5, affection: 2);
    }
  }

  void _handlePetTap() {
    final Member member = _memberProvider.currentMember;
    _petProvider.tapPet(member.name);
    _memberProvider.rewardCurrentMember(xp: 2, affection: 1);
  }

  void _openFullscreenChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _FullscreenChatScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
            onSendMessage: _handleSendMessage,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_petProvider, _memberProvider]),
      builder: (BuildContext context, Widget? child) {
        final List<Widget> tabs = <Widget>[
          ChatScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
            onSendMessage: _handleSendMessage,
            onToggleFullscreen: _openFullscreenChat,
          ),
          HomeScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
            onPetTap: _handlePetTap,
            onCheckInMood: _handleMoodCheckIn,
            onOpenChat: () => setState(() => _selectedTabIndex = 0),
          ),
          SettingsScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
          ),
        ];

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: <Widget>[
              const Positioned.fill(child: _PixelBackdrop()),
              SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                          child: _HeaderCard(
                            memberProvider: _memberProvider,
                            petProvider: _petProvider,
                            onMemberSelected: _memberProvider.selectMember,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              MochiBottomNavBar.overlayPadding(context),
                            ),
                            child: IndexedStack(
                              index: _selectedTabIndex,
                              children: tabs,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MochiBottomNavBar(
                  selectedIndex: _selectedTabIndex,
                  onSelected: (int index) {
                    setState(() => _selectedTabIndex = index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullscreenChatScreen extends StatelessWidget {
  const _FullscreenChatScreen({
    required this.petProvider,
    required this.memberProvider,
    required this.onSendMessage,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final Future<void> Function(String text) onSendMessage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[petProvider, memberProvider]),
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          body: Stack(
            children: <Widget>[
              const Positioned.fill(child: _PixelBackdrop()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: ChatScreen(
                        petProvider: petProvider,
                        memberProvider: memberProvider,
                        onSendMessage: onSendMessage,
                        isFullscreen: true,
                        onToggleFullscreen: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatefulWidget {
  const _HeaderCard({
    required this.memberProvider,
    required this.petProvider,
    required this.onMemberSelected,
  });

  final MemberProvider memberProvider;
  final PetProvider petProvider;
  final ValueChanged<int> onMemberSelected;

  @override
  State<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends State<_HeaderCard> {
  bool _collapsed = false;
  double _dragDelta = 0;

  void _setCollapsed(bool value) {
    if (_collapsed == value) {
      return;
    }
    setState(() {
      _collapsed = value;
    });
  }

  void _onDragStart(DragStartDetails details) {
    _dragDelta = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDelta += details.delta.dy;
    if (!_collapsed && _dragDelta < -24) {
      _setCollapsed(true);
      _dragDelta = 0;
    } else if (_collapsed && _dragDelta > 24) {
      _setCollapsed(false);
      _dragDelta = 0;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity < -180) {
      _setCollapsed(true);
    } else if (velocity > 180) {
      _setCollapsed(false);
    }
    _dragDelta = 0;
  }

  @override
  Widget build(BuildContext context) {
    final Member currentMember = widget.memberProvider.currentMember;

    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: EdgeInsets.fromLTRB(18, _collapsed ? 12 : 16, 18, 12),
          decoration: pixelCardDecoration(MochiPalette.cloudBlue),
          child: _collapsed
              ? _CollapsedHeader(
                  currentMember: currentMember,
                  memberCount: widget.memberProvider.members.length,
                  onExpand: () => _setCollapsed(false),
                )
              : _ExpandedHeader(
                  memberProvider: widget.memberProvider,
                  petProvider: widget.petProvider,
                  onMemberSelected: widget.onMemberSelected,
                  onCollapse: () => _setCollapsed(true),
                ),
        ),
      ),
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({
    required this.memberProvider,
    required this.petProvider,
    required this.onMemberSelected,
    required this.onCollapse,
  });

  final MemberProvider memberProvider;
  final PetProvider petProvider;
  final ValueChanged<int> onMemberSelected;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: MochiPalette.yellow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MochiPalette.ink, width: 2.5),
              ),
              child: const Icon(Icons.pets_rounded, color: MochiPalette.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppConfig.appTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Shared AI companion pet with warm, colorful family rituals.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _InfoBadge(
              label: petProvider.serverOnline ? 'Online' : 'Fallback',
              color: petProvider.serverOnline
                  ? MochiPalette.mint
                  : MochiPalette.peach,
              icon: petProvider.serverOnline
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List<Widget>.generate(memberProvider.members.length, (
              int index,
            ) {
              final Member member = memberProvider.members[index];
              final bool selected = memberProvider.selectedIndex == index;
              final MochiMood? mood = petProvider.moodForMember(member.name);
              return InkWell(
                onTap: () => onMemberSelected(index),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? member.color.withValues(alpha: 0.28)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MochiPalette.ink, width: 2.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: member.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: MochiPalette.ink, width: 2),
                        ),
                        child: Text(
                          member.initials,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            member.name,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            mood?.label ?? 'Ready',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        _DragHandle(
          label: 'Drag up to hide members',
          icon: Icons.keyboard_arrow_up_rounded,
          onTap: onCollapse,
        ),
      ],
    );
  }
}

class _CollapsedHeader extends StatelessWidget {
  const _CollapsedHeader({
    required this.currentMember,
    required this.memberCount,
    required this.onExpand,
  });

  final Member currentMember;
  final int memberCount;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: MochiPalette.yellow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MochiPalette.ink, width: 2),
              ),
              child: const Icon(Icons.pets_rounded, color: MochiPalette.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Mochi', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '$memberCount members ready • ${currentMember.name} selected',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _DragHandle(
          label: 'Drag down to show members',
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: onExpand,
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 6,
              decoration: BoxDecoration(
                color: MochiPalette.ink.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: MochiPalette.ink),
                const SizedBox(width: 4),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
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

class _PixelBackdrop extends StatelessWidget {
  const _PixelBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _PixelBackdropPainter()));
  }
}

class _PixelBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = MochiPalette.background;
    canvas.drawRect(Offset.zero & size, fill);

    final List<Color> colors = <Color>[
      MochiPalette.cloudBlue.withValues(alpha: 0.42),
      MochiPalette.lightPink.withValues(alpha: 0.36),
      MochiPalette.yellow.withValues(alpha: 0.34),
      MochiPalette.mint.withValues(alpha: 0.32),
    ];

    const double step = 48;
    const double pixel = 8;

    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final int colorIndex =
            (((x / step).round()) + ((y / step).round())) % colors.length;
        final Paint squarePaint = Paint()
          ..isAntiAlias = false
          ..color = colors[colorIndex];
        final double offsetX = x + (colorIndex * 3);
        final double offsetY = y + (((colorIndex + 1) % 3) * 3);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, pixel, pixel),
          squarePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
