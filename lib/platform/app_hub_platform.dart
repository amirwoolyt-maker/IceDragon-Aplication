import 'package:flutter/services.dart';

/// MethodChannel bridge for the standalone Android App Hub project.
class AppHubPlatformChannel {
  static const MethodChannel _channel = MethodChannel(
    'icedragon.apphub/android',
  );

  /// App internal files directory path on Android.
  static Future<String> dataDir() async {
    try {
      return await _channel.invokeMethod<String>('dataDir') ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  /// Small PNG bytes for [package]'s launcher icon.
  static Future<Uint8List?> appIcon(String package) async {
    try {
      return await _channel.invokeMethod<Uint8List>('appIcon', {
        'package': package,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Full package metadata for installed apps (permissions, size, version,
  /// timestamps, category, installer).
  static Future<List<Map<Object?, Object?>>> installedAppsDetailed() async {
    try {
      return await _channel.invokeListMethod<Map<Object?, Object?>>(
            'installedAppsDetailed',
          ) ??
          const [];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Device hardware, OS API level, memory, storage, and Usage Access state.
  static Future<Map<Object?, Object?>> deviceInfo() async {
    try {
      return await _channel.invokeMapMethod<Object?, Object?>('deviceInfo') ??
          const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  /// Opens the Android system App Info screen for [package].
  static Future<bool> openAppSettings(String package) async {
    try {
      return await _channel.invokeMethod<bool>('openAppSettings', {
            'package': package,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Android's native uninstall dialog and waits for completion result.
  static Future<bool> uninstallApp(String package) async {
    try {
      return await _channel.invokeMethod<bool>('uninstallApp', {
            'package': package,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Launches [package] directly from inside the app.
  static Future<bool> launchApp(String package) async {
    try {
      return await _channel.invokeMethod<bool>('launchApp', {
            'package': package,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Signals allowed background processes and measures available RAM before/after.
  static Future<Map<Object?, Object?>> boostMemory({
    List<String> exclude = const [],
  }) async {
    try {
      return await _channel.invokeMapMethod<Object?, Object?>(
            'boostMemory',
            {'exclude': exclude},
          ) ??
          const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  /// Opens Android's Usage Access settings so exact app data/cache sizes load.
  static Future<bool> openUsageAccessSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openUsageAccessSettings') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens Android's system VPN settings so users can manage any external VPN app.
  static Future<bool> openVpnSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openVpnSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the Android share sheet for [text].
  static Future<bool> shareText(String text, {String subject = ''}) async {
    try {
      return await _channel.invokeMethod<bool>('shareText', {
            'text': text,
            'subject': subject,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens [package] in [store] (`bazaar`, `myket`, `googlePlay`) or falls back
  /// to validated `https://` [fallbackUrl].
  static Future<bool> openStore(
    String package,
    String store, {
    String fallbackUrl = '',
  }) async {
    try {
      return await _channel.invokeMethod<bool>('openStore', {
            'package': package,
            'store': store,
            'fallbackUrl': fallbackUrl,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Stores a secret string encrypted via Android Keystore AES-256-GCM.
  static Future<bool> saveSecret(String key, String value) async {
    try {
      return await _channel.invokeMethod<bool>('saveSecret', {
            'key': key,
            'value': value,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Reads a secret string encrypted via Android Keystore AES-256-GCM.
  static Future<String> readSecret(String key) async {
    try {
      return await _channel.invokeMethod<String>('readSecret', {'key': key}) ??
          '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }
}
