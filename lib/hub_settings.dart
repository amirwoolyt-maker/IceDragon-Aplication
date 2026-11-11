import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Standalone application UI preferences (language and theme mode) stored
/// independently from any VPN core.
class HubAppSettings extends ChangeNotifier {
  HubAppSettings({this.file});

  final File? file;

  /// `'en'`, `'fa'`, or `''` (system locale).
  String language = '';
  ThemeMode themeMode = ThemeMode.dark;
  Future<void> _saveTail = Future.value();

  static Future<HubAppSettings> load(String dataDir) async {
    final trimmed = dataDir.trim();
    final f = trimmed.isEmpty
        ? null
        : File('$trimmed/hub_data/app-hub-prefs.json');
    final s = HubAppSettings(file: f);
    if (f == null) return s;
    try {
      if (!await f.exists()) return s;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map<String, Object?>) return s;
      if (raw['language'] case final String lang) s.language = lang;
      if (raw['theme'] case final String theme) {
        s.themeMode = switch (theme) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        };
      }
    } on FileSystemException {
      // Recover cleanly with defaults.
    } on FormatException {
      // Recover cleanly with defaults.
    }
    return s;
  }

  Future<void> update({String? language, ThemeMode? themeMode}) async {
    var changed = false;
    if (language != null && language != this.language) {
      this.language = language;
      changed = true;
    }
    if (themeMode != null && themeMode != this.themeMode) {
      this.themeMode = themeMode;
      changed = true;
    }
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  Future<void> _save() {
    _saveTail = _saveTail.then((_) => _write());
    return _saveTail;
  }

  Future<void> _write() async {
    final f = file;
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      await f.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'language': language,
          'theme': switch (themeMode) {
            ThemeMode.light => 'light',
            ThemeMode.system => 'system',
            ThemeMode.dark => 'dark',
          },
        }),
      );
    } on FileSystemException {
      // Keep running in-memory if storage write is unavailable.
    }
  }
}
