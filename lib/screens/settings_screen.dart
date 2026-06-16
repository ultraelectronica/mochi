import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../services/api_service.dart';
import '../services/device_permission_service.dart';
import '../services/floating_mochi_service.dart';
import '../widgets/member_avatar.dart';
import '../widgets/mochi_bottom_nav_bar.dart';
import '../widgets/mochi_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.petProvider,
    required this.memberProvider,
    required this.onCreateMember,
    required this.onLogout,
    required this.onServerUrlChanged,
  });

  final AuthSession session;
  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final Future<void> Function() onCreateMember;
  final Future<void> Function() onLogout;
  final Future<void> Function(String url) onServerUrlChanged;

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

  String _errorMessage(Object error) {
    return widget.memberProvider.errorMessage ??
        widget.petProvider.errorMessage ??
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

  void _showErrorToast(Object error) {
    if (error is ApiException && error.isOffline) {
      _showToast(
        'Start the Mochi server at ${AppConfig.serverUrl}, then try again.',
        title: 'Mochi server offline',
        tone: MochiToastTone.warning,
        icon: Icons.cloud_off_rounded,
      );
      return;
    }

    _showToast(
      _errorMessage(error),
      title: 'Something went sideways',
      tone: MochiToastTone.error,
      icon: Icons.sync_problem_rounded,
    );
  }

  String _formatMemberLastSeen(DateTime? value) {
    if (value == null) {
      return 'Not seen yet';
    }

    final Duration delta = DateTime.now().difference(value);
    if (delta.inMinutes < 1) {
      return 'Just now';
    }
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes}m ago';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours}h ago';
    }
    if (delta.inDays == 1) {
      return 'Yesterday';
    }
    return '${value.month}/${value.day}/${value.year}';
  }

  Future<void> _editServerUrl() async {
    final TextEditingController controller = TextEditingController(
      text: AppConfig.serverUrl,
    );

    String? validate(String? value) {
      final String trimmed = (value ?? '').trim();
      if (trimmed.isEmpty) {
        return 'Enter a server URL.';
      }
      final Uri? parsed = Uri.tryParse(trimmed);
      if (parsed == null ||
          (parsed.scheme != 'http' && parsed.scheme != 'https') ||
          parsed.host.isEmpty) {
        return 'Use a full http:// or https:// address.';
      }
      return null;
    }

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        String? errorText;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        return AlertDialog(
          title: const Text('Server URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Point Mochi at the household host device, e.g. http://192.168.1.50:3000',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                autocorrect: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'http://host:port',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() {
                      errorText = null;
                    });
                  }
                },
                onSubmitted: (String value) {
                  final String? err = validate(value);
                  if (err != null) {
                    setState(() {
                      errorText = err;
                    });
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String? err = validate(controller.text);
                if (err != null) {
                  setState(() {
                    errorText = err;
                  });
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
          },
        );
      },
    );

    final String next = controller.text.trim();
    controller.dispose();

    if (saved != true || !mounted) {
      return;
    }

    if (next == AppConfig.serverUrl) {
      _showToast(
        'No change to the server URL.',
        title: 'Server URL',
        tone: MochiToastTone.info,
        icon: Icons.dns_rounded,
      );
      return;
    }

    try {
      await widget.onServerUrlChanged(next);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorToast(error);
    }
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

  Future<void> _handleCreateMember() async {
    try {
      await widget.onCreateMember();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorToast(error);
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log out'),
          content: const Text(
            'Are you sure you want to log out? You\'ll need to sign in again to access your household.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: MochiPalette.peach,
                foregroundColor: MochiPalette.ink,
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.onLogout();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorToast(error);
    }
  }

  Future<void> _handleDeleteMember(Member member) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove member'),
          content: Text(
            'Remove ${member.name} from Mochi\'s shared family room? Their affection, XP, mood check-ins, and chat history links will be deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.memberProvider.deleteMember(member);
      await widget.petProvider.refreshState(
        includeHealth: false,
        includeChat: false,
      );
      if (!mounted) {
        return;
      }
      _showToast(
        '${member.name} was removed from the family list.',
        title: 'Account removed',
        tone: MochiToastTone.success,
        icon: Icons.person_remove_alt_1_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorToast(error);
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
                  'Practical controls for the app, server connection, and device access.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _SettingsInfoRow(
                  title: 'Server URL',
                  subtitle: AppConfig.serverUrl,
                  icon: Icons.cloud_done_rounded,
                  onTap: _editServerUrl,
                ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Server status',
                  subtitle: widget.petProvider.serverOnline
                      ? 'Online and ready for live updates'
                      : 'Offline or unreachable right now',
                  icon: widget.petProvider.serverOnline
                      ? Icons.wifi_rounded
                      : Icons.portable_wifi_off_rounded,
                ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Llama status',
                  subtitle: widget.petProvider.llamaOnline
                      ? 'Local llama server is reachable'
                      : 'DeepSeek fallback will be used if chat is requested',
                  icon: widget.petProvider.llamaOnline
                      ? Icons.psychology_rounded
                      : Icons.psychology_alt_rounded,
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
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Current member',
                  subtitle: widget.memberProvider.currentMember.name,
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Household code',
                  subtitle: widget.session.household.code,
                  icon: Icons.home_work_rounded,
                ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Signed in as',
                  subtitle:
                      '${widget.session.account.username}${widget.session.account.isAdmin ? ' • admin' : ''}',
                  icon: Icons.badge_rounded,
                ),
                const SizedBox(height: 10),
                Text(
                  'Household accounts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.memberProvider.isAdmin
                      ? 'Admin can create and remove household accounts here. Tap a row to inspect it in detail.'
                      : 'Only the household admin can create or remove accounts. You can still inspect the roster.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (widget.memberProvider.isAdmin) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: widget.memberProvider.isCreating
                          ? null
                          : _handleCreateMember,
                      icon: widget.memberProvider.isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(
                        widget.memberProvider.isCreating
                            ? 'Creating account...'
                            : 'Create account',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.memberProvider.isLoading)
                  const _SettingsLoadingRow(title: 'Loading family members')
                else ...<Widget>[
                  ...List<
                    Widget
                  >.generate(widget.memberProvider.members.length, (int index) {
                    final Member member = widget.memberProvider.members[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            index == widget.memberProvider.members.length - 1
                            ? 0
                            : 10,
                      ),
                      child: _MemberManagementRow(
                        member: member,
                        selected: widget.memberProvider.selectedIndex == index,
                        busy:
                            widget.memberProvider.deletingMemberId == member.id,
                        canDelete: widget.memberProvider.isAdmin,
                        onSelect: () =>
                            widget.memberProvider.selectMember(index),
                        onDelete: () => _handleDeleteMember(member),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 12),
                if (widget.memberProvider.isLoadingSelectedMemberDetail)
                  const _SettingsLoadingRow(title: 'Loading member details')
                else if (widget.memberProvider.selectedMemberDetail != null)
                  _MemberDetailCard(
                    detail: widget.memberProvider.selectedMemberDetail!,
                    lastSeenLabel: _formatMemberLastSeen(
                      widget
                          .memberProvider
                          .selectedMemberDetail!
                          .member
                          .lastSeenAt,
                    ),
                  ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Render mode',
                  subtitle:
                      'Transform-only pet motion tuned for smooth high refresh screens',
                  icon: Icons.high_quality_rounded,
                ),
                const SizedBox(height: 10),
                const _SettingsInfoRow(
                  title: 'Draft note',
                  subtitle:
                      'Mood check-in, feed, and profile features were intentionally merged into Home.',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 16),
                const Divider(
                  color: MochiPalette.ink,
                  thickness: 2,
                  indent: 0,
                  endIndent: 0,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _handleLogout,
                    style: FilledButton.styleFrom(
                      backgroundColor: MochiPalette.peach,
                      foregroundColor: MochiPalette.ink,
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Log out'),
                  ),
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
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool tappable = onTap != null;
    final Widget content = Container(
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
          if (tappable)
            const Icon(
              Icons.chevron_right_rounded,
              color: MochiPalette.ink,
            ),
        ],
      ),
    );

    if (!tappable) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: content,
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

class _MemberManagementRow extends StatelessWidget {
  const _MemberManagementRow({
    required this.member,
    required this.selected,
    required this.busy,
    required this.canDelete,
    required this.onSelect,
    required this.onDelete,
  });

  final Member member;
  final bool selected;
  final bool busy;
  final bool canDelete;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? member.color.withValues(alpha: 0.2) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: busy ? null : onSelect,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MochiPalette.ink, width: 2),
          ),
          child: Row(
            children: <Widget>[
              MemberAvatar(member: member, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      member.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (member.username.isNotEmpty) '@${member.username}',
                        if (member.isAdmin) 'admin',
                        if (member.invitePending) 'invite pending',
                        '${member.affection} affection',
                        '${member.xp} XP',
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MochiPalette.mint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MochiPalette.ink, width: 2),
                  ),
                  child: Text(
                    'Viewing',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              !canDelete
                  ? const SizedBox.shrink()
                  : busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Remove member',
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberDetailCard extends StatelessWidget {
  const _MemberDetailCard({required this.detail, required this.lastSeenLabel});

  final MemberDetail detail;
  final String lastSeenLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: detail.member.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${detail.member.name} details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            detail.member.note,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MemberDetailPill(
                label: '${detail.member.xp} XP',
                icon: Icons.bolt_rounded,
                color: MochiPalette.yellow,
              ),
              _MemberDetailPill(
                label: '${detail.member.affection} affection',
                icon: Icons.favorite_rounded,
                color: MochiPalette.lightPink,
              ),
              _MemberDetailPill(
                label: 'Seen $lastSeenLabel',
                icon: Icons.schedule_rounded,
                color: MochiPalette.cloudBlue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Recent mood history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (detail.recentMoodLogs.isEmpty)
            Text(
              'No mood check-ins recorded yet for this member.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...detail.recentMoodLogs.take(5).map((MemberMoodLog log) {
              final MochiMood mood = mochiMoodFromString(log.mood);
              final DateTime time = log.createdAt;
              final String dateLabel = '${time.month}/${time.day}/${time.year}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: mood.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MochiPalette.ink, width: 2),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(mood.icon, color: MochiPalette.ink, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mood.label,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
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

class _MemberDetailPill extends StatelessWidget {
  const _MemberDetailPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
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
