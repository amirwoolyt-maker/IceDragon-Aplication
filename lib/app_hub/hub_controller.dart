import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../platform/app_hub_platform.dart';
import 'app_intelligence.dart';
import 'hub_models.dart';
import 'hub_repository.dart';
import 'store_aggregator.dart';

/// Platform bridge used by [HubController]; overridden in tests.
abstract class HubPlatform {
  Future<String> dataDir();
  Future<DeviceEnvironment> deviceInfo();
  Future<List<InstalledAppDetail>> installedAppsDetailed();
  Future<Uint8List?> appIcon(String package);
  Future<bool> openAppSettings(String package);
  Future<bool> uninstallApp(String package);
  Future<bool> launchApp(String package);
  Future<BoostReport?> boostMemory(String launchedPackage);
  Future<bool> openUsageAccessSettings();
  Future<bool> openVpnSettings();
  Future<bool> shareText(String text, {String subject = ''});
  Future<bool> openStore(
    String package,
    String store, {
    String fallbackUrl = '',
  });
  Future<bool> saveSecret(String key, String value);
  Future<String> readSecret(String key);
}

class AndroidHubPlatform implements HubPlatform {
  const AndroidHubPlatform();

  @override
  Future<String> dataDir() => AppHubPlatformChannel.dataDir();

  @override
  Future<DeviceEnvironment> deviceInfo() async {
    final map = await AppHubPlatformChannel.deviceInfo();
    return map.isEmpty
        ? const DeviceEnvironment()
        : DeviceEnvironment.fromPlatformMap(map);
  }

  @override
  Future<List<InstalledAppDetail>> installedAppsDetailed() async {
    final list = await AppHubPlatformChannel.installedAppsDetailed();
    return [for (final m in list) InstalledAppDetail.fromPlatformMap(m)];
  }

  @override
  Future<Uint8List?> appIcon(String package) =>
      AppHubPlatformChannel.appIcon(package);

  @override
  Future<bool> openAppSettings(String package) =>
      AppHubPlatformChannel.openAppSettings(package);

  @override
  Future<bool> uninstallApp(String package) =>
      AppHubPlatformChannel.uninstallApp(package);

  @override
  Future<bool> launchApp(String package) =>
      AppHubPlatformChannel.launchApp(package);

  @override
  Future<BoostReport?> boostMemory(String launchedPackage) async {
    final res = await AppHubPlatformChannel.boostMemory(
      exclude: [launchedPackage],
    );
    if (res.isEmpty) return null;
    return BoostReport.fromPlatformMap(res, launchedPackage);
  }

  @override
  Future<bool> openUsageAccessSettings() =>
      AppHubPlatformChannel.openUsageAccessSettings();

  @override
  Future<bool> openVpnSettings() => AppHubPlatformChannel.openVpnSettings();

  @override
  Future<bool> shareText(String text, {String subject = ''}) =>
      AppHubPlatformChannel.shareText(text, subject: subject);

  @override
  Future<bool> openStore(
    String package,
    String store, {
    String fallbackUrl = '',
  }) => AppHubPlatformChannel.openStore(package, store, fallbackUrl: fallbackUrl);

  @override
  Future<bool> saveSecret(String key, String value) =>
      AppHubPlatformChannel.saveSecret(key, value);

  @override
  Future<String> readSecret(String key) =>
      AppHubPlatformChannel.readSecret(key);
}

/// Validates a `host:port` HTTP/SOCKS proxy string such as `127.0.0.1:10808`.
bool isValidProxyHostPort(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return false;
  final idx = t.lastIndexOf(':');
  if (idx <= 0 || idx >= t.length - 1) return false;
  final host = t.substring(0, idx).trim();
  final port = int.tryParse(t.substring(idx + 1).trim());
  if (host.isEmpty || host.contains(RegExp(r'\s')) || port == null) {
    return false;
  }
  return port > 0 && port <= 65535;
}

/// Shared state controller for App Manager, Multi-Store Hub, Phone Assistant,
/// Collections, Central Updates, and App Intelligence.
class HubController extends ChangeNotifier {
  HubController({
    HubPlatform? platform,
    StoreAggregator? stores,
    AppIntelligence? intelligence,
    HubRepository? repository,
    this.externalProxyResolver,
    this.onApplyVpnBypass,
  }) : platform = platform ?? const AndroidHubPlatform(),
       stores = stores ?? StoreAggregator(),
       _repo = repository {
    this.intelligence = intelligence ?? AppIntelligence(stores: this.stores);
  }

  final HubPlatform platform;
  final StoreAggregator stores;
  late final AppIntelligence intelligence;

  /// Optional callback when an external VPN service supplies an HTTP proxy.
  final String? Function()? externalProxyResolver;

  /// Optional callback when an external VPN core enforces per-app bypass rules.
  final Future<bool> Function(Set<String> packages, {required bool bypass})?
      onApplyVpnBypass;

  HubRepository? _repo;
  HubRepository get repo => _repo ??= HubRepository();

  bool _loaded = false;
  bool get loaded => _loaded;

  DeviceEnvironment device = const DeviceEnvironment();
  List<InstalledAppDetail> installedApps = const [];
  final Map<String, Future<Uint8List?>> _icons = {};

  bool loadingApps = false;
  bool categorizing = false;
  bool scanningUpdates = false;
  int scanDone = 0;
  int scanTotal = 0;
  bool searchingStores = false;
  bool loadingRadar = false;
  bool runningAi = false;

  MultiStoreSearchResponse? searchResponse;
  List<UnifiedAppResult> radarApps = const [];
  AiRecommendationResult? aiResult;
  AssistantReport? assistantReport;
  String lastError = '';

  /// Active local HTTP proxy for store queries when configured and enabled.
  String? get activeProxyAddress {
    if (!repo.useVpnProxyForStores) return null;
    final resolved = externalProxyResolver?.call()?.trim();
    if (resolved != null && isValidProxyHostPort(resolved)) return resolved;
    final manual = repo.externalProxyAddress.trim();
    return isValidProxyHostPort(manual) ? manual : null;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (_repo == null) {
      final dir = await platform.dataDir();
      _repo = await HubRepository.load(dir);
    }
    final r = repo;
    if (r.legacyMigratedGeminiKey.isNotEmpty) {
      await platform.saveSecret('gemini_api_key', r.legacyMigratedGeminiKey);
      r.geminiApiKey = r.legacyMigratedGeminiKey;
      r.legacyMigratedGeminiKey = '';
      await r.save();
    } else if (r.geminiApiKey.isEmpty) {
      r.geminiApiKey = await platform.readSecret('gemini_api_key');
    }
    await refreshInstalledApps();
  }

  Future<void> refreshInstalledApps() async {
    loadingApps = true;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        platform.deviceInfo(),
        platform.installedAppsDetailed(),
      ]);
      device = results[0] as DeviceEnvironment;
      installedApps = [...(results[1] as List<InstalledAppDetail>)]
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

      // Seed local category map & version history for newly seen apps,
      // and prune uninstalled apps from caches and diagnostics.
      var changed = false;
      final installedPkgs = {for (final a in installedApps) a.package};
      _icons.removeWhere((k, _) => !installedPkgs.contains(k));
      if (repo.updateCache.isNotEmpty) {
        final beforeLen = repo.updateCache.length;
        repo.updateCache.removeWhere((k, _) => !installedPkgs.contains(k));
        if (repo.updateCache.length != beforeLen) changed = true;
      }
      if (repo.appCategories.isNotEmpty) {
        final beforeLen = repo.appCategories.length;
        repo.appCategories.removeWhere((k, _) => !installedPkgs.contains(k));
        if (repo.appCategories.length != beforeLen) changed = true;
      }
      for (final app in installedApps) {
        if (!repo.appCategories.containsKey(app.package)) {
          repo.appCategories[app.package] = CategoryClassifier.inferCategories(
            app: app,
          );
          changed = true;
        }
        if (app.versionName.isNotEmpty) {
          repo.recordVersionObservation(
            app.package,
            AppVersionRecord(
              versionName: app.versionName,
              versionCode: app.versionCode,
              source: 'Installed',
            ),
          );
        }
      }
      if (changed) unawaited(repo.save());
      if (assistantReport != null) {
        assistantReport = intelligence.analyzePhone(
          device: device,
          apps: installedApps,
          updateCache: repo.updateCache,
          appCategories: repo.appCategories,
        );
      }
    } catch (e) {
      lastError = '$e';
    } finally {
      loadingApps = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> iconFor(String package) =>
      _icons.putIfAbsent(package, () => platform.appIcon(package));

  InstalledAppDetail? findInstalled(String package) {
    for (final a in installedApps) {
      if (a.package == package) return a;
    }
    return null;
  }

  Set<String> categoriesForApp(InstalledAppDetail app) =>
      repo.appCategories[app.package] ??
      CategoryClassifier.inferCategories(app: app);

  Future<void> setAppCategories(String package, Set<String> categoryIds) async {
    repo.appCategories[package] = {...categoryIds};
    notifyListeners();
    await repo.save();
  }

  Future<void> addAppsToCategory(
    Iterable<String> packages,
    String categoryId,
  ) async {
    for (final pkg in packages) {
      final current = {...(repo.appCategories[pkg] ?? const <String>{})};
      current.add(categoryId);
      repo.appCategories[pkg] = current;
    }
    notifyListeners();
    await repo.save();
  }

  Future<AppCategory> createCustomCategory({
    required String nameEn,
    required String nameFa,
    int colorValue = 0xFF816BFF,
  }) async {
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
    final cat = AppCategory(
      id: id,
      nameEn: nameEn.trim().isNotEmpty ? nameEn.trim() : nameFa.trim(),
      nameFa: nameFa.trim().isNotEmpty ? nameFa.trim() : nameEn.trim(),
      iconKey: 'label',
      colorValue: colorValue,
      builtIn: false,
    );
    repo.categories.add(cat);
    notifyListeners();
    await repo.save();
    return cat;
  }

  Future<void> deleteCustomCategory(String id) async {
    repo.categories.removeWhere((c) => c.id == id && !c.builtIn);
    for (final entry in repo.appCategories.entries) {
      entry.value.remove(id);
    }
    notifyListeners();
    await repo.save();
  }

  /// Auto-categorizes user apps by fetching Google Play / store tags (#4).
  Future<int> autoCategorizeFromStores({
    String hl = 'en',
    int? maxFetch,
  }) async {
    categorizing = true;
    notifyListeners();
    var updated = 0;
    try {
      final allTargets = [
        for (final a in installedApps)
          if (!a.system && a.launcher) a,
      ];
      final targets = maxFetch != null && maxFetch > 0
          ? allTargets.take(maxFetch).toList()
          : allTargets;
      final proxy = activeProxyAddress;

      for (var i = 0; i < targets.length; i += 4) {
        final chunk = targets.skip(i).take(4).toList();
        await Future.wait([
          for (final app in chunk)
            () async {
              final unified = await stores
                  .fetchUnifiedApp(app.package, hl: hl, proxyAddress: proxy)
                  .timeout(const Duration(seconds: 12))
                  .catchError((_) => UnifiedAppResult(packageName: app.package));
              final inferred = CategoryClassifier.inferCategories(
                app: app,
                storeCategory: unified.category,
                storeDescription: unified.description,
              );
              final merged = {
                ...(repo.appCategories[app.package] ?? const <String>{}),
                ...inferred,
              };
              repo.appCategories[app.package] = merged;
              updated++;
            }(),
        ]);
        if (i + 4 < targets.length) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          notifyListeners();
        }
      }
      await repo.save();
    } finally {
      categorizing = false;
      notifyListeners();
    }
    return updated;
  }

  /// Available updates computed from cached + scanned store versions (#7, #15).
  List<UpdateCandidate> get availableUpdates {
    final out = <UpdateCandidate>[];
    for (final app in installedApps) {
      final listing = repo.updateCache[app.package];
      if (listing != null &&
          isRemoteVersionNewer(
            localVersion: app.versionName,
            localCode: app.versionCode,
            remoteVersion: listing.versionName,
            remoteCode: listing.versionCode,
          )) {
        out.add(UpdateCandidate(app: app, listing: listing));
      }
    }
    return out;
  }

  Set<String> get updateAvailablePackages => {
    for (final u in availableUpdates) u.app.package,
  };

  /// Scans installed user apps across stores for updates (#7, #15).
  Future<List<UpdateCandidate>> scanUpdates({String hl = 'en'}) async {
    scanningUpdates = true;
    scanDone = 0;
    scanTotal = installedApps.where((a) => !a.system && a.launcher).length;
    notifyListeners();

    try {
      final found = await stores.checkInstalledUpdates(
        installedApps,
        hl: hl,
        proxyAddress: activeProxyAddress,
        onProgress: (d, t) {
          scanDone = d;
          scanTotal = t;
          notifyListeners();
        },
      );
      for (final u in found) {
        repo.updateCache[u.app.package] = u.listing;
        repo.recordVersionObservation(
          u.app.package,
          AppVersionRecord(
            versionName: u.listing.versionName,
            versionCode: u.listing.versionCode,
            source: u.listing.store.nameEn,
            dateLabel: u.listing.lastUpdatedLabel,
            sizeLabel: u.listing.sizeLabel,
          ),
        );
      }
      await repo.save();
      return found;
    } finally {
      scanningUpdates = false;
      notifyListeners();
    }
  }

  /// Runs non-root Speed Boost (when enabled) and launches [package] (#5).
  Future<(bool launched, BoostReport? report)> boostAndLaunch(
    String package,
  ) async {
    BoostReport? report;
    if (repo.boostBeforeLaunch) {
      report = await platform.boostMemory(package);
    }
    final launched = await platform.launchApp(package);
    return (launched, report);
  }

  /// Runs unified multi-store search (#9 & #10).
  Future<void> searchStores(String query, {required String hl}) async {
    searchingStores = true;
    lastError = '';
    notifyListeners();
    try {
      searchResponse = await stores.searchAcrossStores(
        query,
        hl: hl,
        proxyAddress: activeProxyAddress,
      );
    } catch (e) {
      lastError = '$e';
    } finally {
      searchingStores = false;
      notifyListeners();
    }
  }

  /// Loads trending apps for App Radar (#16).
  Future<void> loadRadar({required String hl}) async {
    loadingRadar = true;
    notifyListeners();
    try {
      radarApps = await stores.fetchAppRadar(
        hl: hl,
        proxyAddress: activeProxyAddress,
      );
    } catch (e) {
      lastError = '$e';
    } finally {
      loadingRadar = false;
      notifyListeners();
    }
  }

  /// Runs Phone Management Assistant diagnostics (#12).
  Future<AssistantReport> runDiagnostics() async {
    if (installedApps.isEmpty) {
      await refreshInstalledApps();
    }
    final report = intelligence.analyzePhone(
      device: device,
      apps: installedApps,
      updateCache: repo.updateCache,
      appCategories: repo.appCategories,
    );
    assistantReport = report;
    notifyListeners();
    return report;
  }

  /// Runs hybrid App Intelligence recommendation (#16).
  Future<void> runAiRecommendation(String query, {required bool fa}) async {
    runningAi = true;
    lastError = '';
    notifyListeners();
    try {
      aiResult = await intelligence.recommendForNeed(
        query,
        device: device,
        fa: fa,
        geminiApiKey: repo.geminiApiKey,
        proxyAddress: activeProxyAddress,
      );
    } catch (e) {
      lastError = '$e';
      aiResult = null;
    } finally {
      runningAi = false;
      notifyListeners();
    }
  }

  // Collections (#14)
  Future<AppCollection> createCollection({
    required String name,
    String description = '',
  }) async {
    final c = AppCollection(
      id: 'col_${DateTime.now().millisecondsSinceEpoch}',
      nameEn: name.trim(),
      nameFa: name.trim(),
      descriptionEn: description.trim(),
      descriptionFa: description.trim(),
      isPreset: false,
    );
    repo.collections.add(c);
    notifyListeners();
    await repo.save();
    return c;
  }

  Future<void> deleteCollection(String id) async {
    repo.collections.removeWhere((c) => c.id == id && !c.isPreset);
    notifyListeners();
    await repo.save();
  }

  Future<void> addEntryToCollection(
    String collectionId,
    CollectionAppEntry entry,
  ) async {
    final idx = repo.collections.indexWhere((c) => c.id == collectionId);
    if (idx < 0) return;
    final col = repo.collections[idx];
    if (col.containsPackage(entry.packageName)) return;
    repo.collections[idx] = col.copyWith(items: [...col.items, entry]);
    notifyListeners();
    await repo.save();
  }

  Future<void> removeFromCollection(
    String collectionId,
    String packageName,
  ) async {
    final idx = repo.collections.indexWhere((c) => c.id == collectionId);
    if (idx < 0) return;
    final col = repo.collections[idx];
    repo.collections[idx] = col.copyWith(
      items: [
        for (final i in col.items)
          if (i.packageName != packageName) i,
      ],
    );
    notifyListeners();
    await repo.save();
  }

  Future<bool> importSharedCollection(String raw) async {
    final parsed = AppCollection.tryParseShared(raw);
    if (parsed == null) return false;
    repo.collections.add(parsed);
    notifyListeners();
    await repo.save();
    return true;
  }

  // Standalone VPN Bypass plan & external VPN settings integration (#2 & #3)
  Future<bool> setVpnBypassForPackages(
    Set<String> packages, {
    required bool bypass,
  }) async {
    if (bypass) {
      repo.vpnBypassPackages.addAll(packages);
    } else {
      repo.vpnBypassPackages.removeAll(packages);
    }
    notifyListeners();
    await repo.save();

    final handler = onApplyVpnBypass;
    if (handler != null) {
      return handler(packages, bypass: bypass);
    }
    return false;
  }

  Future<void> clearVpnBypassPlan() async {
    if (repo.vpnBypassPackages.isEmpty) return;
    repo.vpnBypassPackages.clear();
    notifyListeners();
    await repo.save();
  }

  Future<bool> openVpnSettings() => platform.openVpnSettings();

  // Hub preferences
  Future<void> setBoostBeforeLaunch(bool value) async {
    repo.boostBeforeLaunch = value;
    notifyListeners();
    await repo.save();
  }

  Future<void> setUseVpnProxyForStores(bool value) async {
    repo.useVpnProxyForStores = value;
    notifyListeners();
    await repo.save();
  }

  Future<bool> setExternalProxyAddress(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty && !isValidProxyHostPort(trimmed)) {
      return false;
    }
    repo.externalProxyAddress = trimmed;
    notifyListeners();
    await repo.save();
    return true;
  }

  Future<void> setGeminiApiKey(String key) async {
    final trimmed = key.trim();
    repo.geminiApiKey = trimmed;
    notifyListeners();
    await platform.saveSecret('gemini_api_key', trimmed);
  }
}
