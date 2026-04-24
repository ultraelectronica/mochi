import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';

final GlobalKey<MochiToastHostState> mochiToastHostKey =
    GlobalKey<MochiToastHostState>();

enum MochiToastTone { info, success, warning, error }

class MochiToast {
  static void show({
    String? title,
    required String message,
    MochiToastTone tone = MochiToastTone.info,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    mochiToastHostKey.currentState?.showToast(
      title: title,
      message: message,
      tone: tone,
      icon: icon,
      duration: duration,
    );
  }

  static void hide() {
    mochiToastHostKey.currentState?.hideToast();
  }
}

class MochiToastHost extends StatefulWidget {
  const MochiToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<MochiToastHost> createState() => MochiToastHostState();
}

class MochiToastHostState extends State<MochiToastHost> {
  _ToastEntry? _entry;
  Timer? _dismissTimer;
  int _entryId = 0;

  void showToast({
    String? title,
    required String message,
    required MochiToastTone tone,
    IconData? icon,
    required Duration duration,
  }) {
    _dismissTimer?.cancel();

    setState(() {
      _entry = _ToastEntry(
        id: ++_entryId,
        title: title,
        message: message,
        tone: tone,
        icon: icon,
      );
    });

    _dismissTimer = Timer(duration, hideToast);
  }

  void hideToast() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (!mounted || _entry == null) {
      return;
    }

    setState(() {
      _entry = null;
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                reverseDuration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final Animation<Offset> slide = Tween<Offset>(
                    begin: const Offset(0, -0.18),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _entry == null
                    ? const SizedBox.shrink(key: ValueKey<String>('empty'))
                    : _ToastCard(
                        key: ValueKey<int>(_entry!.id),
                        entry: _entry!,
                        onDismiss: hideToast,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastEntry {
  const _ToastEntry({
    required this.id,
    required this.title,
    required this.message,
    required this.tone,
    required this.icon,
  });

  final int id;
  final String? title;
  final String message;
  final MochiToastTone tone;
  final IconData? icon;
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({super.key, required this.entry, required this.onDismiss});

  final _ToastEntry entry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ({Color accent, Color badge, IconData icon}) style = _styleFor(
      entry.tone,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: pixelCardDecoration(style.accent),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: style.badge,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MochiPalette.ink, width: 2.5),
                ),
                child: Icon(
                  entry.icon ?? style.icon,
                  color: MochiPalette.ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if ((entry.title ?? '').isNotEmpty) ...<Widget>[
                      Text(
                        entry.title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      entry.message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MochiPalette.ink, width: 2),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: MochiPalette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({Color accent, Color badge, IconData icon}) _styleFor(MochiToastTone tone) {
    switch (tone) {
      case MochiToastTone.success:
        return (
          accent: MochiPalette.mint,
          badge: MochiPalette.yellow,
          icon: Icons.check_circle_outline_rounded,
        );
      case MochiToastTone.warning:
        return (
          accent: MochiPalette.yellow,
          badge: MochiPalette.peach,
          icon: Icons.cloud_off_rounded,
        );
      case MochiToastTone.error:
        return (
          accent: MochiPalette.peach,
          badge: MochiPalette.lightPink,
          icon: Icons.sync_problem_rounded,
        );
      case MochiToastTone.info:
        return (
          accent: MochiPalette.cloudBlue,
          badge: MochiPalette.lavender,
          icon: Icons.notifications_active_outlined,
        );
    }
  }
}
