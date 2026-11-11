import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'hub_models.dart';

/// Result of a parallel multi-store search across Google Play, Cafe Bazaar,
/// and Myket, merged by `packageName` into unified entries.
class MultiStoreSearchResponse {
  const MultiStoreSearchResponse({
    required this.results,
    required this.storeReachable,
    required this.storeErrors,
  });

  final List<UnifiedAppResult> results;
  final Map<StoreId, bool> storeReachable;
  final Map<StoreId, String> storeErrors;
}

/// Real multi-store client querying Google Play, Cafe Bazaar, Myket, and
/// F-Droid (for open-source version histories) in parallel, optionally routing
/// through IceDragon VPN's local proxy (`127.0.0.1:<port>`).
class StoreAggregator {
  StoreAggregator({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  HttpClient _openClient(String? proxyAddress) {
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 12);
    if (proxyAddress != null && proxyAddress.trim().isNotEmpty) {
      final p = proxyAddress.trim();
      client.findProxy = (_) => 'PROXY $p; DIRECT';
    }
    return client;
  }

  Future<(int, String)> _get(
    HttpClient client,
    String url, {
    Map<String, String> headers = const {},
  }) async {
    final req = await client
        .getUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 14));
    req.headers.set(HttpHeaders.userAgentHeader, _ua);
    headers.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close().timeout(const Duration(seconds: 14));
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 14))) {
      bytes.add(chunk);
      if (bytes.length > 4 * 1024 * 1024) break;
    }
    return (res.statusCode, utf8.decode(bytes.takeBytes(), allowMalformed: true));
  }

  Future<(int, String)> _postJson(
    HttpClient client,
    String url,
    Map<String, Object?> body,
  ) async {
    final req = await client
        .postUrl(Uri.parse(url))
        .timeout(const Duration(seconds: 14));
    req.headers
      ..set(HttpHeaders.userAgentHeader, _ua)
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close().timeout(const Duration(seconds: 14));
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 14))) {
      bytes.add(chunk);
      if (bytes.length > 4 * 1024 * 1024) break;
    }
    return (res.statusCode, utf8.decode(bytes.takeBytes(), allowMalformed: true));
  }

  /// Searches Google Play, Cafe Bazaar, and Myket simultaneously and merges
  /// duplicate hits for the same package into ONE [UnifiedAppResult].
  Future<MultiStoreSearchResponse> searchAcrossStores(
    String query, {
    String hl = 'en',
    String? proxyAddress,
    int limitPerStore = 12,
    int enrichTop = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const MultiStoreSearchResponse(
        results: [],
        storeReachable: {},
        storeErrors: {},
      );
    }

    final reachable = <StoreId, bool>{};
    final errors = <StoreId, String>{};
    final byPkg = <String, UnifiedAppResult>{};
    final order = <String>[];

    void addHits(StoreId store, List<StoreListing> hits) {
      for (final h in hits.take(limitPerStore)) {
        if (h.packageName.isEmpty) continue;
        final existing = byPkg[h.packageName];
        if (existing == null) {
          order.add(h.packageName);
          byPkg[h.packageName] = UnifiedAppResult(
            packageName: h.packageName,
            listings: {h.store: h},
          );
        } else {
          existing.mergeListing(h);
        }
      }
    }

    final directPackage =
        RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$').hasMatch(trimmed);

    await Future.wait([
      () async {
        try {
          final hits = directPackage
              ? [
                  if (await fetchGooglePlayDetails(
                        trimmed,
                        hl: hl,
                        proxyAddress: proxyAddress,
                      )
                      case final d?)
                    d,
                ]
              : await searchGooglePlay(
                  trimmed,
                  hl: hl,
                  proxyAddress: proxyAddress,
                );
          reachable[StoreId.googlePlay] = true;
          addHits(StoreId.googlePlay, hits);
        } catch (e) {
          reachable[StoreId.googlePlay] = false;
          errors[StoreId.googlePlay] = '$e';
        }
      }(),
      () async {
        try {
          final hits = directPackage
              ? [
                  if (await fetchBazaarDetails(
                        trimmed,
                        proxyAddress: proxyAddress,
                      )
                      case final d?)
                    d,
                ]
              : await searchBazaar(trimmed, proxyAddress: proxyAddress);
          reachable[StoreId.bazaar] = true;
          addHits(StoreId.bazaar, hits);
        } catch (e) {
          reachable[StoreId.bazaar] = false;
          errors[StoreId.bazaar] = '$e';
        }
      }(),
      () async {
        try {
          final hits = directPackage
              ? [
                  if (await fetchMyketDetails(
                        trimmed,
                        proxyAddress: proxyAddress,
                      )
                      case final d?)
                    d,
                ]
              : await searchMyket(trimmed, proxyAddress: proxyAddress);
          reachable[StoreId.myket] = true;
          addHits(StoreId.myket, hits);
        } catch (e) {
          reachable[StoreId.myket] = false;
          errors[StoreId.myket] = '$e';
        }
      }(),
    ]);

    // Rank packages found in multiple stores first while keeping query order.
    final ranked = [for (final pkg in order) byPkg[pkg]!];
    ranked.sort((a, b) {
      final sc = b.listings.length.compareTo(a.listings.length);
      if (sc != 0) return sc;
      return b.bestRating.compareTo(a.bestRating);
    });

    // Enrich top results across all 3 stores so size, version, required Android,
    // and cross-store availability are immediately populated.
    if (!directPackage && enrichTop > 0 && ranked.isNotEmpty) {
      await Future.wait([
        for (final item in ranked.take(enrichTop))
          enrichUnifiedApp(item, hl: hl, proxyAddress: proxyAddress),
      ]);
    }

    return MultiStoreSearchResponse(
      results: ranked,
      storeReachable: reachable,
      storeErrors: errors,
    );
  }

  /// Fetches full app profile across Google Play, Cafe Bazaar, and Myket.
  Future<UnifiedAppResult> fetchUnifiedApp(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    final unified = UnifiedAppResult(packageName: packageName);
    await enrichUnifiedApp(unified, hl: hl, proxyAddress: proxyAddress);
    return unified;
  }

  /// Populates missing store listings on [unified] in parallel.
  Future<void> enrichUnifiedApp(
    UnifiedAppResult unified, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    final pkg = unified.packageName;
    final results = await Future.wait<StoreListing?>([
      fetchGooglePlayDetails(pkg, hl: hl, proxyAddress: proxyAddress)
          .catchError((_) => null),
      fetchBazaarDetails(pkg, proxyAddress: proxyAddress)
          .catchError((_) => null),
      fetchMyketDetails(pkg, proxyAddress: proxyAddress)
          .catchError((_) => null),
    ]);
    for (final listing in results) {
      if (listing != null) unified.mergeListing(listing);
    }
  }

  /// Fetches historical versions from F-Droid API (trusted open source) and
  /// combines with store listings & local observations.
  Future<List<AppVersionRecord>> fetchVersionHistory(
    String packageName, {
    String? proxyAddress,
    List<AppVersionRecord> localRecords = const [],
    UnifiedAppResult? unified,
  }) async {
    final out = <AppVersionRecord>[];
    final seen = <String>{};

    void addRec(AppVersionRecord r) {
      if (r.versionName.isEmpty) return;
      final key = '${normalizeDigits(r.versionName)}|${r.source}';
      if (seen.add(key)) out.add(r);
    }

    if (unified != null) {
      for (final l in unified.listings.values) {
        if (l.versionName.isNotEmpty) {
          addRec(
            AppVersionRecord(
              versionName: l.versionName,
              versionCode: l.versionCode,
              source: l.store.nameEn,
              dateLabel: l.lastUpdatedLabel,
              sizeLabel: l.sizeLabel,
              notes: l.changelog,
            ),
          );
        }
      }
    }

    for (final r in localRecords) {
      addRec(r);
    }

    final client = _openClient(proxyAddress);
    try {
      final (status, body) = await _get(
        client,
        'https://f-droid.org/api/v1/packages/$packageName',
        headers: {'Accept': 'application/json'},
      );
      if (status == 200) {
        final j = jsonDecode(body);
        if (j is Map<String, Object?> && j['packages'] is List) {
          for (final item in j['packages']! as List<Object?>) {
            if (item is Map<String, Object?>) {
              final vn = '${item['versionName'] ?? ''}';
              final vc = item['versionCode'] is int
                  ? item['versionCode']! as int
                  : 0;
              addRec(
                AppVersionRecord(
                  versionName: vn,
                  versionCode: vc,
                  source: 'F-Droid',
                ),
              );
            }
          }
        }
      }
    } catch (_) {
      // Closed-source or unreachable F-Droid entry.
    } finally {
      client.close(force: true);
    }

    return out;
  }

  /// Fetches trending & newly featured apps across Cafe Bazaar, Myket, and
  /// Google Play for App Radar (#16).
  Future<List<UnifiedAppResult>> fetchAppRadar({
    String hl = 'en',
    String? proxyAddress,
  }) async {
    final byPkg = <String, UnifiedAppResult>{};
    final order = <String>[];

    void add(StoreListing listing) {
      if (listing.packageName.isEmpty) return;
      final existing = byPkg[listing.packageName];
      if (existing == null) {
        order.add(listing.packageName);
        byPkg[listing.packageName] = UnifiedAppResult(
          packageName: listing.packageName,
          listings: {listing.store: listing},
        );
      } else {
        existing.mergeListing(listing);
      }
    }

    await Future.wait([
      () async {
        try {
          for (final item in await fetchBazaarHomeRadar(
            proxyAddress: proxyAddress,
          )) {
            add(item);
          }
        } catch (_) {}
      }(),
      () async {
        try {
          for (final item in await fetchMyketRadar(
            proxyAddress: proxyAddress,
          )) {
            add(item);
          }
        } catch (_) {}
      }(),
      () async {
        try {
          for (final item in await searchGooglePlay(
            'popular new apps 2026',
            hl: hl,
            proxyAddress: proxyAddress,
          )) {
            add(item);
          }
        } catch (_) {}
      }(),
    ]);

    return [for (final pkg in order.take(30)) byPkg[pkg]!];
  }

  /// Checks installed user apps against connected stores to detect available
  /// updates (#7 & #15).
  Future<List<UpdateCandidate>> checkInstalledUpdates(
    List<InstalledAppDetail> apps, {
    String hl = 'en',
    String? proxyAddress,
    int? maxApps,
    void Function(int checked, int total)? onProgress,
  }) async {
    final eligible = [
      for (final a in apps)
        if (!a.system && a.launcher) a,
    ];
    final candidates = maxApps != null && maxApps > 0
        ? eligible.take(maxApps).toList()
        : eligible;
    final updates = <UpdateCandidate>[];
    var done = 0;

    // Polite bounded concurrency in chunks of 4 with per-app timeout and a
    // short pause between batches to avoid store rate-limiting and memory spikes.
    for (var i = 0; i < candidates.length; i += 4) {
      final chunk = candidates.skip(i).take(4).toList();
      await Future.wait([
        for (final app in chunk)
          () async {
            try {
              final listing = await _fetchBestStoreForUpdate(
                app,
                hl: hl,
                proxyAddress: proxyAddress,
              ).timeout(const Duration(seconds: 12));
              if (listing != null &&
                  isRemoteVersionNewer(
                    localVersion: app.versionName,
                    localCode: app.versionCode,
                    remoteVersion: listing.versionName,
                    remoteCode: listing.versionCode,
                  )) {
                updates.add(UpdateCandidate(app: app, listing: listing));
              }
            } catch (_) {
              // Ignore individual lookup errors and timeouts.
            } finally {
              done++;
              onProgress?.call(done, candidates.length);
            }
          }(),
      ]);
      if (i + 4 < candidates.length) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }
    return updates;
  }

  Future<StoreListing?> _fetchBestStoreForUpdate(
    InstalledAppDetail app, {
    required String hl,
    String? proxyAddress,
  }) async {
    final preferred = app.installerStore;
    if (preferred == StoreId.bazaar) {
      final b = await fetchBazaarDetails(
        app.package,
        proxyAddress: proxyAddress,
      ).catchError((_) => null);
      if (b != null) return b;
    } else if (preferred == StoreId.myket) {
      final m = await fetchMyketDetails(
        app.package,
        proxyAddress: proxyAddress,
      ).catchError((_) => null);
      if (m != null) return m;
    }

    final results = await Future.wait<StoreListing?>([
      fetchBazaarDetails(app.package, proxyAddress: proxyAddress)
          .catchError((_) => null),
      fetchMyketDetails(app.package, proxyAddress: proxyAddress)
          .catchError((_) => null),
      fetchGooglePlayDetails(app.package, hl: hl, proxyAddress: proxyAddress)
          .catchError((_) => null),
    ]);
    StoreListing? best;
    for (final r in results) {
      if (r == null) continue;
      if (best == null ||
          isRemoteVersionNewer(
            localVersion: best.versionName,
            localCode: best.versionCode,
            remoteVersion: r.versionName,
            remoteCode: r.versionCode,
          )) {
        best = r;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Google Play parsers
  // ---------------------------------------------------------------------------

  Future<List<StoreListing>> searchGooglePlay(
    String query, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    final client = _openClient(proxyAddress);
    try {
      final uri = Uri.https('play.google.com', '/store/search', {
        'q': query,
        'c': 'apps',
        'hl': hl,
        'gl': 'us',
      });
      final (status, html) = await _get(client, uri.toString());
      if (status != 200) throw HttpException('Google Play HTTP $status');
      return parseGooglePlaySearchHtml(html);
    } finally {
      client.close(force: true);
    }
  }

  Future<StoreListing?> fetchGooglePlayDetails(
    String packageName, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    final client = _openClient(proxyAddress);
    try {
      final uri = Uri.https('play.google.com', '/store/apps/details', {
        'id': packageName,
        'hl': hl,
        'gl': 'us',
      });
      final (status, html) = await _get(client, uri.toString());
      if (status == 404) return null;
      if (status != 200) return null;
      return parseGooglePlayDetailsHtml(packageName, html);
    } finally {
      client.close(force: true);
    }
  }

  static List<StoreListing> parseGooglePlaySearchHtml(String html) {
    final out = <StoreListing>[];
    final seen = <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    final ds4 = _extractAfCallbackJson(html, 'ds:4');
    if (ds4 != null) {
      _walkGooglePlaySearchNodes(ds4, (item) {
        final pkg = _findPackageIdNode(item);
        if (pkg == null || !seen.add(pkg)) return;
        final title = _firstStringAt(item, const [3]) ??
            _firstShortTextInList(item, exclude: pkg) ??
            pkg;
        final icon = _firstPlayImageUrl(item) ?? '';
        final rating = _firstRatingInList(item);
        final dev = _firstDeveloperInList(item) ?? '';
        out.add(
          StoreListing(
            store: StoreId.googlePlay,
            packageName: pkg,
            title: title,
            developer: dev,
            iconUrl: icon,
            rating: rating,
            storeUrl: 'https://play.google.com/store/apps/details?id=$pkg',
            deepLinkUrl: 'market://details?id=$pkg',
            fetchedAtMs: now,
          ),
        );
      });
    }

    if (out.isEmpty) {
      for (final m in RegExp(
        r'/store/apps/details\?id=([a-zA-Z0-9_.]+)',
      ).allMatches(html)) {
        final pkg = m.group(1)!;
        if (seen.add(pkg)) {
          out.add(
            StoreListing(
              store: StoreId.googlePlay,
              packageName: pkg,
              title: pkg,
              storeUrl: 'https://play.google.com/store/apps/details?id=$pkg',
              deepLinkUrl: 'market://details?id=$pkg',
              fetchedAtMs: now,
            ),
          );
        }
      }
    }
    return out;
  }

  static StoreListing? parseGooglePlayDetailsHtml(
    String packageName,
    String html,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ldList = _extractJsonLdList(html);
    Map<String, Object?>? ld;
    for (final item in ldList) {
      if (item['@type'] == 'SoftwareApplication') {
        ld = item;
        break;
      }
    }

    final ds5 = _extractAfCallbackJson(html, 'ds:5');
    List<Object?>? root;
    if (ds5 is List && ds5.length > 1 && ds5[1] is List) {
      final inner = ds5[1]! as List<Object?>;
      if (inner.length > 2 && inner[2] is List) {
        root = inner[2]! as List<Object?>;
      }
    }

    if (ld == null && root == null) return null;

    var title = '${ld?['name'] ?? ''}';
    if (title.isEmpty && root != null) {
      title = _strAt(root, [0, 0]);
    }
    if (title.isEmpty) title = packageName;

    var description = _stripHtml('${ld?['description'] ?? ''}');
    if (root != null) {
      final fullDesc = _stripHtml(_strAt(root, [72, 0, 1]));
      if (fullDesc.length > description.length) description = fullDesc;
    }

    var iconUrl = '${ld?['image'] ?? ''}';
    if (iconUrl.isEmpty && root != null) {
      iconUrl = _strAt(root, [95, 0, 3, 2]);
    }

    var developer = '';
    if (ld?['author'] case final Map<String, Object?> auth) {
      developer = '${auth['name'] ?? ''}';
    }
    if (developer.isEmpty && root != null) {
      developer = _strAt(root, [68, 0]);
      if (developer.isEmpty) developer = _strAt(root, [37, 0]);
    }

    var rating = 0.0;
    var ratingCount = 0;
    if (ld?['aggregateRating'] case final Map<String, Object?> ar) {
      rating = double.tryParse('${ar['ratingValue']}') ?? 0;
      ratingCount = int.tryParse('${ar['ratingCount']}') ?? 0;
    }

    var isFree = true;
    var priceLabel = '';
    if (ld?['offers'] case final List<Object?> offers when offers.isNotEmpty) {
      if (offers.first case final Map<String, Object?> offer) {
        final rawPrice = '${offer['price'] ?? '0'}';
        final numeric = double.tryParse(rawPrice) ?? 0;
        isFree = numeric <= 0;
        if (isFree) {
          priceLabel = 'Free';
        } else {
          final cur = '${offer['priceCurrency'] ?? 'USD'}';
          priceLabel = '$rawPrice $cur';
        }
      }
    } else if (root != null && _intAt(root, [57, 0, 0, 0, 0, 1, 0, 0]) == 0) {
      priceLabel = 'Free';
    }

    var category = '${ld?['applicationCategory'] ?? ''}';
    if (root != null) {
      final catName = _strAt(root, [79, 0, 0, 0]);
      if (catName.isNotEmpty) category = catName;
    }

    final screenshots = <String>[];
    if (root != null && root.length > 78 && root[78] is List) {
      final outer = root[78]! as List<Object?>;
      if (outer.isNotEmpty && outer[0] is List) {
        for (final entry in outer[0]! as List<Object?>) {
          final url = _strAt(entry, [3, 2]);
          if (url.startsWith('http')) screenshots.add(url);
        }
      }
    }

    var versionName = '';
    int? minSdk;
    var minAndroidLabel = '';
    if (root != null && root.length > 140 && root[140] is List) {
      final vBlock = root[140]! as List<Object?>;
      versionName = _strAt(vBlock, [0, 0, 0]);
      if (versionName.isEmpty) versionName = _strAt(vBlock, [0, 0]);

      // Path A1 (e.g. PicsArt): root[140][1][1][0][0] == [minSdkInt, androidStr]
      var sdkVal = _intAt(vBlock, [1, 1, 0, 0, 0]);
      var androidStr = _strAt(vBlock, [1, 1, 0, 0, 1]);

      // Path A2: root[140][1][1][0] == [minSdkInt, androidStr]
      if (sdkVal == null || sdkVal <= 0) {
        sdkVal = _intAt(vBlock, [1, 1, 0, 0]);
        androidStr = _strAt(vBlock, [1, 1, 0, 1]);
      }

      // Path B (e.g. VLC): root[140][1][0][0] == [minSdkInt, androidStr].
      // Require non-empty androidStr here so bare targetSdk arrays (e.g. [35])
      // are never mistaken for minSdk.
      if (sdkVal == null || sdkVal <= 0) {
        final altSdk = _intAt(vBlock, [1, 0, 0, 0]);
        final altStr = _strAt(vBlock, [1, 0, 0, 1]);
        if (altSdk != null && altSdk > 0 && altStr.isNotEmpty) {
          sdkVal = altSdk;
          androidStr = altStr;
        }
      }

      if (sdkVal != null && sdkVal > 0) minSdk = sdkVal;
      if (androidStr.isNotEmpty) {
        minAndroidLabel = 'Android $androidStr+';
      } else if (minSdk != null) {
        minAndroidLabel = formatMinAndroidFromSdk(minSdk);
      }
    }

    final permissions = <String>[];
    if (root != null && root.length > 74 && root[74] is List) {
      final pOuter = root[74]! as List<Object?>;
      if (pOuter.length > 2 && pOuter[2] is List) {
        for (final grp in pOuter[2]! as List<Object?>) {
          final groupName = _strAt(grp, [0]);
          if (groupName.isNotEmpty) permissions.add(groupName);
        }
      }
    }

    final similar = <String>[];
    for (final dsKey in const ['ds:8', 'ds:6', 'ds:7']) {
      final ds = _extractAfCallbackJson(html, dsKey);
      if (ds != null) {
        _walkGooglePlaySearchNodes(ds, (item) {
          final rel = _findPackageIdNode(item);
          if (rel != null &&
              rel != packageName &&
              !similar.contains(rel) &&
              similar.length < 10) {
            similar.add(rel);
          }
        });
      }
    }
    if (similar.length < 10) {
      for (final m in RegExp(
        r'/store/apps/details\?id=([a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z0-9_]+)+)',
      ).allMatches(html)) {
        final rel = m.group(1)!;
        if (rel != packageName && !similar.contains(rel)) {
          similar.add(rel);
          if (similar.length >= 10) break;
        }
      }
    }

    final downloads = root != null ? _strAt(root, [13, 0]) : '';
    final changelog = root != null ? _stripHtml(_strAt(root, [144, 1, 1])) : '';
    final lastUpdated = root != null ? _strAt(root, [145, 0, 0]) : '';

    return StoreListing(
      store: StoreId.googlePlay,
      packageName: packageName,
      title: title,
      developer: developer,
      iconUrl: iconUrl,
      versionName: versionName,
      minAndroidLabel: minAndroidLabel,
      minSdk: minSdk,
      priceLabel: priceLabel,
      isFree: isFree,
      rating: rating,
      ratingCount: ratingCount,
      downloadsLabel: downloads,
      lastUpdatedLabel: lastUpdated,
      description: description,
      changelog: changelog,
      category: category,
      screenshots: screenshots,
      permissions: permissions,
      similarPackages: similar,
      storeUrl: 'https://play.google.com/store/apps/details?id=$packageName',
      deepLinkUrl: 'market://details?id=$packageName',
      fetchedAtMs: now,
    );
  }

  // ---------------------------------------------------------------------------
  // Cafe Bazaar parsers (api.cafebazaar.ir)
  // ---------------------------------------------------------------------------

  static Map<String, Object?> _bazaarProperties() => const {
    'language': 2,
    'clientID': 'icedragon-web',
    'deviceID': 'icedragon-web',
    'clientVersion': 'web',
  };

  Future<List<StoreListing>> searchBazaar(
    String query, {
    String? proxyAddress,
  }) async {
    final client = _openClient(proxyAddress);
    try {
      final (status, body) = await _postJson(
        client,
        'https://api.cafebazaar.ir/rest-v1/process/SearchV2Request',
        {
          'properties': _bazaarProperties(),
          'singleRequest': {
            'searchRequest': {'query': query, 'language': 'fa'},
          },
        },
      );
      if (status != 200) throw HttpException('Bazaar HTTP $status');
      return parseBazaarSearchJson(body);
    } finally {
      client.close(force: true);
    }
  }

  Future<StoreListing?> fetchBazaarDetails(
    String packageName, {
    String? proxyAddress,
  }) async {
    final client = _openClient(proxyAddress);
    try {
      final (status, body) = await _postJson(
        client,
        'https://api.cafebazaar.ir/rest-v1/process/AppDetailsV2Request',
        {
          'properties': _bazaarProperties(),
          'singleRequest': {
            'appDetailsV2Request': {'packageName': packageName},
          },
        },
      );
      if (status != 200) return null;
      return parseBazaarDetailsJson(packageName, body);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<StoreListing>> fetchBazaarHomeRadar({
    String? proxyAddress,
  }) async {
    final client = _openClient(proxyAddress);
    try {
      final (status, body) = await _postJson(
        client,
        'https://api.cafebazaar.ir/rest-v1/process/GetPageV2Request',
        {
          'properties': _bazaarProperties(),
          'singleRequest': {
            'getPageV2Request': {'path': 'home'},
          },
        },
      );
      if (status != 200) return const [];
      return parseBazaarHomeJson(body);
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, Object?>? _tryDecodeJsonMap(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static List<StoreListing> parseBazaarSearchJson(String body) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final j = _tryDecodeJsonMap(body);
    if (j == null) return const [];
    final reply = j['singleReply'];
    if (reply is! Map<String, Object?>) return const [];
    final sr = reply['searchReply'];
    if (sr is! Map<String, Object?>) return const [];
    final rows = sr['resultRows'];
    if (rows is! List<Object?>) return const [];

    final out = <StoreListing>[];
    for (final row in rows) {
      if (row is! Map<String, Object?>) continue;
      final app = row['app'];
      if (app is! Map<String, Object?>) continue;
      final pkg = '${app['packageName'] ?? ''}';
      if (pkg.isEmpty) continue;
      final price = app['price'] is num ? (app['price']! as num).toInt() : 0;
      final minSdk = app['minimumSdkVersion'] is int
          ? app['minimumSdkVersion']! as int
          : int.tryParse('${app['minimumSdkVersion']}');
      out.add(
        StoreListing(
          store: StoreId.bazaar,
          packageName: pkg,
          title: '${app['name'] ?? pkg}',
          developer: '${app['authorName'] ?? ''}',
          iconUrl: '${app['image'] ?? ''}',
          versionCode: app['versionCode'] is int
              ? app['versionCode']! as int
              : 0,
          minSdk: minSdk != null && minSdk > 0 ? minSdk : null,
          minAndroidLabel: formatMinAndroidFromSdk(minSdk),
          priceLabel: '${app['priceString'] ?? (price == 0 ? 'رایگان' : '$price')}',
          isFree: price <= 0,
          rating: app['rate'] is num ? (app['rate']! as num).toDouble() : 0,
          downloadsLabel: '${app['installCount'] ?? ''}',
          category: '${app['category'] ?? ''}',
          description: '${app['shortDescription'] ?? ''}',
          storeUrl: 'https://cafebazaar.ir/app/$pkg',
          deepLinkUrl: 'bazaar://details?id=$pkg',
          fetchedAtMs: now,
        ),
      );
    }
    return out;
  }

  static StoreListing? parseBazaarDetailsJson(
    String packageName,
    String body,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final j = _tryDecodeJsonMap(body);
    if (j == null) return null;
    final reply = j['singleReply'];
    if (reply is! Map<String, Object?>) return null;
    final rep = reply['appDetailsV2Reply'];
    if (rep is! Map<String, Object?>) return null;

    final meta = rep['meta'] as Map<String, Object?>? ?? const {};
    final pkg = rep['package'] as Map<String, Object?>? ?? const {};
    final media = rep['media'] as Map<String, Object?>? ?? const {};
    if (meta.isEmpty && pkg.isEmpty) return null;

    final title = '${meta['name'] ?? packageName}';
    final sizeBytes = int.tryParse('${pkg['size'] ?? ''}') ?? 0;
    final verboseSize = '${pkg['verboseSize'] ?? ''}';
    final verboseLabel = '${pkg['verboseSizeLabel'] ?? ''}';
    final sizeLabel = verboseSize.isNotEmpty
        ? '$verboseSize $verboseLabel'.trim()
        : (sizeBytes > 0 ? formatStorageBytes(sizeBytes) : '');

    final minSdk = int.tryParse('${pkg['minimumSDKVersion'] ?? ''}');

    final payment = meta['payment'] as Map<String, Object?>? ?? const {};
    final price = payment['price'] is num
        ? (payment['price']! as num).toInt()
        : 0;
    final priceStr = '${payment['priceString'] ?? ''}';

    final review = meta['reviewInfo'] as Map<String, Object?>? ?? const {};
    final rating = review['averageRate'] is num
        ? (review['averageRate']! as num).toDouble()
        : 0.0;
    final ratingCount = review['reviewCount'] is int
        ? review['reviewCount']! as int
        : 0;

    final screenshots = <String>[];
    if (media['screenshots'] case final List<Object?> ss) {
      for (final s in ss) {
        if (s is Map<String, Object?>) {
          final u = '${s['fullSize'] ?? s['thumbnail'] ?? ''}';
          if (u.startsWith('http')) screenshots.add(u);
        }
      }
    }

    final permissions = <String>[];
    if (pkg['permissions'] case final List<Object?> ps) {
      for (final p in ps) {
        permissions.add('$p');
      }
    }

    final related = <String>[];
    if (rep['extraContentPageBodyInfo'] case final Map<String, Object?> ec) {
      if (ec['pageBody'] case final Map<String, Object?> pb) {
        if (pb['rows'] case final List<Object?> rows) {
          for (final r in rows) {
            if (r is Map<String, Object?> && r['simpleAppList'] is Map) {
              final sal = r['simpleAppList']! as Map<String, Object?>;
              if (sal['apps'] case final List<Object?> apps) {
                for (final a in apps) {
                  if (a is Map<String, Object?> && a['info'] is Map) {
                    final info = a['info']! as Map<String, Object?>;
                    final relPkg = '${info['packageName'] ?? ''}';
                    if (relPkg.isNotEmpty) related.add(relPkg);
                  }
                }
              }
            }
          }
        }
      }
    }

    var developer = '';
    if (meta['author'] case final Map<String, Object?> auth) {
      developer = '${auth['name'] ?? ''}';
    }

    final catVal = meta['category'];
    final category = catVal is Map<String, Object?>
        ? '${catVal['name'] ?? catVal['slug'] ?? ''}'
        : '${catVal ?? ''}';

    return StoreListing(
      store: StoreId.bazaar,
      packageName: packageName,
      title: title,
      developer: developer,
      iconUrl: '${media['iconUrl'] ?? ''}',
      versionName: normalizeDigits('${pkg['versionName'] ?? ''}'),
      versionCode: pkg['versionCode'] is int ? pkg['versionCode']! as int : 0,
      sizeLabel: sizeLabel,
      sizeBytes: sizeBytes,
      minSdk: minSdk != null && minSdk > 0 ? minSdk : null,
      minAndroidLabel: formatMinAndroidFromSdk(minSdk),
      priceLabel: price <= 0 ? 'رایگان' : priceStr,
      isFree: price <= 0,
      rating: rating,
      ratingCount: ratingCount,
      downloadsLabel: '${meta['installCount'] ?? ''}',
      lastUpdatedLabel: '${pkg['lastUpdated'] ?? ''}',
      description: _stripHtml('${meta['description'] ?? meta['shortDescription'] ?? ''}'),
      changelog: _stripHtml('${pkg['changeLog'] ?? ''}'),
      category: category,
      screenshots: screenshots,
      permissions: permissions,
      similarPackages: related,
      storeUrl: 'https://cafebazaar.ir/app/$packageName',
      deepLinkUrl: 'bazaar://details?id=$packageName',
      fetchedAtMs: now,
    );
  }

  static List<StoreListing> parseBazaarHomeJson(String body) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <StoreListing>[];
    final seen = <String>{};
    final j = _tryDecodeJsonMap(body);
    if (j == null) return out;
    final reply = j['singleReply'];
    if (reply is! Map<String, Object?>) return out;
    final pageReply = reply['getPageV2Reply'];
    if (pageReply is! Map<String, Object?>) return out;
    final page = pageReply['page'];
    if (page is! Map<String, Object?>) return out;
    final bodyInfo = page['pageBodyInfo'];
    if (bodyInfo is! Map<String, Object?>) return out;
    final pageBody = bodyInfo['pageBody'];
    if (pageBody is! Map<String, Object?>) return out;
    final rows = pageBody['rows'];
    if (rows is! List<Object?>) return out;

    for (final r in rows) {
      if (r is! Map<String, Object?>) continue;
      final sal = r['simpleAppList'];
      if (sal is! Map<String, Object?>) continue;
      final listTitle = '${sal['title'] ?? ''}';
      final apps = sal['apps'];
      if (apps is! List<Object?>) continue;
      for (final a in apps) {
        if (a is! Map<String, Object?>) continue;
        final info = a['info'];
        if (info is! Map<String, Object?>) continue;
        final pkg = '${info['packageName'] ?? ''}';
        if (pkg.isEmpty || !seen.add(pkg)) continue;
        final price = info['price'] is num ? (info['price']! as num).toInt() : 0;
        out.add(
          StoreListing(
            store: StoreId.bazaar,
            packageName: pkg,
            title: '${info['name'] ?? pkg}',
            developer: '${info['authorName'] ?? ''}',
            iconUrl: '${info['image'] ?? ''}',
            rating: info['rate'] is num ? (info['rate']! as num).toDouble() : 0,
            isFree: price <= 0,
            priceLabel: price <= 0 ? 'رایگان' : '$price',
            category: listTitle,
            storeUrl: 'https://cafebazaar.ir/app/$pkg',
            deepLinkUrl: 'bazaar://details?id=$pkg',
            fetchedAtMs: now,
          ),
        );
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Myket parsers (myket.ir)
  // ---------------------------------------------------------------------------

  Future<List<StoreListing>> searchMyket(
    String query, {
    String? proxyAddress,
  }) async {
    final client = _openClient(proxyAddress);
    try {
      final uri = Uri.https('myket.ir', '/Search/Apps', {
        'keyword': query,
        'page': '0',
      });
      final (status, html) = await _get(client, uri.toString());
      if (status != 200) throw HttpException('Myket HTTP $status');
      return parseMyketSearchHtml(html);
    } finally {
      client.close(force: true);
    }
  }

  Future<StoreListing?> fetchMyketDetails(
    String packageName, {
    String? proxyAddress,
  }) async {
    final client = _openClient(proxyAddress);
    try {
      final (status, html) = await _get(
        client,
        'https://myket.ir/app/$packageName',
      );
      if (status == 404) return null;
      if (status != 200) return null;
      return parseMyketDetailsHtml(packageName, html);
    } finally {
      client.close(force: true);
    }
  }

  Future<List<StoreListing>> fetchMyketRadar({String? proxyAddress}) async {
    final client = _openClient(proxyAddress);
    try {
      final (status, html) = await _get(client, 'https://myket.ir/apps');
      if (status != 200) return const [];
      return parseMyketSearchHtml(html);
    } finally {
      client.close(force: true);
    }
  }

  static final RegExp _pkgIdPattern = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z0-9_]+)+$',
  );

  static bool _isValidPackageId(String pkg) {
    if (pkg.isEmpty || pkg.length > 200) return false;
    final lower = pkg.toLowerCase();
    for (final ext in const [
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
      '.svg',
      '.ico',
      '.gif',
      '.css',
      '.js',
      '.html',
      '.xml',
      '.json',
    ]) {
      if (lower.endsWith(ext)) return false;
    }
    return _pkgIdPattern.hasMatch(pkg);
  }

  static List<StoreListing> parseMyketSearchHtml(String html) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <StoreListing>[];
    final seen = <String>{};

    // Match each card anchor element atomically so titles/icons never bleed
    // across neighboring cards.
    final anchorRegex = RegExp(
      r'<a\b([^>]*)href="/app/([a-zA-Z0-9_.]+)"([^>]*)>(.*?)</a>',
      dotAll: true,
      caseSensitive: false,
    );
    for (final m in anchorRegex.allMatches(html)) {
      final pkg = m.group(2) ?? '';
      if (!_isValidPackageId(pkg) || !seen.add(pkg)) continue;

      final openAttrs = '${m.group(1) ?? ''} ${m.group(3) ?? ''}';
      final inner = m.group(4) ?? '';

      var title = '';
      final namePara = RegExp(
        r'<p[^>]*class="[^"]*app-name[^"]*"[^>]*>(.*?)</p>',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(inner);
      if (namePara != null) {
        title = _stripHtml(namePara.group(1) ?? '');
      }
      if (title.isEmpty) {
        final attrTitle = RegExp(
          r'\btitle="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(openAttrs);
        if (attrTitle != null) {
          title = _decodeHtmlEntities(attrTitle.group(1) ?? '').trim();
        }
      }
      if (title.isEmpty) {
        final altMatch = RegExp(
          r'\b(?:alt|title)="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(inner);
        if (altMatch != null) {
          title = _decodeHtmlEntities(altMatch.group(1) ?? '')
              .replaceFirst(RegExp(r'^دانلود\s+'), '')
              .trim();
        }
      }
      if (title.isEmpty) title = pkg;

      final imgMatch = RegExp(
        r'(?:data-iesrc|src)="(https://myket\.ir/[^"]+)"',
        caseSensitive: false,
      ).firstMatch(inner);
      final icon = imgMatch?.group(1) ?? '';

      out.add(
        StoreListing(
          store: StoreId.myket,
          packageName: pkg,
          title: title,
          iconUrl: icon,
          storeUrl: 'https://myket.ir/app/$pkg',
          deepLinkUrl: 'myket://details?id=$pkg',
          fetchedAtMs: now,
        ),
      );
    }

    // Fallback for bare unclosed <a href="/app/pkg" title="..."> tags only:
    // inspect strictly the opening tag attributes (never scan past '>').
    final bareTagRegex = RegExp(
      r'<a\b([^>]*)href="/app/([a-zA-Z0-9_.]+)"([^>]*)>',
      caseSensitive: false,
    );
    for (final m in bareTagRegex.allMatches(html)) {
      final pkg = m.group(2) ?? '';
      if (!_isValidPackageId(pkg) || !seen.add(pkg)) continue;
      final attrs = '${m.group(1) ?? ''} ${m.group(3) ?? ''}';
      final attrTitle = RegExp(r'\btitle="([^"]+)"').firstMatch(attrs);
      final title = _decodeHtmlEntities(attrTitle?.group(1) ?? pkg).trim();
      out.add(
        StoreListing(
          store: StoreId.myket,
          packageName: pkg,
          title: title.isNotEmpty ? title : pkg,
          storeUrl: 'https://myket.ir/app/$pkg',
          deepLinkUrl: 'myket://details?id=$pkg',
          fetchedAtMs: now,
        ),
      );
    }
    return out;
  }

  static StoreListing? parseMyketDetailsHtml(String packageName, String html) {
    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, Object?>? ld;
    for (final item in _extractJsonLdList(html)) {
      if (item['@type'] == 'SoftwareApplication') {
        ld = item;
        break;
      }
    }
    if (ld == null && !html.contains(packageName)) return null;

    final title = _decodeHtmlEntities('${ld?['name'] ?? packageName}');
    final desc = _stripHtml(_decodeHtmlEntities('${ld?['description'] ?? ''}'));
    final iconUrl = '${ld?['image'] ?? ''}';
    var category = '${ld?['applicationCategory'] ?? ''}';

    var rating = 0.0;
    var ratingCount = 0;
    if (ld?['aggregateRating'] case final Map<String, Object?> ar) {
      rating = double.tryParse(normalizeDigits('${ar['ratingValue']}')) ?? 0;
      ratingCount =
          int.tryParse(
            normalizeDigits('${ar['ratingCount']}').replaceAll(',', ''),
          ) ??
          0;
    }

    var isFree = true;
    var priceLabel = '';
    if (ld?['offers'] case final Map<String, Object?> offer) {
      final p = double.tryParse(normalizeDigits('${offer['price'] ?? '0'}')) ?? 0;
      isFree = p <= 0;
      priceLabel = isFree ? 'رایگان' : '${offer['price']}';
    } else if (ld?['offers'] case final List<Object?> offers
        when offers.isNotEmpty) {
      if (offers.first case final Map<String, Object?> offer) {
        final p =
            double.tryParse(normalizeDigits('${offer['price'] ?? '0'}')) ?? 0;
        isFree = p <= 0;
        priceLabel = isFree ? 'رایگان' : '${offer['price']}';
      }
    } else if (html.contains('رایگان')) {
      priceLabel = 'رایگان';
    }

    final specs = <String, String>{};
    for (final m in RegExp(
      r'<tr>\s*<td>(.*?)</td>\s*<td>(.*?)</td>\s*</tr>',
      dotAll: true,
    ).allMatches(html)) {
      final k = _stripHtml(_decodeHtmlEntities(m.group(1) ?? '')).trim();
      final v = _stripHtml(_decodeHtmlEntities(m.group(2) ?? '')).trim();
      if (k.isNotEmpty && v.isNotEmpty) specs[k] = v;
    }

    final version = normalizeDigits(
      specs['نسخه'] ?? '${ld?['softwareVersion'] ?? ''}',
    );
    final sizeLabel = normalizeDigits(specs['حجم'] ?? '');
    final sizeBytes = _parseSizeLabelBytes(sizeLabel);
    final lastUpdated = normalizeDigits(specs['آخرین بروزرسانی'] ?? '');
    final downloads = normalizeDigits(specs['تعداد دانلود'] ?? '');
    final developer = specs['سازنده'] ?? '';
    if (specs['دسته‌بندی']?.isNotEmpty == true) {
      category = specs['دسته‌بندی']!;
    }
    final minAndroid = normalizeDigits(
      specs['اندروید مورد نیاز'] ?? specs['حداقل اندروید'] ?? '',
    );
    final minSdk = parseMinSdkFromLabel(minAndroid);

    final screenshots = <String>[];
    for (final m in RegExp(
      r'https://myket\.ir/asset-files/screenshots/[^"\s<>]+',
    ).allMatches(html)) {
      final u = m.group(0)!;
      if (!screenshots.contains(u)) screenshots.add(u);
    }

    final similar = <String>[];
    for (final m in RegExp(r'/app/([a-zA-Z0-9_.]+)').allMatches(html)) {
      final pkg = m.group(1)!;
      if (pkg != packageName && _isValidPackageId(pkg) && !similar.contains(pkg)) {
        similar.add(pkg);
        if (similar.length >= 10) break;
      }
    }

    return StoreListing(
      store: StoreId.myket,
      packageName: packageName,
      title: title,
      developer: developer,
      iconUrl: iconUrl,
      versionName: version,
      sizeLabel: sizeLabel,
      sizeBytes: sizeBytes,
      minAndroidLabel: minAndroid,
      minSdk: minSdk,
      priceLabel: priceLabel,
      isFree: isFree,
      rating: rating,
      ratingCount: ratingCount,
      downloadsLabel: downloads,
      lastUpdatedLabel: lastUpdated,
      description: desc,
      category: category,
      screenshots: screenshots,
      similarPackages: similar,
      storeUrl: 'https://myket.ir/app/$packageName',
      deepLinkUrl: 'myket://details?id=$packageName',
      fetchedAtMs: now,
    );
  }

  // ---------------------------------------------------------------------------
  // Extraction helpers
  // ---------------------------------------------------------------------------

  static int _parseSizeLabelBytes(String raw) {
    final clean = normalizeDigits(raw).toLowerCase();
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(clean);
    if (m == null) return 0;
    final val = double.tryParse(m.group(1)!) ?? 0;
    if (clean.contains('گیگ') || clean.contains('gb')) {
      return (val * (1 << 30)).round();
    }
    if (clean.contains('مگ') || clean.contains('mb')) {
      return (val * (1 << 20)).round();
    }
    if (clean.contains('کیل') || clean.contains('kb')) {
      return (val * (1 << 10)).round();
    }
    return 0;
  }

  static List<Map<String, Object?>> _extractJsonLdList(String html) {
    final out = <Map<String, Object?>>[];
    final reg = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      dotAll: true,
    );
    for (final m in reg.allMatches(html)) {
      try {
        final decoded = jsonDecode(m.group(1) ?? '');
        if (decoded is Map<String, Object?>) {
          out.add(decoded);
        } else if (decoded is List<Object?>) {
          for (final item in decoded) {
            if (item is Map<String, Object?>) out.add(item);
          }
        }
      } catch (_) {}
    }
    return out;
  }

  static Object? _extractAfCallbackJson(String html, String key) {
    final needle = "AF_initDataCallback({key: '$key'";
    final idx = html.indexOf(needle);
    if (idx < 0) return null;
    final dataIdx = html.indexOf('data:', idx);
    if (dataIdx < 0) return null;
    final sideIdx = html.indexOf(', sideChannel:', dataIdx);
    if (sideIdx < 0) return null;
    final raw = html.substring(dataIdx + 5, sideIdx).trim();
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static void _walkGooglePlaySearchNodes(
    Object? node,
    void Function(List<Object?>) onItem,
  ) {
    if (node is! List<Object?>) return;
    if (node.isNotEmpty && _findPackageIdNode(node) != null && node.length >= 4) {
      onItem(node);
      return;
    }
    for (final child in node) {
      _walkGooglePlaySearchNodes(child, onItem);
    }
  }

  static String? _findPackageIdNode(List<Object?> list) {
    if (list.isEmpty) return null;
    final first = list[0];
    if (first is List<Object?> &&
        first.length == 2 &&
        first[0] is String &&
        first[1] == 7) {
      final s = first[0]! as String;
      if (s.contains('.')) return s;
    }
    return null;
  }

  static String? _firstStringAt(List<Object?> list, List<int> path) {
    Object? cur = list;
    for (final idx in path) {
      if (cur is List<Object?> && idx < cur.length) {
        cur = cur[idx];
      } else {
        return null;
      }
    }
    return cur is String && cur.trim().isNotEmpty ? cur.trim() : null;
  }

  static String? _firstShortTextInList(
    Object? node, {
    required String exclude,
  }) {
    if (node is String) {
      final t = node.trim();
      if (t.isNotEmpty &&
          t != exclude &&
          !t.startsWith('http') &&
          !t.startsWith('/') &&
          t.length <= 60) {
        return t;
      }
      return null;
    }
    if (node is List<Object?>) {
      for (final child in node) {
        final found = _firstShortTextInList(child, exclude: exclude);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String? _firstPlayImageUrl(Object? node) {
    if (node is String) {
      if (node.startsWith('https://play-lh.googleusercontent.com/')) {
        return node;
      }
      return null;
    }
    if (node is List<Object?>) {
      for (final child in node) {
        final found = _firstPlayImageUrl(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  static double _firstRatingInList(Object? node) {
    if (node is num && node >= 1.0 && node <= 5.0 && node is double) {
      return node;
    }
    if (node is List<Object?>) {
      for (final child in node) {
        final found = _firstRatingInList(child);
        if (found > 0) return found;
      }
    }
    return 0;
  }

  static String? _firstDeveloperInList(List<Object?> list) {
    if (list.length > 14 && list[14] is String) {
      return list[14]! as String;
    }
    return null;
  }

  static String _strAt(Object? node, List<int> path) {
    Object? cur = node;
    for (final idx in path) {
      if (cur is List<Object?> && idx >= 0 && idx < cur.length) {
        cur = cur[idx];
      } else {
        return '';
      }
    }
    return cur is String ? cur : '';
  }

  static int? _intAt(Object? node, List<int> path) {
    Object? cur = node;
    for (final idx in path) {
      if (cur is List<Object?> && idx >= 0 && idx < cur.length) {
        cur = cur[idx];
      } else {
        return null;
      }
    }
    return cur is int ? cur : null;
  }

  static String _stripHtml(String raw) => _decodeHtmlEntities(
    raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), ''),
  ).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

  static String _decodeHtmlEntities(String raw) {
    var s = raw
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&zwnj;', '\u200c');
    s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    return s;
  }
}
