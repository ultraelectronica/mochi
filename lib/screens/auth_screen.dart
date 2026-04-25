import 'package:flutter/material.dart';

import '../config/app_config.dart';

class BootstrapDraft {
  const BootstrapDraft({
    required this.householdName,
    required this.adminName,
    required this.username,
    required this.password,
    required this.color,
  });

  final String householdName;
  final String adminName;
  final String username;
  final String password;
  final Color color;
}

class LoginDraft {
  const LoginDraft({
    required this.householdCode,
    required this.username,
    required this.password,
  });

  final String householdCode;
  final String username;
  final String password;
}

class InviteDraft {
  const InviteDraft({required this.inviteCode, required this.password});

  final String inviteCode;
  final String password;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.isBusy,
    required this.errorMessage,
    required this.onBootstrap,
    required this.onLogin,
    required this.onAcceptInvite,
  });

  final bool isBusy;
  final String? errorMessage;
  final Future<void> Function(BootstrapDraft draft) onBootstrap;
  final Future<void> Function(LoginDraft draft) onLogin;
  final Future<void> Function(InviteDraft draft) onAcceptInvite;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  static const List<_AuthTabSpec> _tabs = <_AuthTabSpec>[
    _AuthTabSpec(
      label: 'Sign in',
      title: 'Welcome back',
      subtitle: 'Use the household code plus your own username and password.',
      accent: MochiPalette.cloudBlue,
      icon: Icons.login_rounded,
      formHeight: 448,
    ),
    _AuthTabSpec(
      label: 'Create home',
      title: 'Start a new home',
      subtitle:
          'The first account becomes the admin and handles everyone else\'s accounts.',
      accent: MochiPalette.lightPink,
      icon: Icons.home_work_rounded,
      formHeight: 620,
    ),
    _AuthTabSpec(
      label: 'Use invite',
      title: 'Claim your invite',
      subtitle:
          'Finish the account the household admin already created for you.',
      accent: MochiPalette.yellow,
      icon: Icons.mail_outline_rounded,
      formHeight: 410,
    ),
  ];

  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _PixelBackdrop()),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool wide = constraints.maxWidth >= 880;
                            return wide && !keyboardOpen
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      const Expanded(
                                        flex: 11,
                                        child: _AuthHero(),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        flex: 9,
                                        child: _AuthCard(
                                          tabController: _tabController,
                                          tabs: _tabs,
                                          isBusy: widget.isBusy,
                                          errorMessage: widget.errorMessage,
                                          onBootstrap: widget.onBootstrap,
                                          onLogin: widget.onLogin,
                                          onAcceptInvite: widget.onAcceptInvite,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const _AuthHero(compact: true),
                                      const SizedBox(height: 16),
                                      _AuthCard(
                                        tabController: _tabController,
                                        tabs: _tabs,
                                        isBusy: widget.isBusy,
                                        errorMessage: widget.errorMessage,
                                        onBootstrap: widget.onBootstrap,
                                        onLogin: widget.onLogin,
                                        onAcceptInvite: widget.onAcceptInvite,
                                      ),
                                    ],
                                  );
                          },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabSpec {
  const _AuthTabSpec({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.formHeight,
  });

  final String label;
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final double formHeight;
}

class _AuthHero extends StatefulWidget {
  const _AuthHero({this.compact = false});

  final bool compact;

  @override
  State<_AuthHero> createState() => _AuthHeroState();
}

class _AuthHeroState extends State<_AuthHero> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final bool collapsed = widget.compact && _collapsed;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: EdgeInsets.all(widget.compact ? (collapsed ? 14 : 20) : 28),
        decoration: pixelCardDecoration(MochiPalette.lightPink),
        child: collapsed ? _buildCollapsed(context) : _buildExpanded(context),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: MochiPalette.yellow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MochiPalette.ink, width: 2.5),
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: MochiPalette.ink,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'One Mochi per home.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: _AuthHeroHandle(
            label: 'Tap to expand',
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => setState(() => _collapsed = false),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: widget.compact ? 62 : 76,
              height: widget.compact ? 62 : 76,
              decoration: BoxDecoration(
                color: MochiPalette.yellow,
                borderRadius:
                    BorderRadius.circular(widget.compact ? 20 : 22),
                border: Border.all(color: MochiPalette.ink, width: 3),
              ),
              child: Icon(
                Icons.pets_rounded,
                size: widget.compact ? 30 : 36,
                color: MochiPalette.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: <Widget>[
                  _HeroChip(label: 'Admin-only', icon: Icons.key_rounded),
                  const SizedBox(width: 8),
                  _HeroChip(
                      label: 'One pet/home', icon: Icons.home_rounded),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: widget.compact ? 18 : 22),
        Text(
          'One Mochi per home.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          'Sign into your household, create a fresh one, or finish an invite without mixing anyone else\'s feed, mood log, or roster.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        const Row(
          children: <Widget>[
            Expanded(
              child: _HeroRoomCard(
                title: 'Maple House',
                subtitle: '3 accounts • happy Mochi',
                accent: MochiPalette.cloudBlue,
                icon: Icons.wb_sunny_outlined,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _HeroRoomCard(
                title: 'Moon Nest',
                subtitle: '2 accounts • sleepy Mochi',
                accent: MochiPalette.mint,
                icon: Icons.nights_stay_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MochiPalette.ink, width: 2.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MochiPalette.lavender,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MochiPalette.ink, width: 2),
                ),
                child:
                    const Icon(Icons.dns_rounded, color: MochiPalette.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Current server target',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppConfig.serverUrl,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.compact) ...<Widget>[
          const SizedBox(height: 12),
          Center(
            child: _AuthHeroHandle(
              label: 'Tap to minimize',
              icon: Icons.keyboard_arrow_up_rounded,
              onTap: () => setState(() => _collapsed = true),
            ),
          ),
        ],
      ],
    );
  }
}

class _AuthHeroHandle extends StatelessWidget {
  const _AuthHeroHandle({
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: MochiPalette.ink),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _HeroRoomCard extends StatelessWidget {
  const _HeroRoomCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: pixelCardDecoration(accent),
      child: Column(
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
            child: Icon(icon, color: MochiPalette.ink),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.tabController,
    required this.tabs,
    required this.isBusy,
    required this.errorMessage,
    required this.onBootstrap,
    required this.onLogin,
    required this.onAcceptInvite,
  });

  final TabController tabController;
  final List<_AuthTabSpec> tabs;
  final bool isBusy;
  final String? errorMessage;
  final Future<void> Function(BootstrapDraft draft) onBootstrap;
  final Future<void> Function(LoginDraft draft) onLogin;
  final Future<void> Function(InviteDraft draft) onAcceptInvite;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (BuildContext context, Widget? child) {
        final int index = tabController.index.clamp(0, tabs.length - 1);
        final _AuthTabSpec current = tabs[index];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: pixelCardDecoration(current.accent),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          current.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          current.subtitle,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: MochiPalette.ink, width: 2.5),
                    ),
                    child: Icon(current.icon, color: MochiPalette.ink),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AuthTabBar(
                tabController: tabController,
                tabs: tabs,
                accent: current.accent,
              ),
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: 14),
                _InfoNote(
                  accent: MochiPalette.peach,
                  icon: Icons.sync_problem_rounded,
                  title: 'Last error',
                  body: errorMessage!,
                ),
              ],
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: current.formHeight,
                child: TabBarView(
                  controller: tabController,
                  children: <Widget>[
                    _LoginForm(isBusy: isBusy, onSubmit: onLogin),
                    _BootstrapForm(isBusy: isBusy, onSubmit: onBootstrap),
                    _InviteForm(isBusy: isBusy, onSubmit: onAcceptInvite),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuthTabBar extends StatelessWidget {
  const _AuthTabBar({
    required this.tabController,
    required this.tabs,
    required this.accent,
  });

  final TabController tabController;
  final List<_AuthTabSpec> tabs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MochiPalette.ink, width: 2.5),
      ),
      child: TabBar(
        controller: tabController,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashBorderRadius: BorderRadius.circular(16),
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: accent.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MochiPalette.ink, width: 2),
        ),
        labelColor: MochiPalette.ink,
        unselectedLabelColor: MochiPalette.ink.withValues(alpha: 0.62),
        labelStyle: Theme.of(context).textTheme.labelLarge,
        unselectedLabelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: MochiPalette.ink.withValues(alpha: 0.62),
        ),
        tabs: tabs
            .map(
              (_AuthTabSpec tab) => SizedBox(
                height: 54,
                child: Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(tab.icon, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(tab.label)),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.isBusy, required this.onSubmit});

  final bool isBusy;
  final Future<void> Function(LoginDraft draft) onSubmit;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  late final TextEditingController _householdController =
      TextEditingController();
  late final TextEditingController _usernameController =
      TextEditingController();
  late final TextEditingController _passwordController =
      TextEditingController();

  @override
  void dispose() {
    _householdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSubmit(
      LoginDraft(
        householdCode: _householdController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: _FormScaffold(
        title: 'Sign into your household',
        subtitle:
            'This keeps your own home\'s Mochi, feed, and member list isolated from every other home.',
        isBusy: widget.isBusy,
        buttonLabel: 'Sign in',
        onSubmit: _submit,
        note: const _InfoNote(
          accent: MochiPalette.cloudBlue,
          icon: Icons.key_rounded,
          title: 'What you need',
          body:
              'Ask the household admin for the household code, your username, and your invite if this is your first time signing in.',
        ),
        children: <Widget>[
          _AuthField(
            controller: _householdController,
            label: 'Household code',
            hint: '6-character home code',
            icon: Icons.home_work_rounded,
            textCapitalization: TextCapitalization.characters,
            autofillHints: const <String>[AutofillHints.organizationName],
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _usernameController,
            label: 'Username',
            hint: '@you',
            icon: Icons.alternate_email_rounded,
            autofillHints: const <String>[AutofillHints.username],
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Your account password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.password],
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

class _BootstrapForm extends StatefulWidget {
  const _BootstrapForm({required this.isBusy, required this.onSubmit});

  final bool isBusy;
  final Future<void> Function(BootstrapDraft draft) onSubmit;

  @override
  State<_BootstrapForm> createState() => _BootstrapFormState();
}

class _BootstrapFormState extends State<_BootstrapForm> {
  late final TextEditingController _householdController =
      TextEditingController();
  late final TextEditingController _adminController = TextEditingController();
  late final TextEditingController _usernameController =
      TextEditingController();
  late final TextEditingController _passwordController =
      TextEditingController();
  final List<Color> _colors = const <Color>[
    MochiPalette.sky,
    Color(0xFFFFAFCB),
    Color(0xFFFFD466),
    Color(0xFFA9E6BE),
    MochiPalette.lavender,
    Color(0xFF7EB8F3),
  ];
  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _householdController.dispose();
    _adminController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSubmit(
      BootstrapDraft(
        householdName: _householdController.text.trim(),
        adminName: _adminController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        color: _colors[_selectedColorIndex],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: _FormScaffold(
        title: 'Create the admin household',
        subtitle:
            'This first account becomes the admin. It\'s the only account that can create everybody else.',
        isBusy: widget.isBusy,
        buttonLabel: 'Create household',
        onSubmit: _submit,
        note: const _InfoNote(
          accent: MochiPalette.lightPink,
          icon: Icons.admin_panel_settings_rounded,
          title: 'Admin powers',
          body:
              'The admin account creates the roster, hands out invite codes, and keeps household membership locked down.',
        ),
        children: <Widget>[
          _AuthField(
            controller: _householdController,
            label: 'Household name',
            hint: 'Maple House',
            icon: Icons.home_rounded,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _adminController,
            label: 'Your name',
            hint: 'Arne',
            icon: Icons.badge_outlined,
            autofillHints: const <String>[AutofillHints.name],
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _usernameController,
            label: 'Admin username',
            hint: '@admin',
            icon: Icons.alternate_email_rounded,
            autofillHints: const <String>[AutofillHints.username],
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create a password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          Text(
            'Pick your avatar color',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List<Widget>.generate(_colors.length, (int index) {
              final bool selected = index == _selectedColorIndex;
              return InkWell(
                onTap: () => setState(() => _selectedColorIndex = index),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _colors[index],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MochiPalette.ink,
                      width: selected ? 3.5 : 2,
                    ),
                    boxShadow: selected
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x3328324E),
                              blurRadius: 0,
                              offset: Offset(2, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _InviteForm extends StatefulWidget {
  const _InviteForm({required this.isBusy, required this.onSubmit});

  final bool isBusy;
  final Future<void> Function(InviteDraft draft) onSubmit;

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  late final TextEditingController _inviteController = TextEditingController();
  late final TextEditingController _passwordController =
      TextEditingController();

  @override
  void dispose() {
    _inviteController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.onSubmit(
      InviteDraft(
        inviteCode: _inviteController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: _FormScaffold(
        title: 'Finish an invite',
        subtitle:
            'Paste the invite code from the household admin, then set the password you\'ll use from now on.',
        isBusy: widget.isBusy,
        buttonLabel: 'Accept invite',
        onSubmit: _submit,
        note: const _InfoNote(
          accent: MochiPalette.yellow,
          icon: Icons.mark_email_read_outlined,
          title: 'Invite flow',
          body:
              'Invite codes are single-use. After you claim the account, sign in normally with your household code and username.',
        ),
        children: <Widget>[
          _AuthField(
            controller: _inviteController,
            label: 'Invite code',
            hint: '10-character invite',
            icon: Icons.mail_outline_rounded,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          _AuthField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create your password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.newPassword],
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({
    required this.title,
    required this.subtitle,
    required this.isBusy,
    required this.buttonLabel,
    required this.onSubmit,
    required this.children,
    required this.note,
  });

  final String title;
  final String subtitle;
  final bool isBusy;
  final String buttonLabel;
  final Future<void> Function() onSubmit;
  final List<Widget> children;
  final Widget note;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 16),
          note,
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onSubmit,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: MochiPalette.ink),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: pixelCardDecoration(accent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MochiPalette.ink, width: 2),
            ),
            child: Icon(icon, size: 20, color: MochiPalette.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            MochiPalette.background,
            MochiPalette.sky.withValues(alpha: 0.22),
            MochiPalette.lavender.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(painter: _PixelBackdropPainter()),
    );
  }
}

class _PixelBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint dot = Paint();
    final List<Color> colors = <Color>[
      MochiPalette.cloudBlue.withValues(alpha: 0.32),
      MochiPalette.lightPink.withValues(alpha: 0.28),
      MochiPalette.yellow.withValues(alpha: 0.28),
      MochiPalette.mint.withValues(alpha: 0.24),
    ];

    const double step = 44;
    for (double y = 18; y < size.height; y += step) {
      for (double x = 16; x < size.width; x += step) {
        final int colorIndex = ((x + y) ~/ step) % colors.length;
        dot.color = colors[colorIndex];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 10, 10),
            const Radius.circular(3),
          ),
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
