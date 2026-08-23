import 'dart:async';

import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'models/member.dart';
import 'models/mood.dart';
import 'providers/member_provider.dart';
import 'providers/pet_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mood_checkin_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'services/floating_mochi_service.dart';
import 'services/local_llm/model_manager.dart';
import 'widgets/mochi_bottom_nav_bar.dart';
import 'widgets/mochi_toast.dart';
import 'widgets/mood_checkin_sheet.dart';

Future<void> main() async {
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
      builder: (BuildContext context, Widget? child) {
        return MochiToastHost(
          key: mochiToastHostKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MochiShell(),
    );
  }
}

class MochiShell extends StatefulWidget {
  const MochiShell({super.key});

  @override
  State<MochiShell> createState() => _MochiShellState();
}

class _MochiShellState extends State<MochiShell> with WidgetsBindingObserver {
  late final PetProvider _petProvider;
  late final MemberProvider _memberProvider;
  final FloatingMochiService _floatingMochiService =
      const FloatingMochiService();

  int _selectedTabIndex = 1;
  bool _checkingLocal = true;
  String? _bootstrapError;
  bool _didAutoShowMoodSheetThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _petProvider = PetProvider();
    _memberProvider = MemberProvider();
    _floatingMochiService.syncAppForegroundState(true);
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _floatingMochiService.syncAppForegroundState(true);
    _petProvider.dispose();
    _memberProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _floatingMochiService.syncAppForegroundState(true);
        if (!_checkingLocal && _petProvider.hasPet) {
          unawaited(_petProvider.brushUp());
          unawaited(_memberProvider.loadMembers(setLoading: false));
        }
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _floatingMochiService.syncAppForegroundState(false);
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        return;
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _petProvider.initialize();
      await _memberProvider.initialize();

      if (!mounted) {
        return;
      }
      setState(() {
        _checkingLocal = false;
        _bootstrapError = null;
      });
      _scheduleDailyMoodSheet();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingLocal = false;
        _bootstrapError = error.toString();
      });
    }
  }

  Future<void> _finishOnboarding() async {
    await _petProvider.initialize();
    await _memberProvider.initialize();
    if (!_petProvider.hasPet || !_memberProvider.hasMembers) {
      throw StateError('World setup did not create a profile.');
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _bootstrapError = null;
    });
    _scheduleDailyMoodSheet();
  }

  void _scheduleDailyMoodSheet() {
    if (_didAutoShowMoodSheetThisSession) {
      return;
    }
    if (!_petProvider.hasPet || !_memberProvider.hasMembers) {
      return;
    }
    if (_petProvider.moodForMember(_memberProvider.currentMember.id) != null) {
      return;
    }
    _didAutoShowMoodSheetThisSession = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_showMoodCheckInSheet());
    });
  }

  Future<void> _showMoodCheckInSheet() async {
    await showMoodCheckinSheet(
      context,
      petProvider: _petProvider,
      memberProvider: _memberProvider,
      onSubmitMood: _handleMoodCheckIn,
    );
  }

  void _pushMoodCheckInScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MoodCheckinScreen(
          petProvider: _petProvider,
          memberProvider: _memberProvider,
          onSubmitMood: _handleMoodCheckIn,
        ),
      ),
    );
  }

  void _showToast(
    String message, {
    String? title,
    MochiToastTone tone = MochiToastTone.info,
    IconData? icon,
  }) {
    MochiToast.show(title: title, message: message, tone: tone, icon: icon);
  }

  Future<void> _handleSendMessage(
    String text, {
    String inputType = 'text',
  }) async {
    final Member member = _memberProvider.currentMember;

    try {
      await _petProvider.sendMessage(
        member: member,
        text: text,
        inputType: inputType,
      );
    } catch (error) {
      if (mounted) {
        _showToast(
          error.toString(),
          title: 'A tiny hiccup',
          tone: MochiToastTone.error,
          icon: Icons.sync_problem_rounded,
        );
      }
    }
  }

  Future<bool> _handleMoodCheckIn(MochiMood mood) async {
    final Member member = _memberProvider.currentMember;

    try {
      final bool applied = await _petProvider.checkIn(
        member: member,
        mood: mood,
      );
      if (!applied) {
        if (mounted) {
          _showToast(
            '${member.name} already checked in today.',
            title: 'Mood already logged',
            tone: MochiToastTone.info,
            icon: Icons.event_available_rounded,
          );
        }
        return false;
      }
      return true;
    } catch (error) {
      if (mounted) {
        _showToast(
          error.toString(),
          title: 'A tiny hiccup',
          tone: MochiToastTone.error,
          icon: Icons.sync_problem_rounded,
        );
      }
      return false;
    }
  }

  Future<void> _handlePetTap() async {
    final Member member = _memberProvider.currentMember;

    try {
      await _petProvider.tapPet(member);
    } catch (error) {
      if (mounted) {
        _showToast(
          error.toString(),
          title: 'A tiny hiccup',
          tone: MochiToastTone.error,
          icon: Icons.sync_problem_rounded,
        );
      }
    }
  }

  Future<void> _handleRefreshHistory() async {
    await _petProvider.refreshState(force: true);
  }

  void _openFullscreenChat() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _FullscreenChatScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
            onSendMessage: _handleSendMessage,
            onRefreshHistory: _handleRefreshHistory,
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
        if (_checkingLocal) {
          return Scaffold(
            body: Stack(
              children: <Widget>[
                const Positioned.fill(child: _PixelBackdrop()),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: _StartupCard(
                          title: 'Waking up Mochi',
                          subtitle:
                              'Loading the local room, memories, and mood from this device.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!_petProvider.hasPet || !_memberProvider.hasMembers) {
          return OnboardingScreen(onComplete: _finishOnboarding);
        }

        if (_bootstrapError != null) {
          return Scaffold(
            body: Stack(
              children: <Widget>[
                const Positioned.fill(child: _PixelBackdrop()),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _ActionCard(
                          title: 'Mochi could not start',
                          subtitle: _bootstrapError!,
                          actionLabel: 'Retry',
                          onPressed: () {
                            setState(() {
                              _checkingLocal = true;
                              _bootstrapError = null;
                            });
                            unawaited(_bootstrap());
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final List<Widget> tabs = <Widget>[
          ChatScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
            onSendMessage: _handleSendMessage,
            onRefreshHistory: _handleRefreshHistory,
            onToggleFullscreen: _openFullscreenChat,
          ),
          HomeScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
            onPetTap: () {
              unawaited(_handlePetTap());
            },
            onOpenMoodCheckInSheet: () {
              unawaited(_showMoodCheckInSheet());
            },
            onOpenMoodCheckInFullScreen: _pushMoodCheckInScreen,
            onOpenChat: () => setState(() => _selectedTabIndex = 0),
          ),
          SettingsScreen(
            petProvider: _petProvider,
            memberProvider: _memberProvider,
          ),
        ];

        // The backdrop lives outside the Scaffold so the keyboard inset
        // animation resizes only the body — the backdrop never relayouts or
        // repaints while typing.
        return Stack(
          children: <Widget>[
            const Positioned.fill(
              child: RepaintBoundary(child: _PixelBackdrop()),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              body: Stack(
                children: <Widget>[
                  SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                10,
                              ),
                              child: _HeaderCard(
                                memberProvider: _memberProvider,
                                petProvider: _petProvider,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  0,
                                ),
                                child: IndexedStack(
                                  index: _selectedTabIndex,
                                  children: <Widget>[
                                    for (int i = 0; i < tabs.length; i++)
                                      TickerMode(
                                        enabled: i == _selectedTabIndex,
                                        child: tabs[i],
                                      ),
                                  ],
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
                    child: _AutoHideBottomNav(
                      child: MochiBottomNavBar(
                        selectedIndex: _selectedTabIndex,
                        onSelected: (int index) {
                          setState(() => _selectedTabIndex = index);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Slides the nav pill offscreen while the keyboard is up: frees screen space
// for the composer and keeps the BackdropFilter blur out of the keyboard
// inset animation. Only this subtree rebuilds per inset frame.
class _AutoHideBottomNav extends StatelessWidget {
  const _AutoHideBottomNav({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return IgnorePointer(
      ignoring: keyboardOpen,
      child: AnimatedSlide(
        offset: keyboardOpen ? const Offset(0, 1.4) : Offset.zero,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

class _StartupCard extends StatelessWidget {
  const _StartupCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: pixelCardDecoration(MochiPalette.cloudBlue),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          const Row(
            children: <Widget>[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Reading this device...')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: pixelCardDecoration(MochiPalette.lightPink),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _FullscreenChatScreen extends StatelessWidget {
  const _FullscreenChatScreen({
    required this.petProvider,
    required this.memberProvider,
    required this.onSendMessage,
    required this.onRefreshHistory,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final Future<void> Function(String text, {String inputType}) onSendMessage;
  final Future<void> Function() onRefreshHistory;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[petProvider, memberProvider]),
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            const Positioned.fill(
              child: RepaintBoundary(child: _PixelBackdrop()),
            ),
            Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: ChatScreen(
                        petProvider: petProvider,
                        memberProvider: memberProvider,
                        onSendMessage: onSendMessage,
                        onRefreshHistory: onRefreshHistory,
                        isFullscreen: true,
                        onToggleFullscreen: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.memberProvider, required this.petProvider});

  final MemberProvider memberProvider;
  final PetProvider petProvider;

  @override
  Widget build(BuildContext context) {
    final Member currentMember = memberProvider.currentMember;
    final String petName = petProvider.pet.name;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: pixelCardDecoration(MochiPalette.cloudBlue),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MochiPalette.yellow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: const Icon(
              Icons.pets_rounded,
              size: 20,
              color: MochiPalette.ink,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$petName \u00b7 ${petProvider.pet.mood.label}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 17),
                ),
                Text(
                  'Your ${currentMember.name} \u00b7 on-device companion',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: ModelManager.instance,
            builder: (BuildContext context, Widget? child) {
              final bool downloading = ModelManager.instance.state.isActive;
              return _InfoBadge(
                label: petProvider.llamaOnline
                    ? 'AI ready'
                    : downloading
                    ? 'Downloading brain'
                    : 'AI offline',
                color: petProvider.llamaOnline
                    ? MochiPalette.mint
                    : downloading
                    ? MochiPalette.yellow
                    : MochiPalette.peach,
                icon: petProvider.llamaOnline
                    ? Icons.psychology_rounded
                    : downloading
                    ? Icons.download_rounded
                    : Icons.psychology_alt_rounded,
              );
            },
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MochiPalette.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: MochiPalette.ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 11),
          ),
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
