import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../models/member.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../services/device_permission_service.dart';
import '../services/floating_mochi_service.dart';
import '../services/local_llm/llm_service.dart';
import '../services/local_llm/model_manager.dart';
import '../widgets/mochi_bottom_nav_bar.dart';
import '../widgets/mochi_toast.dart';
import '../widgets/model_setup_panel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.petProvider,
    required this.memberProvider,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final DevicePermissionService _permissionService =
      const DevicePermissionService();
  final FloatingMochiService _floatingMochiService =
      const FloatingMochiService();

  DevicePermissionSnapshot? _permissionSnapshot;
  FloatingMochiState? _floatingMochiState;
  String? _pendingPermissionKey;

  void _showToast(
    String message, {
    String? title,
    MochiToastTone tone = MochiToastTone.info,
    IconData? icon,
  }) {
    MochiToast.show(title: title, message: message, tone: tone, icon: icon);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissionSnapshot();
    _refreshFloatingMochiState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionSnapshot();
      _refreshFloatingMochiState();
    }
  }

  Future<void> _refreshPermissionSnapshot() async {
    if (!_permissionService.supportsInteractivePermissions) {
      return;
    }

    final DevicePermissionSnapshot snapshot = await _permissionService
        .loadSnapshot();
    if (!mounted) {
      return;
    }

    setState(() {
      _permissionSnapshot = snapshot;
    });
  }

  Future<void> _refreshFloatingMochiState() async {
    if (!_floatingMochiService.supportsFloatingMochi) {
      return;
    }

    final FloatingMochiState state = await _floatingMochiService.loadState();
    if (!mounted) {
      return;
    }

    setState(() {
      _floatingMochiState = state;
    });
  }

  Future<void> _runPermissionAction({
    required String key,
    required Future<void> Function() action,
    String? notice,
  }) async {
    if (_pendingPermissionKey != null) {
      return;
    }

    setState(() {
      _pendingPermissionKey = key;
    });

    try {
      await action();
      await _refreshPermissionSnapshot();

      if (!mounted || notice == null) {
        return;
      }

      _showToast(
        notice,
        title: 'Updated',
        tone: MochiToastTone.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      _showToast(
        error.message ?? 'Permission request failed.',
        title: 'Permission issue',
        tone: MochiToastTone.error,
        icon: Icons.lock_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingPermissionKey = null;
        });
      }
    }
  }

  Future<void> _handleFloatingMochiToggle(bool value) async {
    if (_pendingPermissionKey != null ||
        !_floatingMochiService.supportsFloatingMochi) {
      return;
    }

    setState(() {
      _pendingPermissionKey = 'floating-toggle';
    });

    try {
      final FloatingMochiState state = await _floatingMochiService.setEnabled(
        value,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _floatingMochiState = state;
      });

      final String message;
      if (!value) {
        message = 'Floating Mochi turned off.';
      } else if (!state.overlayGranted) {
        message =
            'Floating Mochi is enabled. Grant floating window access so it can appear above other apps.';
      } else {
        message =
            'Floating Mochi is enabled and will appear when the app moves to the background.';
      }

      _showToast(
        message,
        title: 'Floating Mochi',
        tone: value ? MochiToastTone.info : MochiToastTone.success,
        icon: value ? Icons.open_in_new_rounded : Icons.close_rounded,
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      _showToast(
        error.message ?? 'Floating Mochi failed.',
        title: 'Floating Mochi',
        tone: MochiToastTone.error,
        icon: Icons.open_in_new_off_rounded,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pendingPermissionKey = null;
        });
      }
    }
  }

  Color _permissionAccent(DevicePermissionState state) {
    switch (state) {
      case DevicePermissionState.granted:
        return MochiPalette.mint;
      case DevicePermissionState.partial:
        return MochiPalette.yellow;
      case DevicePermissionState.denied:
        return MochiPalette.peach;
      case DevicePermissionState.unsupported:
        return MochiPalette.lavender;
    }
  }

  Color _floatingMochiAccent(FloatingMochiState state) {
    if (!state.overlayGranted && state.enabled) {
      return MochiPalette.peach;
    }
    if (state.running) {
      return MochiPalette.mint;
    }
    if (state.enabled) {
      return MochiPalette.yellow;
    }
    return MochiPalette.cloudBlue;
  }

  String _floatingMochiSubtitle(FloatingMochiState state) {
    if (!state.enabled) {
      return 'Keep Mochi drifting above other apps whenever the app is in the background.';
    }
    if (!state.overlayGranted) {
      return 'Enabled, but Android still needs floating window access before the bubble can appear.';
    }
    if (state.running) {
      return 'Mochi is currently floating above your other apps.';
    }
    return 'Mochi will appear automatically the next time the app moves to the background.';
  }

  String _mediaSubtitle(DevicePermissionState state) {
    switch (state) {
      case DevicePermissionState.granted:
        return 'Photo and video uploads are ready for chat and memory moments.';
      case DevicePermissionState.partial:
        return 'Only part of the media library is available. Review Android media access.';
      case DevicePermissionState.denied:
        return 'Needed for photo and video uploads into chat and shared memories.';
      case DevicePermissionState.unsupported:
        return 'This device does not expose Android media access controls here.';
    }
  }

  String _microphoneSubtitle(DevicePermissionState state) {
    switch (state) {
      case DevicePermissionState.granted:
        return 'Microphone access is ready for voice capture and spoken features.';
      case DevicePermissionState.partial:
        return 'Microphone access is only partially available.';
      case DevicePermissionState.denied:
        return 'Needed for voice messages, recording, and spoken Mochi moments.';
      case DevicePermissionState.unsupported:
        return 'This device does not expose Android microphone controls here.';
    }
  }

  String _batterySubtitle(DevicePermissionState state) {
    switch (state) {
      case DevicePermissionState.granted:
        return 'Android is set up to keep the floating Mochi bubble alive more reliably in the background.';
      case DevicePermissionState.partial:
        return 'Battery access is only partially available.';
      case DevicePermissionState.denied:
        return 'Recommended so floating Mochi is less likely to be stopped while the app runs in the background.';
      case DevicePermissionState.unsupported:
        return 'Battery optimization controls are only relevant on supported Android devices.';
    }
  }

  String _floatingWindowSubtitle(DevicePermissionState state) {
    switch (state) {
      case DevicePermissionState.granted:
        return 'Overlay window access is ready for the background floating Mochi bubble.';
      case DevicePermissionState.partial:
        return 'Overlay access is only partially available.';
      case DevicePermissionState.denied:
        return 'Required for a floating Mochi window that stays above other apps.';
      case DevicePermissionState.unsupported:
        return 'Floating window controls are only available on Android.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MochiBottomNavBar.overlayPadding(context) + 24,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: pixelCardDecoration(MochiPalette.lavender),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Settings', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Everything runs on this device. No server, no accounts.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _SettingsInfoRow(
                  title: 'Your profile',
                  subtitle: widget.memberProvider.currentMember.name,
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 10),
                _AboutYouCard(
                  member: widget.memberProvider.currentMember,
                  onEdit: _editAboutYou,
                ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Mochi\'s name',
                  subtitle: widget.petProvider.pet.name,
                  icon: Icons.pets_rounded,
                ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Storage',
                  subtitle: 'All chats, moods, and memories live on this phone.',
                  icon: Icons.phone_android_rounded,
                ),
                const SizedBox(height: 10),
                _SettingsToggleRow(
                  title: 'Pet voice replies',
                  subtitle: widget.petProvider.ttsEnabled
                      ? 'TTS preview enabled'
                      : 'Muted for quiet sessions',
                  icon: Icons.record_voice_over_rounded,
                  value: widget.petProvider.ttsEnabled,
                  activeColor: MochiPalette.lightPink,
                  onChanged: widget.petProvider.setTtsEnabled,
                ),
                const SizedBox(height: 10),
                _SettingsToggleRow(
                  title: 'Milestone notifications',
                  subtitle: widget.petProvider.notificationsEnabled
                      ? 'Level-up nudges are on'
                      : 'Notifications are paused',
                  icon: Icons.notifications_active_rounded,
                  value: widget.petProvider.notificationsEnabled,
                  activeColor: MochiPalette.yellow,
                  onChanged: widget.petProvider.setNotificationsEnabled,
                ),
                const SizedBox(height: 16),
                const Divider(
                  color: MochiPalette.ink,
                  thickness: 2,
                  indent: 0,
                  endIndent: 0,
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[
                    ModelManager.instance,
                    LlmService.instance,
                  ]),
                  builder: (BuildContext context, Widget? child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'On-device AI',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            _SettingsStatusPill(
                              label: _aiStatusLabel(),
                              color: _aiStatusColor(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mochi\'s brain is a small language model downloaded once and run entirely on this phone. No internet needed after setup.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        ModelSetupPanel(
                          onInstalled: () {
                            widget.petProvider.refreshState(force: true);
                          },
                        ),
                        const SizedBox(height: 10),
                        _SettingsInfoRow(
                          title: 'Loaded model',
                          subtitle: LlmService.instance.loadedModel?.label ??
                              'Nothing loaded right now',
                          icon: Icons.memory_rounded,
                        ),
                        const SizedBox(height: 10),
                        _SettingsInfoRow(
                          title: 'Accelerator',
                          subtitle: LlmService.instance.accelerator ?? 'CPU',
                          icon: Icons.speed_rounded,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Floating Mochi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep Mochi drifting above other apps while this app is in the background.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (_floatingMochiService.supportsFloatingMochi)
                  if (_floatingMochiState == null)
                    const _SettingsLoadingRow(
                      title: 'Checking floating Mochi status',
                    )
                  else
                    _SettingsToggleRow(
                      title: 'Background Mochi bubble',
                      subtitle: _floatingMochiSubtitle(_floatingMochiState!),
                      icon: Icons.bubble_chart_rounded,
                      value: _floatingMochiState!.enabled,
                      activeColor: _floatingMochiAccent(_floatingMochiState!),
                      onChanged: _handleFloatingMochiToggle,
                      enabled: _pendingPermissionKey == null,
                      isBusy: _pendingPermissionKey == 'floating-toggle',
                    )
                else
                  const _SettingsInfoRow(
                    title: 'Floating Mochi platform note',
                    subtitle:
                        'The floating Mochi bubble is implemented on Android. iOS includes media and microphone usage descriptions only.',
                    icon: Icons.mobile_friendly_rounded,
                  ),
                const SizedBox(height: 16),
                Text(
                  'Device permissions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Grant upload, microphone, battery, and floating-window access for device-side Mochi features.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_permissionService
                    .supportsInteractivePermissions) ...<Widget>[
                  if (_permissionSnapshot == null)
                    const _SettingsLoadingRow(
                      title: 'Checking Android permissions',
                    )
                  else ...<Widget>[
                    _PermissionActionRow(
                      title: 'Media upload',
                      subtitle: _mediaSubtitle(_permissionSnapshot!.media),
                      icon: Icons.perm_media_rounded,
                      statusLabel: _permissionSnapshot!.media.label,
                      accentColor: _permissionAccent(
                        _permissionSnapshot!.media,
                      ),
                      actionLabel: 'Request',
                      isBusy: _pendingPermissionKey == 'media',
                      onPressed: _pendingPermissionKey == null
                          ? () => _runPermissionAction(
                              key: 'media',
                              action: _permissionService
                                  .requestMediaUploadPermission,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _PermissionActionRow(
                      title: 'Microphone',
                      subtitle: _microphoneSubtitle(
                        _permissionSnapshot!.microphone,
                      ),
                      icon: Icons.mic_rounded,
                      statusLabel: _permissionSnapshot!.microphone.label,
                      accentColor: _permissionAccent(
                        _permissionSnapshot!.microphone,
                      ),
                      actionLabel: 'Request',
                      isBusy: _pendingPermissionKey == 'microphone',
                      onPressed: _pendingPermissionKey == null
                          ? () => _runPermissionAction(
                              key: 'microphone',
                              action: _permissionService
                                  .requestMicrophonePermission,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _PermissionActionRow(
                      title: 'Battery optimization',
                      subtitle: _batterySubtitle(
                        _permissionSnapshot!.batteryOptimization,
                      ),
                      icon: Icons.battery_saver_rounded,
                      statusLabel:
                          _permissionSnapshot!.batteryOptimization.label,
                      accentColor: _permissionAccent(
                        _permissionSnapshot!.batteryOptimization,
                      ),
                      actionLabel: 'Open settings',
                      isBusy: _pendingPermissionKey == 'battery',
                      onPressed: _pendingPermissionKey == null
                          ? () => _runPermissionAction(
                              key: 'battery',
                              action: _permissionService
                                  .openBatteryOptimizationSettings,
                              notice:
                                  'Opened Android battery optimization settings.',
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _PermissionActionRow(
                      title: 'Floating window',
                      subtitle: _floatingWindowSubtitle(
                        _permissionSnapshot!.floatingWindow,
                      ),
                      icon: Icons.picture_in_picture_alt_rounded,
                      statusLabel: _permissionSnapshot!.floatingWindow.label,
                      accentColor: _permissionAccent(
                        _permissionSnapshot!.floatingWindow,
                      ),
                      actionLabel: 'Open settings',
                      isBusy: _pendingPermissionKey == 'floating',
                      onPressed: _pendingPermissionKey == null
                          ? () => _runPermissionAction(
                              key: 'floating',
                              action:
                                  _permissionService.openFloatingWindowSettings,
                              notice:
                                  'Opened Android floating window settings.',
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _pendingPermissionKey == null
                            ? () => _runPermissionAction(
                                key: 'app-settings',
                                action: _permissionService.openAppSettings,
                                notice: 'Opened Android app settings.',
                              )
                            : null,
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Open app settings'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _SettingsInfoRow(
                      title: 'Floating Mochi note',
                      subtitle:
                          'For the smoothest results, keep both floating window and battery optimization access available for the Android bubble service.',
                      icon: Icons.bubble_chart_rounded,
                    ),
                  ],
                ] else
                  const _SettingsInfoRow(
                    title: 'Platform note',
                    subtitle:
                        'Microphone and photo library usage descriptions are configured for iOS. The floating Mochi bubble, floating window access, and battery optimization controls are Android-only.',
                    icon: Icons.mobile_friendly_rounded,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _aiStatusLabel() {
    final LlmService service = LlmService.instance;
    if (service.isReady) {
      return 'Running';
    }
    if (ModelManager.instance.state.isActive) {
      return 'Downloading';
    }
    if (service.state == LlmEngineState.error) {
      return 'Error';
    }
    return 'Idle';
  }

  Color _aiStatusColor() {
    final LlmService service = LlmService.instance;
    if (service.isReady) {
      return MochiPalette.mint;
    }
    if (ModelManager.instance.state.isActive) {
      return MochiPalette.yellow;
    }
    return MochiPalette.peach;
  }

  Future<void> _editAboutYou() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _EditAboutYouDialog(provider: widget.memberProvider),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: MochiPalette.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.activeColor,
    required this.onChanged,
    this.enabled = true,
    this.isBusy = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: MochiPalette.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (isBusy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
        ],
      ),
    );
  }
}

class _SettingsStatusPill extends StatelessWidget {
  const _SettingsStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _PermissionActionRow extends StatelessWidget {
  const _PermissionActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.statusLabel,
    required this.accentColor,
    required this.actionLabel,
    required this.isBusy,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String statusLabel;
  final Color accentColor;
  final String actionLabel;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: MochiPalette.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _PermissionStatusPill(label: statusLabel, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionStatusPill extends StatelessWidget {
  const _PermissionStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _SettingsLoadingRow extends StatelessWidget {
  const _SettingsLoadingRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _AboutYouCard extends StatelessWidget {
  const _AboutYouCard({required this.member, required this.onEdit});

  final Member member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String? bio = member.bio;
    final DateTime? birthday = member.birthdate;
    final int? age = member.age;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.person_outline_rounded, color: MochiPalette.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'About you',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            birthday == null
                ? 'Birthday: not set'
                : 'Birthday: ${formatBirthdate(birthday)}'
                    '${age == null ? '' : ' (age $age)'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            bio ?? 'Nothing shared yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Stored only on this phone.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EditAboutYouDialog extends StatefulWidget {
  const _EditAboutYouDialog({required this.provider});

  final MemberProvider provider;

  @override
  State<_EditAboutYouDialog> createState() => _EditAboutYouDialogState();
}

class _EditAboutYouDialogState extends State<_EditAboutYouDialog> {
  late final TextEditingController _bioController;
  late DateTime? _birthdate;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final Member member = widget.provider.currentMember;
    _bioController = TextEditingController(text: member.bio ?? '');
    _birthdate = member.birthdate;
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 15, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthday',
    );
    if (picked != null && mounted) {
      setState(() => _birthdate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.provider.updateProfile(
        bio: _bioController.text,
        birthdate: _birthdate,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: pixelCardDecoration(MochiPalette.cloudBlue),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('About you', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: GameConfig.maxBioLength,
                  decoration: const InputDecoration(
                    labelText: 'A little about you',
                    hintText: 'e.g. I love rainy days, jazz, and long walks',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickBirthdate,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MochiPalette.ink,
                          textStyle: const TextStyle(
                            fontFamily: 'Pixelify Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        icon: const Icon(Icons.cake_rounded),
                        label: Text(
                          _birthdate == null
                              ? 'Pick your birthday'
                              : 'Birthday: ${formatBirthdate(_birthdate!)}',
                        ),
                      ),
                    ),
                    if (_birthdate != null)
                      IconButton(
                        onPressed: () => setState(() => _birthdate = null),
                        icon: const Icon(Icons.close_rounded),
                        color: MochiPalette.ink,
                        tooltip: 'Clear birthday',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Privacy: stored only on this phone.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MochiPalette.peach,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: MochiPalette.ink.withValues(
                          alpha: 0.7,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Pixelify Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: MochiPalette.cloudBlue,
                        foregroundColor: MochiPalette.ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Pixelify Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(
                            color: MochiPalette.ink,
                            width: 2.5,
                          ),
                        ),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
