import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.petProvider,
    required this.memberProvider,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
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
                  'Practical controls for the app and server connection.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _SettingsInfoRow(
                  title: 'Server URL',
                  subtitle: AppConfig.serverUrl,
                  icon: Icons.cloud_done_rounded,
                ),
                const SizedBox(height: 10),
                _SettingsToggleRow(
                  title: 'Server status',
                  subtitle: petProvider.serverOnline
                      ? 'Online and ready for live updates'
                      : 'Offline, fallback mode active',
                  icon: petProvider.serverOnline
                      ? Icons.wifi_rounded
                      : Icons.portable_wifi_off_rounded,
                  value: petProvider.serverOnline,
                  activeColor: MochiPalette.mint,
                  onChanged: petProvider.setServerOnline,
                ),
                const SizedBox(height: 10),
                _SettingsToggleRow(
                  title: 'Pet voice replies',
                  subtitle: petProvider.ttsEnabled
                      ? 'TTS preview enabled'
                      : 'Muted for quiet sessions',
                  icon: Icons.record_voice_over_rounded,
                  value: petProvider.ttsEnabled,
                  activeColor: MochiPalette.lightPink,
                  onChanged: petProvider.setTtsEnabled,
                ),
                const SizedBox(height: 10),
                _SettingsToggleRow(
                  title: 'Milestone notifications',
                  subtitle: petProvider.notificationsEnabled
                      ? 'Level-up nudges are on'
                      : 'Notifications are paused',
                  icon: Icons.notifications_active_rounded,
                  value: petProvider.notificationsEnabled,
                  activeColor: MochiPalette.yellow,
                  onChanged: petProvider.setNotificationsEnabled,
                ),
                const SizedBox(height: 10),
                _SettingsInfoRow(
                  title: 'Current member',
                  subtitle: memberProvider.currentMember.name,
                  icon: Icons.person_rounded,
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

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
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
