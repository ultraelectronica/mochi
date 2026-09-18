import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FloatingMochiState {
  const FloatingMochiState({
    required this.enabled,
    required this.running,
    required this.overlayGranted,
    required this.available,
  });

  const FloatingMochiState.unsupported()
    : enabled = false,
      running = false,
      overlayGranted = false,
      available = false;

  factory FloatingMochiState.fromMap(Map<Object?, Object?> raw) {
    return FloatingMochiState(
      enabled: raw['enabled'] == true,
      running: raw['running'] == true,
      overlayGranted: raw['overlayGranted'] == true,
      available: true,
    );
  }

  final bool enabled;
  final bool running;
  final bool overlayGranted;
  final bool available;
}

class FloatingMochiService {
  const FloatingMochiService();

  static const MethodChannel _channel = MethodChannel(
    'mochi/device_permissions',
  );

  bool get supportsFloatingMochi =>
      defaultTargetPlatform == TargetPlatform.android;

  Future<FloatingMochiState> loadState() async {
    if (!supportsFloatingMochi) {
      return const FloatingMochiState.unsupported();
    }

    try {
      final Map<Object?, Object?> raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(
            'getFloatingMochiState',
          ) ??
          <Object?, Object?>{};
      return FloatingMochiState.fromMap(raw);
    } on PlatformException {
      return const FloatingMochiState.unsupported();
    } on MissingPluginException {
      return const FloatingMochiState.unsupported();
    }
  }

  Future<FloatingMochiState> setEnabled(bool enabled) async {
    if (!supportsFloatingMochi) {
      return const FloatingMochiState.unsupported();
    }

    try {
      final Map<Object?, Object?> raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(
            'setFloatingMochiEnabled',
            <String, Object?>{'enabled': enabled},
          ) ??
          <Object?, Object?>{};
      return FloatingMochiState.fromMap(raw);
    } on MissingPluginException {
      return const FloatingMochiState.unsupported();
    }
  }

  Future<void> syncAppForegroundState(bool isForeground) async {
    if (!supportsFloatingMochi) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(
        'syncFloatingMochiAppForegroundState',
        <String, Object?>{'isForeground': isForeground},
      );
    } on PlatformException {
      // Ignore startup and lifecycle sync failures.
    } on MissingPluginException {
      // Ignore unsupported platform setups.
    }
  }
}
