import 'dart:convert';
import 'dart:io';

import 'hub_models.dart';

/// Persists standalone App Hub state (`app-hub-state.json`):
/// custom categories, multi-category assignments, collections, cached store
/// updates, observed version history, Speed Boost preference, local VPN bypass
/// plan, optional external proxy, and transient Gemini migration handling.
class HubRepository {
  HubRepository({
    this.file,
    List<AppCategory>? categories,
    Map<String, Set<String>>? appCategories,
    List<AppCollection>? collections,
    Map<String, StoreListing>? updateCache,
    Map<String, List<AppVersionRecord>>? versionHistory,
    Set<String>? vpnBypassPackages,
    this.boostBeforeLaunch = true,
    this.useVpnProxyForStores = true,
    this.externalProxyAddress = '',
    this.geminiApiKey = '',
  }) : categories = categories ?? [...defaultAppCategories],
       appCategories = appCategories ?? {},
       collections = collections ?? [...defaultAppCollections],
       updateCache = updateCache ?? {},
       versionHistory = versionHistory ?? {},
       vpnBypassPackages = vpnBypassPackages ?? {};

  final File? file;

  final List<AppCategory> categories;
  final Map<String, Set<String>> appCategories;
  final List<AppCollection> collections;
  final Map<String, StoreListing> updateCache;
  final Map<String, List<AppVersionRecord>> versionHistory;
  final Set<String> vpnBypassPackages;

  bool boostBeforeLaunch;
  bool useVpnProxyForStores;
  String externalProxyAddress;

  /// Kept in memory only; stored securely on Android via Keystore AES-GCM.
  String geminiApiKey;

  /// Populated transiently if an older plaintext JSON had `gemini_api_key`,
  /// so [HubController] can migrate it to Android Keystore and wipe disk JSON.
  String legacyMigratedGeminiKey = '';

  Future<void> _saveTail = Future.value();

  static Future<HubRepository> load(String dataDir) async {
    final trimmed = dataDir.trim();
    final repo = HubRepository(
      file: trimmed.isEmpty
          ? null
          : File(
              '$trimmed${Platform.pathSeparator}hub_data${Platform.pathSeparator}app-hub-state.json',
            ),
    );
    final f = repo.file;
    if (f == null) return repo;
    try {
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map<String, Object?>) return repo;

      if (raw['categories'] case final List<Object?> cats) {
        final loaded = <AppCategory>[];
        final seen = <String>{};
        for (final item in cats) {
          if (item is Map<String, Object?>) {
            final c = AppCategory.fromJson(item);
            if (c.id.isNotEmpty && seen.add(c.id)) {
              loaded.add(c);
            }
          }
        }
        // Always ensure built-in categories remain available.
        for (final def in defaultAppCategories) {
          if (seen.add(def.id)) loaded.add(def);
        }
        if (loaded.isNotEmpty) {
          repo.categories
            ..clear()
            ..addAll(loaded);
        }
      }

      if (raw['app_categories'] case final Map<String, Object?> map) {
        for (final e in map.entries) {
          if (e.value is List<Object?>) {
            repo.appCategories[e.key] = {
              for (final id in e.value! as List<Object?>) '$id',
            };
          }
        }
      }

      if (raw['collections'] case final List<Object?> cols) {
        final loaded = <AppCollection>[];
        for (final item in cols) {
          if (item is Map<String, Object?>) {
            final c = AppCollection.fromJson(item);
            if (c.id.isNotEmpty) loaded.add(c);
          }
        }
        if (loaded.isNotEmpty) {
          repo.collections
            ..clear()
            ..addAll(loaded);
        }
      }

      if (raw['update_cache'] case final Map<String, Object?> uc) {
        for (final e in uc.entries) {
          if (e.value is Map<String, Object?>) {
            repo.updateCache[e.key] = StoreListing.fromJson(
              e.value! as Map<String, Object?>,
            );
          }
        }
      }

      if (raw['version_history'] case final Map<String, Object?> vh) {
        for (final e in vh.entries) {
          if (e.value is List<Object?>) {
            repo.versionHistory[e.key] = [
              for (final r in e.value! as List<Object?>)
                if (r is Map<String, Object?>) AppVersionRecord.fromJson(r),
            ];
          }
        }
      }

      if (raw['vpn_bypass_packages'] case final List<Object?> bps) {
        repo.vpnBypassPackages.addAll([
          for (final p in bps)
            if ('$p'.trim().isNotEmpty) '$p'.trim(),
        ]);
      }

      if (raw['boost_before_launch'] case final bool b) {
        repo.boostBeforeLaunch = b;
      }
      if (raw['use_vpn_proxy_stores'] case final bool v) {
        repo.useVpnProxyForStores = v;
      }
      if (raw['external_proxy_address'] case final String p) {
        repo.externalProxyAddress = p.trim();
      }
      if (raw['gemini_api_key'] case final String k when k.trim().isNotEmpty) {
        repo.legacyMigratedGeminiKey = k.trim();
      }
    } on FileSystemException {
      // First run: use defaults.
    } on FormatException {
      // Corrupt state: recover cleanly with defaults.
    }
    return repo;
  }

  Future<void> save() {
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
          'categories': [for (final c in categories) c.toJson()],
          'app_categories': {
            for (final e in appCategories.entries) e.key: e.value.toList(),
          },
          'collections': [for (final c in collections) c.toJson()],
          'update_cache': {
            for (final e in updateCache.entries) e.key: e.value.toJson(),
          },
          'version_history': {
            for (final e in versionHistory.entries)
              e.key: [for (final r in e.value) r.toJson()],
          },
          'vpn_bypass_packages': vpnBypassPackages.toList()..sort(),
          'boost_before_launch': boostBeforeLaunch,
          'use_vpn_proxy_stores': useVpnProxyForStores,
          'external_proxy_address': externalProxyAddress,
        }),
      );
    } on FileSystemException {
      // Keep running with in-memory state if disk write fails.
    }
  }

  void recordVersionObservation(String package, AppVersionRecord record) {
    if (package.isEmpty || record.versionName.isEmpty) return;
    final list = versionHistory.putIfAbsent(package, () => []);
    final exists = list.any(
      (r) =>
          normalizeDigits(r.versionName) ==
              normalizeDigits(record.versionName) &&
          r.source == record.source,
    );
    if (!exists) {
      list.insert(0, record);
      if (list.length > 25) {
        list.removeRange(25, list.length);
      }
    }
  }
}
