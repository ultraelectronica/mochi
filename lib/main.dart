import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'models/auth_session.dart';
import 'models/member.dart';
import 'models/mood.dart';
import 'providers/member_provider.dart';
import 'providers/pet_provider.dart';
import 'screens/auth_screen.dart';
import 'services/floating_mochi_service.dart';
import 'services/api_service.dart';
import 'services/session_store.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mood_checkin_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/mood_checkin_sheet.dart';
import 'widgets/create_member_dialog.dart';
import 'widgets/mochi_bottom_nav_bar.dart';
import 'widgets/mochi_toast.dart';

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
  final ApiService _apiService = ApiService();
  late final PetProvider _petProvider;
  late final MemberProvider _memberProvider;
  final FloatingMochiService _floatingMochiService =
      const FloatingMochiService();

  int _selectedTabIndex = 1;
  bool _checkingAuth = true;
  bool _authBusy = false;
  bool _bootstrapping = true;
  String? _bootstrapError;
  AuthSession? _session;
  bool _didAutoShowMoodSheetThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _petProvider = PetProvider();
    _memberProvider = MemberProvider();
    _floatingMochiService.syncAppForegroundState(true);
    unawaited(_restoreSession());
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
        unawaited(_refreshRemoteState(reconnectRealtime: true));
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

  Future<void> _restoreSession() async {
    await SessionStore.instance.load();

    if (!SessionStore.instance.hasSession) {
      if (!mounted) {
        return;
      }

      setState(() {
        _checkingAuth = false;
        _bootstrapping = false;
      });
      return;
    }

    try {
      final AuthSession session = await _apiService.fetchSession();
      _applySession(session);
      await _bootstrap();
    } catch (error) {
      await SessionStore.instance.clearSessionToken();
      await _petProvider.clearSession();
      _memberProvider.clearSession();
      if (!mounted) {
        return;
      }

      setState(() {
        _session = null;
        _bootstrapError = null;
        _checkingAuth = false;
        _bootstrapping = false;
      });

      _showErrorToast(error, offlineOnly: true);
    }
  }

  void _applySession(AuthSession session) {
    _session = session;
    _memberProvider.configureSession(session);
  }

  Future<void> _bootstrap() async {
    if (mounted) {
      setState(() {
        _bootstrapping = true;
        _bootstrapError = null;
      });
    }

    try {
      await Future.wait<void>(<Future<void>>[
        _petProvider.initialize(),
        _memberProvider.loadMembers(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapError = null;
        _checkingAuth = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapError = _primaryErrorMessage(error);
      });

      _showErrorToast(error, offlineOnly: true);
    } finally {
      if (mounted) {
        setState(() {
          _bootstrapping = false;
        });
        _scheduleDailyMoodSheet();
      }
    }
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

  Future<void> _refreshRemoteState({bool reconnectRealtime = false}) async {
    try {
      await Future.wait<void>(<Future<void>>[
        _petProvider.refreshState(includeHealth: true, includeChat: true),
        _memberProvider.loadMembers(setLoading: false),
      ]);

      if (reconnectRealtime) {
        await _petProvider.reconnectRealtime();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapError = null;
      });
    } catch (error) {
      if (!mounted || _petProvider.hasPet) {
        return;
      }

      setState(() {
        _bootstrapError = _primaryErrorMessage(error);
      });

      _showErrorToast(error, offlineOnly: true);
    }
  }

  String _primaryErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return _petProvider.errorMessage ??
        _memberProvider.errorMessage ??
        error.toString().replaceFirst('Exception: ', '');
  }

  void _showToast(
    String message, {
    String? title,
    MochiToastTone tone = MochiToastTone.info,
    IconData? icon,
  }) {
    MochiToast.show(title: title, message: message, tone: tone, icon: icon);
  }

  void _showErrorToast(Object error, {bool offlineOnly = false}) {
    if (error is ApiException && error.isOffline) {
      _showToast(
        'Start the Mochi server at ${AppConfig.serverUrl}, then try again.',
        title: 'Mochi server offline',
        tone: MochiToastTone.warning,
        icon: Icons.cloud_off_rounded,
      );
      return;
    }

    if (offlineOnly) {
      return;
    }

    _showToast(
      _primaryErrorMessage(error),
      title: 'Something went sideways',
      tone: MochiToastTone.error,
      icon: Icons.sync_problem_rounded,
    );
  }

  Future<void> _handleAuthenticatedSession(AuthSession session) async {
    await SessionStore.instance.setSessionToken(session.sessionToken);
    _applySession(session);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTabIndex = 1;
      _checkingAuth = false;
      _bootstrapError = null;
    });

    await _bootstrap();
  }

  Future<void> _runAuthAction(Future<AuthSession> Function() action) async {
    if (_authBusy) {
      return;
    }

    setState(() {
      _authBusy = true;
      _bootstrapError = null;
    });

    try {
      final AuthSession session = await action();
      await _handleAuthenticatedSession(session);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapError = null;
      });

      _showErrorToast(error);
    } finally {
      if (mounted) {
        setState(() {
          _authBusy = false;
        });
      }
    }
  }

  Future<void> _handleBootstrap(BootstrapDraft draft) async {
    await _runAuthAction(
      () => _apiService.bootstrap(
        householdName: draft.householdName,
        adminName: draft.adminName,
        username: draft.username,
        password: draft.password,
        color: draft.color,
      ),
    );
  }

  Future<void> _handleLogin(LoginDraft draft) async {
    await _runAuthAction(
      () => _apiService.login(
        householdCode: draft.householdCode,
        username: draft.username,
        password: draft.password,
      ),
    );
  }

  Future<void> _handleInvite(InviteDraft draft) async {
    await _runAuthAction(
      () => _apiService.acceptInvite(
        inviteCode: draft.inviteCode,
        password: draft.password,
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _apiService.logout();
    } catch (_) {}

    await SessionStore.instance.clearSessionToken();
    await _petProvider.clearSession();
    _memberProvider.clearSession();

    if (!mounted) {
      return;
    }

    setState(() {
      _session = null;
      _bootstrapError = null;
      _selectedTabIndex = 1;
      _didAutoShowMoodSheetThisSession = false;
      _checkingAuth = false;
      _bootstrapping = false;
    });
  }

  Future<void> _handleSendMessage(String text) async {
    final Member member = _memberProvider.currentMember;

    try {
      await _petProvider.sendMessage(member: member, text: text);
      await _memberProvider.loadMembers(
        setLoading: false,
        preferredMemberId: member.id,
      );
    } catch (error) {
      if (mounted) {
        _showErrorToast(error);
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

      await _memberProvider.loadMembers(
        setLoading: false,
        preferredMemberId: member.id,
      );
      return true;
    } catch (error) {
      if (mounted) {
        _showErrorToast(error);
      }
      return false;
    }
  }

  Future<void> _handlePetTap() async {
    final Member member = _memberProvider.currentMember;

    try {
      await _petProvider.tapPet(member);
      await _memberProvider.loadMembers(
        setLoading: false,
        preferredMemberId: member.id,
      );
    } catch (error) {
      if (mounted) {
        _showErrorToast(error);
      }
    }
  }

  Future<void> _handleRefreshHistory() async {
    try {
      await _refreshRemoteState();
    } catch (error) {
      if (mounted) {
        _showErrorToast(error);
      }
    }
  }

  Future<void> _openCreateMemberDialog() async {
    if (!_memberProvider.isAdmin) {
      _showToast(
        'Only the household admin can create accounts.',
        title: 'Admin only',
        tone: MochiToastTone.warning,
        icon: Icons.admin_panel_settings_rounded,
      );
      return;
    }

    final MemberDraft? draft = await showDialog<MemberDraft>(
      context: context,
      builder: (BuildContext context) => const CreateMemberDialog(),
    );

    if (draft == null || !mounted) {
      return;
    }

    try {
      final CreatedMemberInvite created = await _memberProvider.createMember(
        name: draft.name,
        username: draft.username,
        color: draft.color,
      );
      if (_petProvider.hasPet) {
        await _petProvider.refreshState(
          includeHealth: false,
          includeChat: false,
        );
      }
      if (mounted) {
        await _showInviteCodeDialog(created);
      }
    } catch (error) {
      if (mounted) {
        _showErrorToast(error);
      }
    }
  }

  Future<void> _showInviteCodeDialog(CreatedMemberInvite created) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${created.member.name} account created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Username: ${created.member.username}'),
              const SizedBox(height: 8),
              Text('Invite code: ${created.inviteCode}'),
              const SizedBox(height: 8),
              Text('Household code: ${_session?.household.code ?? ''}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'Invite code: ${created.inviteCode}\nHousehold code: ${_session?.household.code ?? ''}\nUsername: ${created.member.username}',
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                _showToast(
                  'Invite details copied.',
                  title: 'Copied',
                  tone: MochiToastTone.success,
                  icon: Icons.content_copy_rounded,
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
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
        if (_checkingAuth) {
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
                          title: 'Checking session',
                          subtitle:
                              'Looking for your saved household account before Mochi syncs the rest of the app.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (_session == null) {
          return AuthScreen(
            isBusy: _authBusy,
            errorMessage: null,
            onBootstrap: _handleBootstrap,
            onLogin: _handleLogin,
            onAcceptInvite: _handleInvite,
          );
        }

        if (_bootstrapping) {
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
                          title: 'Syncing Mochi',
                          subtitle:
                              'Loading the shared pet, family members, and recent moments from the server.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!_petProvider.hasPet) {
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
                          title: 'Mochi could not connect',
                          subtitle:
                              _bootstrapError ??
                              'Check the server URL, make sure the backend is running, then try again.',
                          actionLabel: 'Retry sync',
                          onPressed: _bootstrap,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (!_memberProvider.hasMembers) {
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
                          title: 'Create the first family member',
                          subtitle:
                              'Mochi is online, but nobody has joined the shared room yet. Add the first profile to start chatting and checking in.',
                          actionLabel: _memberProvider.isCreating
                              ? 'Adding member...'
                              : 'Add first member',
                          onPressed: _memberProvider.isCreating
                              ? null
                              : _openCreateMemberDialog,
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
            session: _session!,
            petProvider: _petProvider,
            memberProvider: _memberProvider,
            onCreateMember: _openCreateMemberDialog,
            onLogout: _handleLogout,
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
                            session: _session!,
                            memberProvider: _memberProvider,
                            petProvider: _petProvider,
                            onCreateMember: _openCreateMemberDialog,
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
              Expanded(child: Text('Talking to the shared Mochi server...')),
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
  final Future<void> Function(String text) onSendMessage;
  final Future<void> Function() onRefreshHistory;

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
                        onRefreshHistory: onRefreshHistory,
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
    required this.session,
    required this.memberProvider,
    required this.petProvider,
    required this.onCreateMember,
  });

  final AuthSession session;
  final MemberProvider memberProvider;
  final PetProvider petProvider;
  final VoidCallback onCreateMember;

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
                  householdCode: widget.session.household.code,
                  onExpand: () => _setCollapsed(false),
                )
              : _ExpandedHeader(
                  session: widget.session,
                  memberProvider: widget.memberProvider,
                  petProvider: widget.petProvider,
                  onCreateMember: widget.onCreateMember,
                  onCollapse: () => _setCollapsed(true),
                ),
        ),
      ),
    );
  }
}

class _ExpandedHeader extends StatelessWidget {
  const _ExpandedHeader({
    required this.session,
    required this.memberProvider,
    required this.petProvider,
    required this.onCreateMember,
    required this.onCollapse,
  });

  final AuthSession session;
  final MemberProvider memberProvider;
  final PetProvider petProvider;
  final VoidCallback onCreateMember;
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
                    '${session.household.name} • code ${session.household.code}',
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
            const SizedBox(width: 8),
            if (memberProvider.isAdmin)
              InkWell(
                onTap: onCreateMember,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MochiPalette.ink, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: MochiPalette.ink,
                  ),
                ),
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
              final bool selected =
                  member.id == memberProvider.currentMember.id;
              final MochiMood? mood = petProvider.moodForMember(member.id);
              return AnimatedContainer(
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              member.name,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            if (member.isAdmin) ...<Widget>[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          mood?.label ??
                              (member.invitePending
                                  ? 'Invite pending'
                                  : 'Ready'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        _DragHandle(
          label: 'Drag up to hide household roster',
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
    required this.householdCode,
    required this.onExpand,
  });

  final Member currentMember;
  final int memberCount;
  final String householdCode;
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
                    '$memberCount accounts • ${currentMember.name} • $householdCode',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _DragHandle(
          label: 'Drag down to show household roster',
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
