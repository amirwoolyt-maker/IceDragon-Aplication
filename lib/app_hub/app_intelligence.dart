import 'dart:convert';
import 'dart:io';

import 'hub_models.dart';
import 'store_aggregator.dart';

/// Output from App Intelligence AI recommender (#16).
class AiRecommendationResult {
  const AiRecommendationResult({
    required this.summary,
    required this.apps,
    required this.usedGemini,
  });

  final String summary;
  final List<UnifiedAppResult> apps;
  final bool usedGemini;
}

class _RoleRule {
  const _RoleRule(this.key, this.en, this.fa, this.keywords);
  final String key;
  final String en;
  final String fa;
  final List<String> keywords;
}

/// On-device smart diagnostics, duplicate/similar function detection,
/// permission auditing, free-alternative lookup, and hybrid App Intelligence
/// (local engine + optional Gemini API).
class AppIntelligence {
  AppIntelligence({
    required this.stores,
    HttpClient Function()? clientFactory,
    this.geminiEndpoint,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final StoreAggregator stores;
  final HttpClient Function() _clientFactory;
  final Uri? geminiEndpoint;

  static const _duplicateRoles = <_RoleRule>[
    _RoleRule('browser', 'Web Browsers', 'مرورگرهای وب', [
      'chrome',
      'firefox',
      'opera',
      'brave',
      'edge',
      'kiwi',
      'browser',
      'duckduckgo',
      'مرورگر',
    ]),
    _RoleRule('photo_editor', 'Photo Editors', 'ویرایشگرهای عکس', [
      'picsart',
      'snapseed',
      'lightroom',
      'psmobile',
      'photoeditor',
      'polish',
      'photolab',
      'remini',
      'canva',
      'collage',
      'ویرایش عکس',
    ]),
    _RoleRule('video_editor', 'Video Editors', 'ویرایشگرهای ویدئو', [
      'capcut',
      'inshot',
      'kinemaster',
      'vita',
      'vn ',
      'youcut',
      'powerdirector',
      'filmora',
      'ادیت فیلم',
      'تدوین',
    ]),
    _RoleRule('vpn', 'VPN & Proxy Tools', 'ابزارهای VPN و پروکسی', [
      'vpn',
      'v2ray',
      'nekobox',
      'hiddify',
      'outline',
      'wireguard',
      'openvpn',
      'psiphon',
      'warp',
      'فیلترشکن',
    ]),
    _RoleRule('pdf_office', 'PDF & Document Readers', 'ابزارهای PDF و اسناد', [
      'pdf',
      'acrobat',
      'wps',
      'camscanner',
      'scanner',
      'xodo',
      'foxit',
      'office',
    ]),
    _RoleRule('media_player', 'Video & Music Players', 'پخش‌کننده‌های رسانه', [
      'vlc',
      'mxtech',
      'kmplayer',
      'player',
      'jetaudio',
      'poweramp',
      'musicolet',
    ]),
    _RoleRule('notes', 'Notes & To-Do Apps', 'یادداشت و برنامه‌ریزی', [
      'notion',
      'obsidian',
      'keep',
      'evernote',
      'onenote',
      'simplenote',
      'todo',
      'ticktick',
      'یادداشت',
    ]),
    _RoleRule('ai_chat', 'AI Assistants', 'دستیارهای هوش مصنوعی', [
      'openai',
      'chatgpt',
      'gemini',
      'claude',
      'copilot',
      'perplexity',
      'deepseek',
      'poe',
    ]),
    _RoleRule('file_manager', 'File Managers', 'مدیریت فایل', [
      'files',
      'solidexplorer',
      'cxfile',
      'mixplorer',
      'zarchiver',
      'rar',
      'فایل',
    ]),
    _RoleRule('keyboard', 'Keyboards', 'صفحه‌کلیدها', [
      'gboard',
      'swiftkey',
      'farsikey',
      'keyboard',
      'کیبورد',
    ]),
  ];

  /// Inspects installed apps and device health to produce [AssistantReport] (#12).
  AssistantReport analyzePhone({
    required DeviceEnvironment device,
    required List<InstalledAppDetail> apps,
    required Map<String, StoreListing> updateCache,
    required Map<String, Set<String>> appCategories,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final userApps = [for (final a in apps) if (!a.system) a];

    // 1. Large apps (>= 40 MB or top 10 largest)
    final sortedBySize = [...userApps]
      ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    final largeApps = sortedBySize
        .where((a) => a.totalBytes >= 40 * 1024 * 1024)
        .take(12)
        .toList();
    if (largeApps.isEmpty) {
      largeApps.addAll(sortedBySize.where((a) => a.totalBytes > 0).take(6));
    }

    // 2. Outdated store updates + stale apps (>180 days since update)
    final outdatedApps = <UpdateCandidate>[];
    for (final a in userApps) {
      final cached = updateCache[a.package];
      if (cached != null &&
          isRemoteVersionNewer(
            localVersion: a.versionName,
            localCode: a.versionCode,
            remoteVersion: cached.versionName,
            remoteCode: cached.versionCode,
          )) {
        outdatedApps.add(UpdateCandidate(app: a, listing: cached));
      }
    }
    final staleApps =
        [
          for (final a in userApps)
            if (a.launcher && a.ageDays(current) >= 180) a,
        ]..sort(
          (a, b) => a.lastUpdateTime.compareTo(b.lastUpdateTime),
        );

    // 3. Duplicate / similar function finder
    final roleBuckets = <String, List<InstalledAppDetail>>{};
    for (final a in userApps) {
      if (!a.launcher) continue;
      final blob = '${a.package} ${a.label}'.toLowerCase();
      for (final rule in _duplicateRoles) {
        if (rule.keywords.any(blob.contains)) {
          roleBuckets.putIfAbsent(rule.key, () => []).add(a);
        }
      }
    }
    final duplicateGroups = <DuplicateGroup>[];
    for (final rule in _duplicateRoles) {
      final bucket = roleBuckets[rule.key];
      if (bucket != null && bucket.length >= 2) {
        duplicateGroups.add(
          DuplicateGroup(
            roleKey: rule.key,
            titleEn: rule.en,
            titleFa: rule.fa,
            apps: bucket,
          ),
        );
      }
    }

    // 4. Unnecessary / risky permission auditor
    final permissionAudits = <PermissionAuditItem>[];
    for (final a in userApps) {
      if (!a.launcher) continue;
      final cats = appCategories[a.package] ??
          CategoryClassifier.inferCategories(app: a);
      final flagged = <String>[];
      final grantedFlagged = <String>[];
      var score = 0;

      for (final perm in a.sensitivePermissions) {
        final kind = sensitivePermissionPrefixes[perm] ?? '';
        final unusual = _isPermissionUnusualForCategories(kind, cats);
        if (unusual || perm.endsWith('BACKGROUND_LOCATION') || perm.endsWith('READ_SMS')) {
          flagged.add(perm);
          final isGranted = a.grantedPermissions.contains(perm);
          if (isGranted) grantedFlagged.add(perm);
          score += unusual ? (isGranted ? 3 : 2) : 1;
        }
      }
      if (flagged.isNotEmpty && score >= 3) {
        permissionAudits.add(
          PermissionAuditItem(
            app: a,
            flaggedPermissions: flagged,
            grantedFlagged: grantedFlagged,
            riskScore: score,
          ),
        );
      }
    }
    permissionAudits.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    // 5. Reclaimable space estimate (caches + smallest duplicate apps + stale)
    var reclaim = 0;
    for (final a in userApps) {
      reclaim += a.cacheBytes;
    }
    for (final g in duplicateGroups) {
      final sizes = [for (final a in g.apps) a.totalBytes]..sort();
      for (final s in sizes.take(sizes.length - 1)) {
        reclaim += s;
      }
    }

    return AssistantReport(
      device: device,
      largeApps: largeApps,
      outdatedApps: outdatedApps,
      staleApps: staleApps.take(15).toList(),
      duplicateGroups: duplicateGroups,
      permissionAudits: permissionAudits.take(15).toList(),
      potentialReclaimBytes: reclaim,
      generatedAt: current,
    );
  }

  static bool _isPermissionUnusualForCategories(
    String kind,
    Set<String> cats,
  ) {
    final isSocial = cats.contains('social');
    final isMedia = cats.contains('media');
    final isTravel = cats.contains('travel');
    final isFinance = cats.contains('finance');
    final isTools = cats.contains('tools');
    return switch (kind) {
      'sms' || 'calls' => !isSocial && !isFinance,
      'contacts' => !isSocial && !isFinance && !isTravel,
      'location' => !isTravel && !isSocial && !isFinance && !isTools,
      'camera' => !isMedia && !isSocial && !isFinance && !isTools,
      'microphone' => !isMedia && !isSocial && !cats.contains('education') && !cats.contains('ai'),
      'overlay' || 'install' => !isTools,
      _ => false,
    };
  }

  /// Known curated free/open alternatives when a user inspects a paid or
  /// heavy app (#16 Smart Alternative).
  static const _curatedFreeAlternatives = <String, List<String>>{
    'photo': [
      'com.niksoftware.snapseed',
      'photo.editor.photoeditor.photoeditorpro',
      'com.canva.editor',
    ],
    'video': ['com.lemon.lvoverseas', 'com.camerasideas.instashot', 'org.videolan.vlc'],
    'pdf': ['com.adobe.reader', 'com.xodo.pdf.reader'],
    'notes': ['md.obsidian', 'notion.id', 'com.automattic.simplenote'],
    'office': ['org.libreoffice.android', 'com.google.android.apps.docs'],
    'music': ['org.videolan.vlc', 'in.krosbits.musicolet'],
    'ai': ['com.openai.chatgpt', 'com.google.android.apps.bard', 'ai.perplexity.app.android'],
    'file': ['com.google.android.apps.nbu.files', 'pl.solidexplorer2'],
    'game': ['com.chess', 'org.lichess.mobileapp'],
  };

  static const _faAlternativeTopics = <String, String>{
    'عکاسی': 'photo',
    'عکس': 'photo',
    'ویرایش تصویر': 'photo',
    'ویدیو': 'video',
    'فیلم': 'video',
    'پخش': 'video',
    'pdf': 'pdf',
    'سند': 'pdf',
    'اداری': 'office',
    'آفیس': 'office',
    'یادداشت': 'notes',
    'موزیک': 'music',
    'موسیقی': 'music',
    'صدا': 'music',
    'هوش مصنوعی': 'ai',
    'فایل': 'file',
    'بازی': 'game',
  };

  /// Suggests free alternatives for [source] using live store lookups +
  /// curated free/open-source mappings (#16 Smart Alternative).
  Future<List<UnifiedAppResult>> findFreeAlternatives(
    UnifiedAppResult source, {
    String hl = 'en',
    String? proxyAddress,
  }) async {
    final blob =
        '${source.displayTitle} ${source.category} ${source.description}'
            .toLowerCase();
    final seedPackages = <String>[];
    for (final e in _curatedFreeAlternatives.entries) {
      if (blob.contains(e.key)) {
        seedPackages.addAll(e.value);
      }
    }
    for (final e in _faAlternativeTopics.entries) {
      if (blob.contains(e.key)) {
        seedPackages.addAll(_curatedFreeAlternatives[e.value] ?? const []);
      }
    }

    final isFaQuery =
        hl == 'fa' ||
        RegExp(r'[\u0600-\u06FF]').hasMatch(source.category) ||
        RegExp(r'[\u0600-\u06FF]').hasMatch(source.displayTitle);
    final rawTopic = source.category.isNotEmpty
        ? source.category
        : source.displayTitle;
    final queryTopic = isFaQuery ? 'برنامه رایگان $rawTopic' : 'free $rawTopic';

    final searchRes = await stores.searchAcrossStores(
      queryTopic,
      hl: hl,
      proxyAddress: proxyAddress,
      limitPerStore: 8,
      enrichTop: 4,
    );

    final out = <UnifiedAppResult>[];
    final seen = <String>{source.packageName};

    // Enrich up to 3 curated seeds in parallel
    if (seedPackages.isNotEmpty) {
      final fetched = await Future.wait([
        for (final pkg in seedPackages.take(3))
          if (pkg != source.packageName)
            stores.fetchUnifiedApp(pkg, hl: hl, proxyAddress: proxyAddress)
                .catchError((_) => UnifiedAppResult(packageName: pkg)),
      ]);
      for (final item in fetched) {
        if (item.listings.isNotEmpty &&
            item.isFreeAnywhere &&
            seen.add(item.packageName)) {
          out.add(item);
        }
      }
    }

    for (final r in searchRes.results) {
      if (r.isFreeAnywhere && seen.add(r.packageName)) {
        out.add(r);
      }
    }
    return out.take(8).toList();
  }

  /// Hybrid App Intelligence (#16): uses optional Gemini API if [geminiApiKey]
  /// is supplied, else translates natural Persian/English needs into optimized
  /// multi-store queries, compatibility checks, and lightweight rankings.
  Future<AiRecommendationResult> recommendForNeed(
    String userNeed, {
    required DeviceEnvironment device,
    required bool fa,
    String geminiApiKey = '',
    String? proxyAddress,
  }) async {
    final trimmed = userNeed.trim();
    if (trimmed.isEmpty) {
      return const AiRecommendationResult(
        summary: '',
        apps: [],
        usedGemini: false,
      );
    }

    final preferFree = _containsAny(trimmed.toLowerCase(), const [
      'free',
      'رایگان',
      'مجانی',
      'بدون پول',
    ]);
    final preferLight = _containsAny(trimmed.toLowerCase(), const [
      'light',
      'small',
      'fast',
      'سبک',
      'کم حجم',
      'کم‌حجم',
    ]);

    String searchQuery = _translateIntentToQuery(trimmed);
    String aiSummary = '';
    var usedGemini = false;
    var suggestedPackages = <String>[];

    if (geminiApiKey.trim().isNotEmpty) {
      final gemini = await _askGemini(
        userNeed: trimmed,
        device: device,
        fa: fa,
        apiKey: geminiApiKey.trim(),
        proxyAddress: proxyAddress,
      );
      if (gemini != null) {
        usedGemini = true;
        if (gemini.summary.isNotEmpty) aiSummary = gemini.summary;
        if (gemini.searchQuery.isNotEmpty) searchQuery = gemini.searchQuery;
        suggestedPackages = gemini.packages;
      }
    }

    final res = await stores.searchAcrossStores(
      searchQuery,
      hl: fa ? 'fa' : 'en',
      proxyAddress: proxyAddress,
      limitPerStore: 10,
      enrichTop: 6,
    );

    final byPkg = <String, UnifiedAppResult>{};
    for (final r in res.results) {
      byPkg[r.packageName] = r;
    }

    if (suggestedPackages.isNotEmpty) {
      final extras = await Future.wait([
        for (final pkg in suggestedPackages.take(4))
          if (!byPkg.containsKey(pkg))
            stores
                .fetchUnifiedApp(
                  pkg,
                  hl: fa ? 'fa' : 'en',
                  proxyAddress: proxyAddress,
                )
                .catchError((_) => UnifiedAppResult(packageName: pkg)),
      ]);
      for (final e in extras) {
        if (e.listings.isNotEmpty) byPkg[e.packageName] = e;
      }
    }

    var candidates = byPkg.values.where((app) {
      if (preferFree && !app.isFreeAnywhere) return false;
      return app.isCompatibleWith(device);
    }).toList();

    if (candidates.isEmpty) candidates = byPkg.values.toList();

    candidates.sort((a, b) {
      if (preferLight) {
        final sa = a.smallestSizeBytes;
        final sb = b.smallestSizeBytes;
        if (sa > 0 && sb > 0) return sa.compareTo(sb);
      }
      final sc = b.listings.length.compareTo(a.listings.length);
      if (sc != 0) return sc;
      return b.bestRating.compareTo(a.bestRating);
    });

    if (aiSummary.isEmpty) {
      final topNames = [
        for (final c in candidates.take(3)) c.displayTitle,
      ].join(' · ');
      aiSummary = fa
          ? 'بر اساس نیاز شما («$trimmed») و سازگاری با اندروید ${device.androidRelease}، جستجو در گوگل‌پلی، بازار و مایکت انجام شد${preferFree ? ' (فیلتر رایگان فعال)' : ''}${preferLight ? ' (اولویت کم‌حجم)' : ''}.${topNames.isNotEmpty ? '\nبرترین گزینه‌ها: $topNames' : ''}'
          : 'Analyzed "$trimmed" for Android ${device.androidRelease} across Google Play, Cafe Bazaar & Myket${preferFree ? ' (Free filter)' : ''}${preferLight ? ' (Lightweight priority)' : ''}.${topNames.isNotEmpty ? '\nTop matches: $topNames' : ''}';
    }

    return AiRecommendationResult(
      summary: aiSummary,
      apps: candidates.take(10).toList(),
      usedGemini: usedGemini,
    );
  }

  static String _translateIntentToQuery(String raw) {
    final lower = raw.toLowerCase();
    final mappings = <String, String>{
      'ویرایش عکس': 'photo editor',
      'ادیت عکس': 'photo editor',
      'ادیت ویدیو': 'video editor',
      'ادیت ویدئو': 'video editor',
      'ویرایش فیلم': 'video editor',
      'هوش مصنوعی': 'ai assistant chatgpt',
      'ضبط صفحه': 'screen recorder',
      'پی دی اف': 'pdf reader',
      'اسکنر': 'document scanner',
      'آفلاین': 'offline',
      'کم حجم': 'lite',
      'آموزش زبان': 'language learning duolingo',
      'کیبورد': 'keyboard persian',
      'مسیریاب': 'navigation map',
      'فیلترشکن': 'vpn',
    };
    for (final e in mappings.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return raw;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }

  Future<_GeminiAdvice?> _askGemini({
    required String userNeed,
    required DeviceEnvironment device,
    required bool fa,
    required String apiKey,
    String? proxyAddress,
  }) async {
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 12);
    if (proxyAddress != null && proxyAddress.trim().isNotEmpty) {
      final p = proxyAddress.trim();
      client.findProxy = (_) => 'PROXY $p; DIRECT';
    }
    try {
      final uri =
          geminiEndpoint ??
          Uri.https(
            'generativelanguage.googleapis.com',
            '/v1beta/models/gemini-2.5-flash:generateContent',
          );
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 15));
      req.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('x-goog-api-key', apiKey);
      final langLabel = fa ? 'Persian (Farsi)' : 'English';
      final prompt =
          'User needs an Android app: "$userNeed". Device: Android ${device.androidRelease} (API ${device.sdkInt}). '
          'Respond ONLY in valid JSON with keys: "summary" (short helpful explanation in $langLabel), '
          '"search_query" (short English Google Play search query), '
          '"packages" (array of up to 4 real Android package IDs like "com.niksoftware.snapseed").';
      req.add(
        utf8.encode(
          jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.2,
            },
          }),
        ),
      );
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) return null;
      final outer = jsonDecode(body);
      if (outer is! Map<String, Object?>) return null;
      final candidates = outer['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final first = candidates.first;
      if (first is! Map<String, Object?>) return null;
      final content = first['content'];
      if (content is! Map<String, Object?>) return null;
      final parts = content['parts'];
      if (parts is! List || parts.isEmpty) return null;
      final text = (parts.first as Map<String, Object?>?)?['text'] as String?;
      if (text == null || text.isEmpty) return null;
      final parsed = jsonDecode(text);
      if (parsed is! Map<String, Object?>) return null;
      return _GeminiAdvice(
        summary: '${parsed['summary'] ?? ''}',
        searchQuery: '${parsed['search_query'] ?? ''}',
        packages: [
          for (final p in (parsed['packages'] as List<Object?>? ?? const []))
            '$p',
        ],
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class _GeminiAdvice {
  const _GeminiAdvice({
    required this.summary,
    required this.searchQuery,
    required this.packages,
  });

  final String summary;
  final String searchQuery;
  final List<String> packages;
}
