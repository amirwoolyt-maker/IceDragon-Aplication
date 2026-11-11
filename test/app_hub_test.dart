import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icedragon_app_hub/app_hub/app_intelligence.dart';
import 'package:icedragon_app_hub/app_hub/hub_controller.dart';
import 'package:icedragon_app_hub/app_hub/hub_models.dart';
import 'package:icedragon_app_hub/app_hub/hub_repository.dart';
import 'package:icedragon_app_hub/app_hub/pages/app_compare_page.dart';
import 'package:icedragon_app_hub/app_hub/pages/app_profile_page.dart';
import 'package:icedragon_app_hub/app_hub/pages/apps_manager_page.dart';
import 'package:icedragon_app_hub/app_hub/pages/assistant_hub_page.dart';
import 'package:icedragon_app_hub/app_hub/pages/hub_settings_page.dart';
import 'package:icedragon_app_hub/app_hub/pages/store_hub_page.dart';
import 'package:icedragon_app_hub/app_hub/store_aggregator.dart';
import 'package:icedragon_app_hub/hub_settings.dart';
import 'package:icedragon_app_hub/hub_shell.dart';
import 'package:icedragon_app_hub/main.dart';
import 'package:icedragon_app_hub/theme/hub_theme.dart';

class _FakeHubPlatform implements HubPlatform {
  final List<String> launched = [];
  final List<String> uninstalled = [];
  final List<String> openedSettings = [];
  final List<(String, String)> openedStores = [];
  final List<String> shared = [];
  final Map<String, String> secrets = {};
  final String dirPath;
  int openedVpnSettingsCount = 0;

  _FakeHubPlatform({this.dirPath = ''});

  bool launchReturn = true;
  bool uninstallReturn = true;
  Future<bool> Function(String package)? onUninstall;

  List<InstalledAppDetail> apps = [
    InstalledAppDetail(
      package: 'com.picsart.studio',
      label: 'Picsart',
      versionName: '20.0.0',
      versionCode: 2000,
      lastUpdateTime: DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch,
      apkBytes: 95 * 1024 * 1024,
      cacheBytes: 12 * 1024 * 1024,
      minSdk: 24,
      installer: 'com.farsitel.bazaar',
      permissions: const [
        'android.permission.CAMERA',
        'android.permission.INTERNET',
      ],
      grantedPermissions: const ['android.permission.CAMERA'],
    ),
    InstalledAppDetail(
      package: 'com.niksoftware.snapseed',
      label: 'Snapseed',
      versionName: '2.22.0',
      versionCode: 222,
      lastUpdateTime: DateTime.now()
          .subtract(const Duration(days: 240))
          .millisecondsSinceEpoch,
      apkBytes: 38 * 1024 * 1024,
      minSdk: 24,
      installer: 'com.android.vending',
      permissions: const [
        'android.permission.READ_EXTERNAL_STORAGE',
      ],
    ),
    InstalledAppDetail(
      package: 'com.example.calculator',
      label: 'Simple Calc',
      versionName: '1.0.0',
      versionCode: 1,
      lastUpdateTime: DateTime.now()
          .subtract(const Duration(days: 10))
          .millisecondsSinceEpoch,
      apkBytes: 4 * 1024 * 1024,
      minSdk: 23,
      permissions: const [
        'android.permission.READ_SMS',
        'android.permission.READ_CONTACTS',
        'android.permission.ACCESS_BACKGROUND_LOCATION',
      ],
      grantedPermissions: const [
        'android.permission.READ_SMS',
        'android.permission.READ_CONTACTS',
      ],
    ),
  ];

  @override
  Future<Uint8List?> appIcon(String package) async => null;

  @override
  Future<BoostReport?> boostMemory(String launchedPackage) async => BoostReport(
    beforeAvailBytes: 1800 * 1024 * 1024,
    afterAvailBytes: 2150 * 1024 * 1024,
    totalRamBytes: 8192 * 1024 * 1024,
    processesTrimmed: 0,
    launchedPackage: launchedPackage,
  );

  @override
  Future<String> dataDir() async => dirPath;

  @override
  Future<DeviceEnvironment> deviceInfo() async => const DeviceEnvironment(
    sdkInt: 34,
    androidRelease: '14',
    model: 'Pixel Test',
    totalRamBytes: 8192 * 1024 * 1024,
    availRamBytes: 2048 * 1024 * 1024,
    totalStorageBytes: 128 * 1024 * 1024 * 1024,
    freeStorageBytes: 24 * 1024 * 1024 * 1024,
    hasUsageAccess: false,
  );

  @override
  Future<List<InstalledAppDetail>> installedAppsDetailed() async => [...apps];

  @override
  Future<bool> launchApp(String package) async {
    launched.add(package);
    return launchReturn;
  }

  @override
  Future<bool> openAppSettings(String package) async {
    openedSettings.add(package);
    return true;
  }

  @override
  Future<bool> openStore(
    String package,
    String store, {
    String fallbackUrl = '',
  }) async {
    openedStores.add((package, store));
    return true;
  }

  @override
  Future<bool> openUsageAccessSettings() async => true;

  @override
  Future<bool> openVpnSettings() async {
    openedVpnSettingsCount++;
    return true;
  }

  @override
  Future<bool> saveSecret(String key, String value) async {
    if (value.isEmpty) {
      secrets.remove(key);
    } else {
      secrets[key] = value;
    }
    return true;
  }

  @override
  Future<String> readSecret(String key) async => secrets[key] ?? '';

  @override
  Future<bool> shareText(String text, {String subject = ''}) async {
    shared.add(text);
    return true;
  }

  @override
  Future<bool> uninstallApp(String package) async {
    uninstalled.add(package);
    final ok = onUninstall != null
        ? await onUninstall!(package)
        : uninstallReturn;
    if (ok) {
      apps.removeWhere((a) => a.package == package);
    }
    return ok;
  }
}

class _StubStoreAggregator extends StoreAggregator {
  @override
  Future<void> enrichUnifiedApp(
    UnifiedAppResult unified, {
    String hl = 'en',
    String? proxyAddress,
  }) async {}

  @override
  Future<UnifiedAppResult> fetchUnifiedApp(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async => UnifiedAppResult(packageName: packageName);

  @override
  Future<List<AppVersionRecord>> fetchVersionHistory(
    String packageName, {
    String? proxyAddress,
    List<AppVersionRecord> localRecords = const [],
    UnifiedAppResult? unified,
  }) async => localRecords;

  @override
  Future<List<UnifiedAppResult>> fetchAppRadar({
    String hl = 'en',
    String? proxyAddress,
  }) async => const [];

  @override
  Future<MultiStoreSearchResponse> searchAcrossStores(
    String query, {
    String hl = 'en',
    String? proxyAddress,
    int limitPerStore = 12,
    int enrichTop = 8,
  }) async => const MultiStoreSearchResponse(
    results: [],
    storeReachable: {
      StoreId.googlePlay: true,
      StoreId.bazaar: true,
      StoreId.myket: true,
    },
    storeErrors: {},
  );
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  theme: buildLightGlassTheme(),
  darkTheme: buildDarkGlassTheme(),
  themeMode: ThemeMode.dark,
  supportedLocales: const [Locale('en'), Locale('fa')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

void main() {
  test('normalizeDigits, version comparison and minSdk parsing', () {
    expect(normalizeDigits('۲.۲۶.۴۴.۷۵'), '2.26.44.75');
    expect(compareSemanticVersions('2.26.44.75', '2.25.10'), greaterThan(0));
    expect(
      isRemoteVersionNewer(
        localVersion: '20.0.0',
        localCode: 2000,
        remoteVersion: '31.1.6',
        remoteCode: 3101,
      ),
      isTrue,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '31.1.6',
        localCode: 3101,
        remoteVersion: '31.1.6',
        remoteCode: 3101,
      ),
      isFalse,
    );
    expect(parseMinSdkFromLabel('Android 7.0+'), 24);
    expect(parseMinSdkFromLabel('6.0 and up'), 23);
    expect(sdkToAndroidVersion(14), '4.0');
    expect(formatMinAndroidFromSdk(14), 'Android 4.0+');
  });

  test('CategoryClassifier assigns multiple broad categories', () {
    const app = InstalledAppDetail(
      package: 'com.openai.chatgpt',
      label: 'ChatGPT AI Assistant',
    );
    final cats = CategoryClassifier.inferCategories(
      app: app,
      storeCategory: 'Productivity',
    );
    expect(cats, containsAll(['ai', 'productivity']));
  });

  test('Store parsers decode Bazaar, Myket and Google Play payloads', () {
    final bazaarSearch = jsonEncode({
      'singleReply': {
        'searchReply': {
          'resultRows': [
            {
              'app': {
                'packageName': 'com.picsart.studio',
                'name': 'Picsart',
                'image': 'https://s.cafebazaar.ir/icon.webp',
                'versionCode': 3000,
                'minimumSdkVersion': 23,
                'rate': 4.6,
                'price': 0,
                'priceString': 'رایگان',
                'category': 'عکاسی و ویدیو',
              },
            },
          ],
        },
      },
    });
    final bz = StoreAggregator.parseBazaarSearchJson(bazaarSearch);
    expect(bz.length, 1);
    expect(bz.first.packageName, 'com.picsart.studio');
    expect(bz.first.isFree, isTrue);
    expect(bz.first.minSdk, 23);

    const myketHtml = '''
      <html><head>
      <script type="application/ld+json">
      {"@type":"SoftwareApplication","name":"پیکس‌آرت","applicationCategory":"Photography","image":"https://myket.ir/icon.png","softwareVersion":"31.1.0","aggregateRating":{"ratingValue":"4.5","ratingCount":"1200"},"offers":{"price":"0"}}
      </script>
      </head><body>
      <table><tr><td>نسخه</td><td>۳۱.۱.۰</td></tr><tr><td>حجم</td><td>۸۵ مگابایت</td></tr></table>
      </body></html>
    ''';
    final mk = StoreAggregator.parseMyketDetailsHtml(
      'com.picsart.studio',
      myketHtml,
    );
    expect(mk, isNotNull);
    expect(mk!.versionName, '31.1.0');
    expect(mk.sizeBytes, greaterThan(80 * 1024 * 1024));

    const gpHtml = '''
      <script type="application/ld+json">
      {"@type":"SoftwareApplication","name":"Picsart AI Photo Editor","description":"Edit photos","applicationCategory":"PHOTOGRAPHY","image":"https://play-lh.googleusercontent.com/icon","author":{"name":"PicsArt"},"aggregateRating":{"ratingValue":"4.7","ratingCount":"9999"},"offers":[{"price":"0","priceCurrency":"USD"}]}
      </script>
    ''';
    final gp = StoreAggregator.parseGooglePlayDetailsHtml(
      'com.picsart.studio',
      gpHtml,
    );
    expect(gp, isNotNull);
    expect(gp!.title, 'Picsart AI Photo Editor');
    expect(gp.isFree, isTrue);

    final unified = UnifiedAppResult(packageName: 'com.picsart.studio');
    unified.mergeListing(bz.first);
    unified.mergeListing(mk);
    unified.mergeListing(gp);
    expect(unified.listings.length, 3);
    expect(unified.availableInAllThree, isTrue);
  });

  test('HubRepository persists categories, collections, bypass plan & excludes Gemini key', () async {
    final dir = Directory.systemTemp.createTempSync('hub_repo_test_');
    try {
      final repo = await HubRepository.load(dir.path);
      repo.appCategories['com.picsart.studio'] = {'media', 'ai'};
      repo.geminiApiKey = 'test-key';
      repo.vpnBypassPackages.add('com.picsart.studio');
      repo.externalProxyAddress = '127.0.0.1:10808';
      final col = AppCollection(
        id: 'c1',
        nameEn: 'My Top',
        nameFa: 'برترین‌ها',
        items: const [
          CollectionAppEntry(
            packageName: 'com.picsart.studio',
            title: 'Picsart',
          ),
        ],
      );
      repo.collections.add(col);
      await repo.save();

      final reloaded = await HubRepository.load(dir.path);
      expect(
        reloaded.appCategories['com.picsart.studio'],
        containsAll(['media', 'ai']),
      );
      expect(reloaded.vpnBypassPackages, contains('com.picsart.studio'));
      expect(reloaded.externalProxyAddress, '127.0.0.1:10808');
      expect(reloaded.geminiApiKey, isEmpty);

      final rawDisk = File(
        '${dir.path}/hub_data/app-hub-state.json',
      ).readAsStringSync();
      expect(rawDisk, isNot(contains('gemini_api_key')));
      expect(rawDisk, isNot(contains('test-key')));

      final shared = col.toShareText(fa: true);
      final imported = AppCollection.tryParseShared(shared);
      expect(imported, isNotNull);
      expect(imported!.items.first.packageName, 'com.picsart.studio');
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('AppIntelligence detects large, stale, duplicate & risky apps', () {
    final platform = _FakeHubPlatform();
    final intel = AppIntelligence(stores: StoreAggregator());
    final report = intel.analyzePhone(
      device: const DeviceEnvironment(),
      apps: platform.apps,
      updateCache: {
        'com.picsart.studio': const StoreListing(
          store: StoreId.bazaar,
          packageName: 'com.picsart.studio',
          title: 'Picsart',
          versionName: '31.1.6',
          versionCode: 3116,
        ),
      },
      appCategories: {
        'com.picsart.studio': {'media'},
        'com.niksoftware.snapseed': {'media'},
        'com.example.calculator': {'tools'},
      },
    );

    expect(report.largeApps.first.package, 'com.picsart.studio');
    expect(report.outdatedApps.length, 1);
    expect(
      report.staleApps.any((a) => a.package == 'com.niksoftware.snapseed'),
      isTrue,
    );
    expect(report.duplicateGroups.length, 1);
    expect(report.duplicateGroups.first.roleKey, 'photo_editor');
    expect(
      report.permissionAudits.any((p) => p.app.package == 'com.example.calculator'),
      isTrue,
    );
  });

  testWidgets('AppsManagerPage supports search, update badges, multi-select & launch', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final repo = HubRepository()
      ..updateCache['com.picsart.studio'] = const StoreListing(
        store: StoreId.bazaar,
        packageName: 'com.picsart.studio',
        title: 'Picsart',
        versionName: '31.1.6',
        versionCode: 3116,
      );
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: repo,
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(_wrap(AppsManagerPage(hub: hub)));
    await tester.pumpAndSettle();

    expect(find.text('Picsart'), findsOneWidget);
    expect(find.text('Snapseed'), findsOneWidget);
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.rocket_launch_rounded).first);
    await tester.pumpAndSettle();
    expect(platform.launched, isNotEmpty);

    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picsart'));
    await tester.tap(find.text('Snapseed'));
    await tester.pumpAndSettle();
    expect(find.text('Compare'), findsOneWidget);
  });

  testWidgets('AppComparePage renders comparison table in Persian & English', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(
      _wrap(
        AppComparePage(
          hub: hub,
          initialA: CompareTarget(
            packageName: platform.apps[0].package,
            installed: platform.apps[0],
          ),
          initialB: CompareTarget(
            packageName: platform.apps[1].package,
            installed: platform.apps[1],
          ),
        ),
        locale: const Locale('fa'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مقایسه واقعی اپلیکیشن‌ها'), findsOneWidget);
    expect(find.text('Picsart'), findsOneWidget);
    expect(find.text('Snapseed'), findsOneWidget);
  });

  testWidgets('StoreHubPage, AssistantHubPage, and AppProfilePage render cleanly', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(_wrap(StoreHubPage(hub: hub)));
    await tester.pumpAndSettle();
    expect(find.text('Multi-Store Hub'), findsOneWidget);

    await tester.pumpWidget(_wrap(AssistantHubPage(hub: hub)));
    await tester.pumpAndSettle();
    expect(find.text('Phone Doctor'), findsOneWidget);
    expect(find.text('Zero-permission ready'), findsOneWidget);
    expect(find.text('Grant access'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        AppProfilePage(
          hub: hub,
          packageName: 'com.picsart.studio',
          installed: platform.apps[0],
          initialUnified: UnifiedAppResult(
            packageName: 'com.picsart.studio',
            listings: {
              StoreId.bazaar: const StoreListing(
                store: StoreId.bazaar,
                packageName: 'com.picsart.studio',
                title: 'Picsart',
                versionName: '31.1.6',
                sizeLabel: '90 MB',
                minAndroidLabel: 'Android 6.0+',
                minSdk: 23,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('App Profile'), findsOneWidget);
    expect(find.text('Picsart'), findsOneWidget);
  });

  test('Store parsers handle real Play variants, Myket card scoping & Bazaar errors', () {
    String gpDs5Html(String title, Object vBlock, {String extra = ''}) {
      final root = List<Object?>.filled(141, null, growable: true);
      root[0] = [title];
      root[140] = vBlock;
      final ds5 = jsonEncode([
        null,
        [null, null, root],
      ]);
      return '''
        <script type="application/ld+json">
        {"@type":"SoftwareApplication","name":"$title","offers":[{"price":"0","priceCurrency":"USD"}]}
        </script>
        $extra
        <script>AF_initDataCallback({key: 'ds:5', hash: '1', data:$ds5, sideChannel: {}});</script>
      ''';
    }

    final picsArtPlayHtml = gpDs5Html(
      'Picsart',
      [
        [
          ['31.1.6'],
        ],
        [
          [
            [36],
          ],
          [
            [
              [23, '6.0'],
            ],
          ],
        ],
      ],
    );
    final picsGp = StoreAggregator.parseGooglePlayDetailsHtml(
      'com.picsart.studio',
      picsArtPlayHtml,
    );
    expect(picsGp, isNotNull);
    expect(picsGp!.versionName, '31.1.6');
    expect(picsGp.minSdk, 23);
    expect(picsGp.minAndroidLabel, 'Android 6.0+');

    final vlcPlayHtml = gpDs5Html(
      'VLC for Android',
      [
        [null, <Object?>[]],
        [
          [
            [26, '8.0'],
          ],
          [null, <Object?>[]],
        ],
      ],
      extra:
          '<a href="/store/apps/details?id=org.videolan.vlcbenchmark">B</a>'
          '<a href="/store/apps/details?id=org.videolan.vlc">Self</a>',
    );
    final vlcGp = StoreAggregator.parseGooglePlayDetailsHtml(
      'org.videolan.vlc',
      vlcPlayHtml,
    );
    expect(vlcGp, isNotNull);
    expect(vlcGp!.minSdk, 26);
    expect(vlcGp.minAndroidLabel, 'Android 8.0+');
    expect(vlcGp.versionName, isEmpty);
    expect(vlcGp.similarPackages, ['org.videolan.vlcbenchmark']);

    final whatsappTargetOnlyHtml = gpDs5Html('WhatsApp', [
      [null, <Object?>[]],
      [
        [
          [35],
        ],
        [null, <Object?>[]],
      ],
    ]);
    final waGp = StoreAggregator.parseGooglePlayDetailsHtml(
      'com.whatsapp',
      whatsappTargetOnlyHtml,
    );
    expect(waGp, isNotNull);
    expect(waGp!.minSdk, isNull);
    expect(waGp.minAndroidLabel, isEmpty);

    const myketSearchHtml = '''
      <div class="list-app"><a href="/app/org.videolan.vlc" class="app-detail-link" title="VLC for Android"><img src="https://myket.ir/asset-files/icons/large/vlc.png" title="دانلود VLC for Android"><p class="app-name">VLC for Android</p></a></div>
      <div class="list-app"><a href="/app/com.mxtech.videoplayer.ad"><img src="https://myket.ir/asset-files/icons/large/mx.png" title="دانلود MX Player"><p class="app-name">MX Player</p></a></div>
      <a href="/app/promo.webp">asset</a>
    ''';
    final mkCards = StoreAggregator.parseMyketSearchHtml(myketSearchHtml);
    expect(mkCards.length, 2);
    expect(mkCards[0].packageName, 'org.videolan.vlc');
    expect(mkCards[0].title, 'VLC for Android');
    expect(mkCards[0].isPriceKnown, isFalse);
    expect(mkCards[1].packageName, 'com.mxtech.videoplayer.ad');
    expect(mkCards[1].title, 'MX Player');

    const myketPartialDetails = '''
      <html><body>
      com.incomplete.app
      <a href="/app/cover.webp">bad</a>
      <a href="/app/org.videolan.vlc">VLC</a>
      </body></html>
    ''';
    final mkDet = StoreAggregator.parseMyketDetailsHtml(
      'com.incomplete.app',
      myketPartialDetails,
    );
    expect(mkDet, isNotNull);
    expect(mkDet!.isPriceKnown, isFalse);
    expect(mkDet.similarPackages, ['org.videolan.vlc']);

    final bzApi14 = StoreAggregator.parseBazaarSearchJson(
      jsonEncode({
        'singleReply': {
          'searchReply': {
            'resultRows': [
              {
                'app': {
                  'packageName': 'ir.app.oldcompat',
                  'name': 'Old Compat',
                  'minimumSdkVersion': 14,
                  'price': 0,
                },
              },
            ],
          },
        },
      }),
    );
    expect(bzApi14.single.minAndroidLabel, 'Android 4.0+');
    expect(StoreAggregator.parseBazaarSearchJson('<html>502</html>'), isEmpty);
    expect(StoreAggregator.parseBazaarDetailsJson('a.b', ''), isNull);
    expect(StoreAggregator.parseBazaarHomeJson('{invalid'), isEmpty);
  });

  test('isRemoteVersionNewer prevents ABI versionCode & Varies false positives', () {
    expect(
      isRemoteVersionNewer(
        localVersion: '2.26.1.0-arm64',
        localCode: 12000,
        remoteVersion: '2.26.1',
        remoteCode: 90012000,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '2.26.0',
        localCode: 100,
        remoteVersion: '2.25.9',
        remoteCode: 900500,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '3.1.0',
        localCode: 300,
        remoteVersion: 'Varies with device',
        remoteCode: 0,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '2.0.5',
        localCode: 20500,
        remoteVersion: '',
        remoteCode: 10020500,
      ),
      isFalse,
    );
    expect(
      isRemoteVersionNewer(
        localVersion: '2.0.5',
        localCode: 20500,
        remoteVersion: '',
        remoteCode: 20600,
      ),
      isTrue,
    );
  });

  test('scanUpdates & autoCategorizeFromStores process all >40 / >20 user apps', () async {
    final platform = _FakeHubPlatform()
      ..apps = [
        for (var i = 0; i < 45; i++)
          InstalledAppDetail(
            package: 'com.test.app$i',
            label: 'Test App $i',
            versionName: '1.0.0',
            versionCode: 100,
            installer: 'com.android.vending',
          ),
      ];
    final stores = _CountingStoreAggregator();
    final hub = HubController(
      platform: platform,
      stores: stores,
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await hub.ensureLoaded();
    final updates = await hub.scanUpdates();
    expect(hub.scanTotal, 45);
    expect(hub.scanDone, 45);
    expect(stores.detailLookups.length, 45);
    expect(updates.length, 45);

    final catCount = await hub.autoCategorizeFromStores();
    expect(catCount, 45);
    expect(stores.unifiedLookups.length, 45);
  });

  testWidgets('AppComparePage shows Unknown (not Free/0) for missing remote data', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await tester.pumpWidget(
      _wrap(
        AppComparePage(
          hub: hub,
          initialA: CompareTarget(
            packageName: platform.apps[0].package,
            installed: platform.apps[0],
          ),
          initialB: const CompareTarget(packageName: 'com.remote.unknown'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unknown'), findsWidgets);
    expect(find.text('Free'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Sequential batch uninstall, standalone VPN bypass plan & launch failure', (
    tester,
  ) async {
    final order = <String>[];
    var inFlight = 0;
    var maxConcurrent = 0;
    final platform = _FakeHubPlatform()
      ..onUninstall = (pkg) async {
        inFlight++;
        if (inFlight > maxConcurrent) maxConcurrent = inFlight;
        order.add(pkg);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        inFlight--;
        return pkg != 'com.example.calculator';
      };
    final repo = HubRepository()
      ..updateCache['com.picsart.studio'] = const StoreListing(
        store: StoreId.bazaar,
        packageName: 'com.picsart.studio',
        title: 'Picsart',
        versionName: '31.1.6',
      );
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: repo,
    );
    addTearDown(hub.dispose);

    await hub.ensureLoaded();
    await hub.runDiagnostics();
    expect(hub.assistantReport!.largeApps.first.package, 'com.picsart.studio');

    await tester.pumpWidget(_wrap(AppsManagerPage(hub: hub)));
    await tester.pumpAndSettle();

    platform.launchReturn = false;
    await tester.tap(find.byIcon(Icons.rocket_launch_rounded).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not launch'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Picsart'));
    await tester.tap(find.text('Snapseed'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ VPN Bypass'));
    await tester.tap(find.text('+ VPN Bypass'));
    await tester.pumpAndSettle();
    expect(
      hub.repo.vpnBypassPackages,
      containsAll(['com.picsart.studio', 'com.niksoftware.snapseed']),
    );
    await tester.tap(find.text('Android VPN Settings'));
    await tester.pumpAndSettle();
    expect(platform.openedVpnSettingsCount, 1);
    ScaffoldMessenger.of(
      tester.element(find.byType(AppsManagerPage)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('- VPN Bypass'));
    await tester.tap(find.text('- VPN Bypass'));
    await tester.pumpAndSettle();
    expect(hub.repo.vpnBypassPackages, isEmpty);
    ScaffoldMessenger.of(
      tester.element(find.byType(AppsManagerPage)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    final uninstallBtn = find.widgetWithText(OutlinedButton, 'Uninstall');
    await tester.ensureVisible(uninstallBtn);
    await tester.tap(uninstallBtn);
    await tester.pumpAndSettle();
    expect(maxConcurrent, 1);
    expect(order, ['com.picsart.studio', 'com.niksoftware.snapseed']);
    expect(hub.updateAvailablePackages, isEmpty);
    expect(
      hub.assistantReport!.largeApps.any((a) => a.package == 'com.picsart.studio'),
      isFalse,
    );
    expect(find.text('Picsart'), findsNothing);
    expect(find.text('2 of 2 app(s) uninstalled'), findsOneWidget);
  });

  test('Keystore migration & Gemini x-goog-api-key header via real loopback HTTP', () async {
    final dir = Directory.systemTemp.createTempSync('hub_sec_test_');
    try {
      final legacyFile = File('${dir.path}/hub_data/app-hub-state.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({'gemini_api_key': 'AIzaLegacyKey99'}));

      final platform = _FakeHubPlatform(dirPath: dir.path);
      final hub = HubController(
        platform: platform,
        stores: _StubStoreAggregator(),
      );
      try {
        await hub.ensureLoaded();
        await hub.repo.save();
        expect(hub.repo.geminiApiKey, 'AIzaLegacyKey99');
        expect(platform.secrets['gemini_api_key'], 'AIzaLegacyKey99');
        expect(
          legacyFile.readAsStringSync(),
          isNot(contains('AIzaLegacyKey99')),
        );
      } finally {
        hub.dispose();
      }

      await HttpOverrides.runWithHttpOverrides(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        try {
          Uri? capturedUri;
          String? capturedHeaderKey;
          server.listen((req) async {
            capturedUri = req.requestedUri;
            capturedHeaderKey = req.headers.value('x-goog-api-key');
            await req.drain<void>();
            req.response.statusCode = 200;
            req.response.headers.contentType = ContentType.json;
            req.response.write(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {
                          'text': jsonEncode({
                            'summary': 'Try Snapseed',
                            'search_query': 'photo editor',
                            'packages': ['com.niksoftware.snapseed'],
                          }),
                        },
                      ],
                    },
                  },
                ],
              }),
            );
            await req.response.close();
          });

          final okIntel = AppIntelligence(
            stores: _StubStoreAggregator(),
            geminiEndpoint: Uri.parse(
              'http://127.0.0.1:${server.port}/generate',
            ),
          );
          final rec = await okIntel.recommendForNeed(
            'edit photos',
            device: const DeviceEnvironment(),
            fa: false,
            geminiApiKey: 'AIzaTestSecret123',
          );
          expect(rec.usedGemini, isTrue);
          expect(capturedUri?.queryParameters.containsKey('key'), isFalse);
          expect(capturedUri.toString(), isNot(contains('AIzaTestSecret123')));
          expect(capturedHeaderKey, 'AIzaTestSecret123');
        } finally {
          await server.close(force: true);
        }
      }, _RealHttpOverrides());
    } finally {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  testWidgets('Collections error, AI error & HubSettings UI validation', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final stores = _FailingStoreAggregator();
    final hub = HubController(
      platform: platform,
      stores: stores,
      intelligence: AppIntelligence(stores: stores),
      repository: HubRepository(),
    );
    addTearDown(hub.dispose);

    await hub.runAiRecommendation('photo editor', fa: false);
    expect(hub.lastError, contains('offline store error'));

    await tester.pumpWidget(_wrap(AssistantHubPage(hub: hub)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Collections'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'invalid-collection-data');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      find.text('Invalid or corrupted collection code. Paste a valid IceDragon code or JSON.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('App Intelligence'));
    await tester.tap(find.text('App Intelligence'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recommendation failed:'), findsOneWidget);

    await hub.setGeminiApiKey('');
    await tester.pumpWidget(
      _wrap(Scaffold(body: HubSettingsPage(hub: hub, settings: HubAppSettings()))),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'bad-proxy');
    await tester.pump();
    final proxySave = find.text('Save').first;
    await tester.ensureVisible(proxySave);
    await tester.tap(proxySave);
    await tester.pump();
    expect(
      find.text('Enter host:port (port 1\u201365535) or leave empty'),
      findsOneWidget,
    );
    ScaffoldMessenger.maybeOf(
      tester.element(find.byType(HubSettingsPage)),
    )?.hideCurrentSnackBar();
    await tester.pumpAndSettle();

    final proxyDelete = find.text('Delete').first;
    await tester.ensureVisible(proxyDelete);
    await tester.tap(proxyDelete);
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);

    await tester.ensureVisible(find.byType(TextField).last);
    expect(find.text('Delete'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'AIzaTypedKey');
    await tester.pump();
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Standalone HubShell switches all 4 tabs and IceDragonHubApp mounts cleanly', (
    tester,
  ) async {
    final platform = _FakeHubPlatform();
    final hub = HubController(
      platform: platform,
      stores: _StubStoreAggregator(),
      repository: HubRepository(),
    );
    final settings = HubAppSettings();

    await tester.pumpWidget(IceDragonHubApp(hub: hub, settings: settings));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HubShell), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );

    for (final (idx, icon) in [
      (1, Icons.travel_explore_outlined),
      (2, Icons.auto_awesome_outlined),
      (3, Icons.settings_outlined),
      (0, Icons.apps_outlined),
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        idx,
      );
    }

    await tester.pumpWidget(const SizedBox());
  });
}

class _CountingStoreAggregator extends StoreAggregator {
  final List<String> detailLookups = [];
  final List<String> unifiedLookups = [];

  @override
  Future<StoreListing?> fetchBazaarDetails(
    String packageName, {
    String? proxyAddress,
  }) async => null;

  @override
  Future<StoreListing?> fetchMyketDetails(
    String packageName, {
    String? proxyAddress,
  }) async => null;

  @override
  Future<StoreListing?> fetchGooglePlayDetails(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    detailLookups.add(packageName);
    return StoreListing(
      store: StoreId.googlePlay,
      packageName: packageName,
      title: packageName,
      versionName: '2.0.0',
      versionCode: 200,
    );
  }

  @override
  Future<UnifiedAppResult> fetchUnifiedApp(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    unifiedLookups.add(packageName);
    return UnifiedAppResult(
      packageName: packageName,
      listings: {
        StoreId.googlePlay: StoreListing(
          store: StoreId.googlePlay,
          packageName: packageName,
          title: packageName,
          category: 'Productivity',
        ),
      },
    );
  }
}

class _FailingStoreAggregator extends _StubStoreAggregator {
  @override
  Future<MultiStoreSearchResponse> searchAcrossStores(
    String query, {
    String hl = 'en',
    String? proxyAddress,
    int limitPerStore = 12,
    int enrichTop = 8,
  }) async => throw const HttpException('offline store error');
}

extension on UnifiedAppResult {
  bool get availableInAllThree =>
      listings.containsKey(StoreId.googlePlay) &&
      listings.containsKey(StoreId.bazaar) &&
      listings.containsKey(StoreId.myket);
}

class _RealHttpOverrides extends HttpOverrides {}
