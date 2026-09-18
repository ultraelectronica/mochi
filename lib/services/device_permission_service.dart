import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DevicePermissionState { granted, partial, denied, unsupported }

class DevicePermissionSnapshot {
  const DevicePermissionSnapshot({
    required this.media,
    required this.microphone,
    required this.batteryOptimization,
    required this.floatingWindow,
  });

  const DevicePermissionSnapshot.unsupported()
    : media = DevicePermissionState.unsupported,
      microphone = DevicePermissionState.unsupported,
      batteryOptimization = DevicePermissionState.unsupported,
      floatingWindow = DevicePermissionState.unsupported;

  factory DevicePermissionSnapshot.fromMap(Map<Object?, Object?> raw) {
    return DevicePermissionSnapshot(
      media: _stateFromRaw(raw['media']),
      microphone: _stateFromRaw(raw['microphone']),
      batteryOptimization: _stateFromRaw(raw['batteryOptimization']),
      floatingWindow: _stateFromRaw(raw['floatingWindow']),
    );
  }

  final DevicePermissionState media;
  final DevicePermissionState microphone;
  final DevicePermissionState batteryOptimization;
  final DevicePermissionState floatingWindow;

  static DevicePermissionState _stateFromRaw(Object? raw) {
    switch (raw) {
      case 'granted':
        return DevicePermissionState.granted;
      case 'partial':
        return DevicePermissionState.partial;
      case 'denied':
        return DevicePermissionState.denied;
      default:
        return DevicePermissionState.unsupported;
    }
  }
}

class DevicePermissionService {
  const DevicePermissionService();

  static const MethodChannel _channel = MethodChannel(
    'mochi/device_permissions',
  );

  bool get supportsInteractivePermissions =>
      defaultTargetPlatform == TargetPlatform.android;

  Future<DevicePermissionSnapshot> loadSnapshot() async {
    if (!supportsInteractivePermissions) {
      return const DevicePermissionSnapshot.unsupported();
    }

    try {
      final Map<Object?, Object?> raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(
            'getPermissionSnapshot',
          ) ??
          <Object?, Object?>{};
      return DevicePermissionSnapshot.fromMap(raw);
    } on PlatformException {
      return const DevicePermissionSnapshot.unsupported();
    } on MissingPluginException {
      return const DevicePermissionSnapshot.unsupported();
    }
  }

  Future<void> requestMediaUploadPermission() async {
    await _invokeVoid('requestMediaUploadPermission');
  }

  Future<void> requestMicrophonePermission() async {
    await _invokeVoid('requestMicrophonePermission');
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _invokeVoid('openBatteryOptimizationSettings');
  }

  Future<void> openFloatingWindowSettings() async {
    await _invokeVoid('openFloatingWindowSettings');
  }

  Future<void> openAppSettings() async {
    await _invokeVoid('openAppSettings');
  }

  Future<void> _invokeVoid(String method) async {
    if (!supportsInteractivePermissions) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      rethrow;
    } on MissingPluginException {
      // Ignore unsupported platform setups and let the UI render as unavailable.
    }
  }
}

extension DevicePermissionStateX on DevicePermissionState {
  String get label {
    switch (this) {
      case DevicePermissionState.granted:
        return 'Granted';
      case DevicePermissionState.partial:
        return 'Partial';
      case DevicePermissionState.denied:
        return 'Needs access';
      case DevicePermissionState.unsupported:
        return 'Unavailable';
    }
  }
}
