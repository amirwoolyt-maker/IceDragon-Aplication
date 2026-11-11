import 'dart:convert';
import 'dart:math' as math;

/// Supported app distribution stores & metadata sources.
enum StoreId {
  googlePlay('googlePlay', 'Google Play', 'گوگل‌پلی'),
  bazaar('bazaar', 'Cafe Bazaar', 'کافه‌بازار'),
  myket('myket', 'Myket', 'مایکت'),
  fdroid('fdroid', 'F-Droid', 'اف‌دروید');

  const StoreId(this.key, this.nameEn, this.nameFa);

  final String key;
  final String nameEn;
  final String nameFa;

  String label({required bool fa}) => fa ? nameFa : nameEn;

  static StoreId? fromKey(String? key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// Normalizes Persian (`۰-۹`) and Arabic (`٠-٩`) digits to ASCII `0-9`.
String normalizeDigits(String input) {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final fi = fa.indexOf(ch);
    if (fi >= 0) {
      buf.write(fi);
      continue;
    }
    final ai = ar.indexOf(ch);
    if (ai >= 0) {
      buf.write(ai);
      continue;
    }
    buf.write(ch);
  }
  return buf.toString();
}

/// Formats byte counts cleanly for storage and RAM UI.
String formatStorageBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes >= 1 << 30) {
    return '${(bytes / (1 << 30)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1 << 20) {
    return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1 << 10) {
    return '${(bytes / (1 << 10)).toStringAsFixed(0)} KB';
  }
  return '$bytes B';
}

/// Maps Android SDK API level to human-readable Android OS version.
String sdkToAndroidVersion(int sdk) => switch (sdk) {
  <= 0 => '',
  14 || 15 => '4.0',
  16 => '4.1',
  17 => '4.2',
  18 => '4.3',
  19 || 20 => '4.4',
  21 => '5.0',
  22 => '5.1',
  23 => '6.0',
  24 => '7.0',
  25 => '7.1',
  26 => '8.0',
  27 => '8.1',
  28 => '9',
  29 => '10',
  30 => '11',
  31 => '12',
  32 => '12L',
  33 => '13',
  34 => '14',
  35 => '15',
  36 => '16',
  _ => 'API $sdk',
};

/// Formats an Android minimum SDK integer as `"Android X+"` or `"API X"`.
String formatMinAndroidFromSdk(int? sdk) {
  if (sdk == null || sdk <= 0) return '';
  final ver = sdkToAndroidVersion(sdk);
  if (ver.isEmpty) return '';
  return ver.startsWith('API ') ? ver : 'Android $ver+';
}

/// Parses a minimum Android string like "Android 7.0+", "7.0 and up", "24"
/// into an approximate Android SDK level, or null if unknown.
int? parseMinSdkFromLabel(String raw) {
  final text = normalizeDigits(raw).trim();
  if (text.isEmpty) return null;
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
  if (m == null) return null;
  final val = m.group(1)!;
  if (!val.contains('.')) {
    final n = int.tryParse(val);
    if (n != null && n >= 21) return n;
  }
  final major = double.tryParse(val);
  if (major == null) return null;
  if (major >= 16) return 36;
  if (major >= 15) return 35;
  if (major >= 14) return 34;
  if (major >= 13) return 33;
  if (major >= 12) return 31;
  if (major >= 11) return 30;
  if (major >= 10) return 29;
  if (major >= 9) return 28;
  if (major >= 8.1) return 27;
  if (major >= 8.0) return 26;
  if (major >= 7.1) return 25;
  if (major >= 7.0) return 24;
  if (major >= 6.0) return 23;
  if (major >= 5.1) return 22;
  if (major >= 5.0) return 21;
  return 19;
}

/// Compares whether store build ([remoteVersion], [remoteCode]) is newer than
/// installed ([localVersion], [localCode]).
bool isRemoteVersionNewer({
  required String localVersion,
  required int localCode,
  required String remoteVersion,
  required int remoteCode,
}) {
  final remoteParts = _versionParts(remoteVersion);
  final localParts = _versionParts(localVersion);

  if (remoteParts.isNotEmpty && localParts.isNotEmpty) {
    // Compare numeric semantic version first so ABI-split versionCodes across
    // different stores never produce false positives when versions match or regress.
    return compareSemanticVersions(remoteVersion, localVersion) > 0;
  }

  // Fallback to versionCode only when store omits a human version string
  // (avoiding "Varies with device" labels and synthetic ABI prefix codes).
  if (remoteVersion.trim().isEmpty && localCode > 0 && remoteCode > localCode) {
    if (localCode < 100 || remoteCode < localCode * 4) {
      return true;
    }
  }
  return false;
}

/// Compares dotted version strings (e.g. "2.26.44.75" vs "2.25.1").
int compareSemanticVersions(String a, String b) {
  final pa = _versionParts(a);
  final pb = _versionParts(b);
  if (pa.isEmpty || pb.isEmpty) return 0;
  final len = math.max(pa.length, pb.length);
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

List<int> _versionParts(String raw) {
  final clean = normalizeDigits(raw)
      .replaceAll(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[-+\s]'))
      .first;
  if (clean.isEmpty) return const [];
  final out = <int>[];
  for (final seg in clean.split('.')) {
    final m = RegExp(r'\d+').firstMatch(seg);
    if (m != null) {
      out.add(int.tryParse(m.group(0)!) ?? 0);
    }
  }
  return out;
}

/// Device hardware and OS capabilities read from Android.
class DeviceEnvironment {
  const DeviceEnvironment({
    this.sdkInt = 34,
    this.androidRelease = '14',
    this.manufacturer = '',
    this.model = 'Android Device',
    this.abi = 'arm64-v8a',
    this.totalRamBytes = 0,
    this.availRamBytes = 0,
    this.totalStorageBytes = 0,
    this.freeStorageBytes = 0,
    this.hasUsageAccess = false,
  });

  final int sdkInt;
  final String androidRelease;
  final String manufacturer;
  final String model;
  final String abi;
  final int totalRamBytes;
  final int availRamBytes;
  final int totalStorageBytes;
  final int freeStorageBytes;
  final bool hasUsageAccess;

  factory DeviceEnvironment.fromPlatformMap(Map<Object?, Object?> m) {
    int asInt(String key, [int fallback = 0]) {
      final v = m[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    String asStr(String key, [String fallback = '']) {
      final v = m[key];
      return v is String ? v : fallback;
    }

    return DeviceEnvironment(
      sdkInt: asInt('sdkInt', 34),
      androidRelease: asStr('release', '14'),
      manufacturer: asStr('manufacturer'),
      model: asStr('model', 'Android'),
      abi: asStr('abi', 'arm64-v8a'),
      totalRamBytes: asInt('totalRamBytes'),
      availRamBytes: asInt('availRamBytes'),
      totalStorageBytes: asInt('totalStorageBytes'),
      freeStorageBytes: asInt('freeStorageBytes'),
      hasUsageAccess: m['hasUsageAccess'] == true,
    );
  }
}

/// Android sensitive permission taxonomy for privacy & assistant auditing.
const sensitivePermissionPrefixes = <String, String>{
  'android.permission.ACCESS_FINE_LOCATION': 'location',
  'android.permission.ACCESS_COARSE_LOCATION': 'location',
  'android.permission.ACCESS_BACKGROUND_LOCATION': 'location',
  'android.permission.CAMERA': 'camera',
  'android.permission.RECORD_AUDIO': 'microphone',
  'android.permission.READ_CONTACTS': 'contacts',
  'android.permission.WRITE_CONTACTS': 'contacts',
  'android.permission.READ_SMS': 'sms',
  'android.permission.SEND_SMS': 'sms',
  'android.permission.RECEIVE_SMS': 'sms',
  'android.permission.READ_CALL_LOG': 'calls',
  'android.permission.READ_PHONE_STATE': 'phone',
  'android.permission.CALL_PHONE': 'calls',
  'android.permission.READ_EXTERNAL_STORAGE': 'storage',
  'android.permission.WRITE_EXTERNAL_STORAGE': 'storage',
  'android.permission.MANAGE_EXTERNAL_STORAGE': 'storage',
  'android.permission.READ_MEDIA_IMAGES': 'media',
  'android.permission.READ_MEDIA_VIDEO': 'media',
  'android.permission.SYSTEM_ALERT_WINDOW': 'overlay',
  'android.permission.REQUEST_INSTALL_PACKAGES': 'install',
};

/// Human-friendly permission label (both short English and Persian).
String friendlyPermissionName(String permission, {required bool fa}) {
  final short = permission.split('.').last;
  return switch (short) {
    'ACCESS_FINE_LOCATION' => fa ? 'موقعیت مکانی دقیق (GPS)' : 'Precise Location',
    'ACCESS_COARSE_LOCATION' => fa ? 'موقعیت مکانی تقریبی' : 'Approximate Location',
    'ACCESS_BACKGROUND_LOCATION' =>
      fa ? 'موقعیت در پس‌زمینه' : 'Background Location',
    'CAMERA' => fa ? 'دوربین' : 'Camera',
    'RECORD_AUDIO' => fa ? 'میکروفون / ضبط صدا' : 'Microphone',
    'READ_CONTACTS' => fa ? 'خواندن مخاطبین' : 'Read Contacts',
    'WRITE_CONTACTS' => fa ? 'ویرایش مخاطبین' : 'Modify Contacts',
    'READ_SMS' => fa ? 'خواندن پیامک‌ها' : 'Read SMS',
    'SEND_SMS' => fa ? 'ارسال پیامک' : 'Send SMS',
    'RECEIVE_SMS' => fa ? 'دریافت پیامک' : 'Receive SMS',
    'READ_CALL_LOG' => fa ? 'تاریخچه تماس‌ها' : 'Call Log',
    'READ_PHONE_STATE' => fa ? 'وضعیت و شناسه تلفن' : 'Phone State',
    'CALL_PHONE' => fa ? 'برقراری تماس' : 'Make Calls',
    'READ_EXTERNAL_STORAGE' ||
    'WRITE_EXTERNAL_STORAGE' ||
    'MANAGE_EXTERNAL_STORAGE' =>
      fa ? 'دسترسی کامل به حافظه' : 'Storage Access',
    'READ_MEDIA_IMAGES' => fa ? 'تصاویر و گالری' : 'Photos & Images',
    'READ_MEDIA_VIDEO' => fa ? 'ویدیوها' : 'Videos',
    'SYSTEM_ALERT_WINDOW' => fa ? 'نمایش روی سایر برنامه‌ها' : 'Draw Over Apps',
    'REQUEST_INSTALL_PACKAGES' => fa ? 'نصب بسته APK' : 'Install Packages',
    'POST_NOTIFICATIONS' => fa ? 'ارسال اعلان' : 'Notifications',
    'INTERNET' => fa ? 'دسترسی اینترنت' : 'Internet',
    'BLUETOOTH' || 'BLUETOOTH_CONNECT' => fa ? 'بلوتوث' : 'Bluetooth',
    _ => short.replaceAll('_', ' ').toLowerCase(),
  };
}

/// Detailed model of an app installed on the user's Android device.
class InstalledAppDetail {
  const InstalledAppDetail({
    required this.package,
    required this.label,
    this.launcher = true,
    this.system = false,
    this.versionName = '',
    this.versionCode = 0,
    this.firstInstallTime = 0,
    this.lastUpdateTime = 0,
    this.androidCategory = -1,
    this.isGame = false,
    this.minSdk = 24,
    this.targetSdk = 34,
    this.installer = '',
    this.apkBytes = 0,
    this.dataBytes = 0,
    this.cacheBytes = 0,
    this.permissions = const [],
    this.grantedPermissions = const [],
  });

  final String package;
  final String label;
  final bool launcher;
  final bool system;
  final String versionName;
  final int versionCode;
  final int firstInstallTime;
  final int lastUpdateTime;
  final int androidCategory;
  final bool isGame;
  final int minSdk;
  final int targetSdk;
  final String installer;
  final int apkBytes;
  final int dataBytes;
  final int cacheBytes;
  final List<String> permissions;
  final List<String> grantedPermissions;

  int get totalBytes => apkBytes + dataBytes + cacheBytes;

  List<String> get sensitivePermissions => [
    for (final p in permissions)
      if (sensitivePermissionPrefixes.containsKey(p)) p,
  ];

  List<String> get grantedSensitivePermissions => [
    for (final p in grantedPermissions)
      if (sensitivePermissionPrefixes.containsKey(p)) p,
  ];

  StoreId? get installerStore => switch (installer) {
    'com.android.vending' => StoreId.googlePlay,
    'com.farsitel.bazaar' => StoreId.bazaar,
    'ir.mservices.market' => StoreId.myket,
    'org.fdroid.fdroid' || 'org.fdroid.basic' => StoreId.fdroid,
    _ => null,
  };

  int ageDays([DateTime? now]) {
    if (lastUpdateTime <= 0) return 0;
    final ref = now ?? DateTime.now();
    return ref
        .difference(DateTime.fromMillisecondsSinceEpoch(lastUpdateTime))
        .inDays;
  }

  factory InstalledAppDetail.fromPlatformMap(Map<Object?, Object?> m) {
    int asInt(String key, [int fallback = 0]) {
      final v = m[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? fallback;
    }

    List<String> asList(String key) {
      final v = m[key];
      if (v is List) return [for (final item in v) '$item'];
      return const [];
    }

    return InstalledAppDetail(
      package: '${m['package'] ?? ''}',
      label: '${m['label'] ?? ''}',
      launcher: m['launcher'] != false,
      system: m['system'] == true,
      versionName: '${m['versionName'] ?? ''}',
      versionCode: asInt('versionCode'),
      firstInstallTime: asInt('firstInstallTime'),
      lastUpdateTime: asInt('lastUpdateTime'),
      androidCategory: asInt('category', -1),
      isGame: m['isGame'] == true,
      minSdk: asInt('minSdk', 24),
      targetSdk: asInt('targetSdk', 34),
      installer: '${m['installer'] ?? ''}',
      apkBytes: asInt('apkBytes'),
      dataBytes: asInt('dataBytes'),
      cacheBytes: asInt('cacheBytes'),
      permissions: asList('permissions'),
      grantedPermissions: asList('grantedPermissions'),
    );
  }
}

/// Built-in or user-created category. An app can belong to multiple categories.
class AppCategory {
  const AppCategory({
    required this.id,
    required this.nameEn,
    required this.nameFa,
    this.iconKey = 'folder',
    this.colorValue = 0xFF816BFF,
    this.builtIn = false,
  });

  final String id;
  final String nameEn;
  final String nameFa;
  final String iconKey;
  final int colorValue;
  final bool builtIn;

  String label({required bool fa}) => fa ? nameFa : nameEn;

  Map<String, Object?> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_fa': nameFa,
    'icon': iconKey,
    'color': colorValue,
    'built_in': builtIn,
  };

  factory AppCategory.fromJson(Map<String, Object?> j) => AppCategory(
    id: '${j['id'] ?? ''}',
    nameEn: '${j['name_en'] ?? j['name'] ?? ''}',
    nameFa: '${j['name_fa'] ?? j['name'] ?? ''}',
    iconKey: '${j['icon'] ?? 'folder'}',
    colorValue: j['color'] is int ? j['color']! as int : 0xFF816BFF,
    builtIn: j['built_in'] == true,
  );
}

/// Broad built-in categories matching requirement #4.
const defaultAppCategories = <AppCategory>[
  AppCategory(
    id: 'gaming',
    nameEn: 'Gaming',
    nameFa: 'گیمینگ و بازی',
    iconKey: 'sports_esports',
    colorValue: 0xFFFF5C7A,
    builtIn: true,
  ),
  AppCategory(
    id: 'education',
    nameEn: 'Education',
    nameFa: 'آموزشی',
    iconKey: 'school',
    colorValue: 0xFF00D2FF,
    builtIn: true,
  ),
  AppCategory(
    id: 'social',
    nameEn: 'Social & Messaging',
    nameFa: 'شبکه‌های اجتماعی',
    iconKey: 'chat',
    colorValue: 0xFF816BFF,
    builtIn: true,
  ),
  AppCategory(
    id: 'media',
    nameEn: 'Photo & Video',
    nameFa: 'عکس و ویدئو',
    iconKey: 'photo_camera',
    colorValue: 0xFFFFB547,
    builtIn: true,
  ),
  AppCategory(
    id: 'ai',
    nameEn: 'AI & Smart Tools',
    nameFa: 'هوش مصنوعی',
    iconKey: 'auto_awesome',
    colorValue: 0xFF00E5A3,
    builtIn: true,
  ),
  AppCategory(
    id: 'productivity',
    nameEn: 'Productivity',
    nameFa: 'بهره‌وری و اداری',
    iconKey: 'work',
    colorValue: 0xFF56CCF2,
    builtIn: true,
  ),
  AppCategory(
    id: 'finance',
    nameEn: 'Finance & Banking',
    nameFa: 'مالی و بانکی',
    iconKey: 'account_balance',
    colorValue: 0xFF22A06B,
    builtIn: true,
  ),
  AppCategory(
    id: 'tools',
    nameEn: 'Utilities & System',
    nameFa: 'ابزارها و سیستم',
    iconKey: 'build',
    colorValue: 0xFF9EA8CE,
    builtIn: true,
  ),
  AppCategory(
    id: 'travel',
    nameEn: 'Maps & Travel',
    nameFa: 'نقشه و سفر',
    iconKey: 'map',
    colorValue: 0xFF4ECDC4,
    builtIn: true,
  ),
  AppCategory(
    id: 'shopping',
    nameEn: 'Shopping',
    nameFa: 'خرید و فروشگاه',
    iconKey: 'shopping_bag',
    colorValue: 0xFFF2994A,
    builtIn: true,
  ),
];

/// Automatically infers broad categories from Google Play / store tags,
/// Android `ApplicationInfo.category`, and local package/name heuristics.
abstract final class CategoryClassifier {
  static Set<String> inferCategories({
    required InstalledAppDetail app,
    String? storeCategory,
    String? storeDescription,
  }) {
    final ids = <String>{};
    if (app.isGame) ids.add('gaming');

    // Android ApplicationInfo.category constants (API 26+)
    switch (app.androidCategory) {
      case 0: // CATEGORY_GAME
        ids.add('gaming');
      case 1: // CATEGORY_AUDIO
      case 2: // CATEGORY_VIDEO
      case 3: // CATEGORY_IMAGE
        ids.add('media');
      case 4: // CATEGORY_SOCIAL
        ids.add('social');
      case 5: // CATEGORY_NEWS
        ids.add('education');
      case 6: // CATEGORY_MAPS
        ids.add('travel');
      case 7: // CATEGORY_PRODUCTIVITY
        ids.add('productivity');
    }

    final storeBlob =
        '${storeCategory ?? ''} ${storeDescription ?? ''}'.toLowerCase();
    _matchKeywords(storeBlob, ids);

    final localBlob = '${app.package} ${app.label}'.toLowerCase();
    _matchKeywords(localBlob, ids);

    if (ids.isEmpty) {
      ids.add(app.system ? 'tools' : 'productivity');
    }
    return ids;
  }

  static void _matchKeywords(String text, Set<String> out) {
    if (text.isEmpty) return;
    if (_hasAny(text, const [
      'game',
      'arcade',
      'puzzle',
      'action',
      'racing',
      'pubg',
      'supercell',
      'minecraft',
      'roblox',
      'chess',
      'بازی',
      'سرگرمی',
    ])) {
      out.add('gaming');
    }
    if (_hasAny(text, const [
      'education',
      'learn',
      'duolingo',
      'coursera',
      'udemy',
      'khan',
      'anki',
      'dictionary',
      'translate',
      'book',
      'fidibo',
      'taaghche',
      'آموزش',
      'کتاب',
      'لغت',
      'زبان',
    ])) {
      out.add('education');
    }
    if (_hasAny(text, const [
      'social',
      'communication',
      'messenger',
      'whatsapp',
      'telegram',
      'instagram',
      'discord',
      'rubika',
      'eitaa',
      'bale',
      'soroush',
      'shad',
      'پیام',
      'شبکه',
      'اجتماعی',
    ])) {
      out.add('social');
    }
    if (_hasAny(text, const [
      'photo',
      'video',
      'camera',
      'photography',
      'editor',
      'picsart',
      'capcut',
      'inshot',
      'snapseed',
      'lightroom',
      'canva',
      'vlc',
      'mxtech',
      'spotify',
      'aparat',
      'filimo',
      'namava',
      'عکاسی',
      'عکس',
      'ویدئو',
      'ویدیو',
      'تدوین',
      'موسیقی',
    ])) {
      out.add('media');
    }
    if (_hasAny(text, const [
      'openai',
      'chatgpt',
      'gemini',
      'claude',
      'copilot',
      'perplexity',
      'deepseek',
      'artificial intelligence',
      'ai ',
      '.ai',
      'هوش مصنوعی',
    ])) {
      out.add('ai');
    }
    if (_hasAny(text, const [
      'productivity',
      'office',
      'docs',
      'sheets',
      'notion',
      'obsidian',
      'todo',
      'calendar',
      'pdf',
      'scanner',
      'notes',
      'بهره‌وری',
      'اداری',
      'یادداشت',
    ])) {
      out.add('productivity');
    }
    if (_hasAny(text, const [
      'bank',
      'finance',
      'wallet',
      'pay',
      'mellat',
      'melli',
      'tejarat',
      'saman',
      'pasargad',
      'blu',
      'wepod',
      'asanpardakht',
      'مالی',
      'بانک',
      'پرداخت',
      'کیف پول',
    ])) {
      out.add('finance');
    }
    if (_hasAny(text, const [
      'map',
      'navigation',
      'travel',
      'snapp',
      'tapsi',
      'neshan',
      'balad',
      'waze',
      'alibaba',
      'سفر',
      'نقشه',
      'مسیریاب',
      'تاکسی',
    ])) {
      out.add('travel');
    }
    if (_hasAny(text, const [
      'shop',
      'digikala',
      'torob',
      'divar',
      'sheypoor',
      'basalam',
      'amazon',
      'خرید',
      'فروشگاه',
    ])) {
      out.add('shopping');
    }
    if (_hasAny(text, const [
      'tool',
      'util',
      'vpn',
      'browser',
      'chrome',
      'firefox',
      'files',
      'cleaner',
      'keyboard',
      'launcher',
      'authenticator',
      'ابزار',
      'مرورگر',
    ])) {
      out.add('tools');
    }
  }

  static bool _hasAny(String text, List<String> needles) {
    for (final n in needles) {
      if (text.contains(n)) return true;
    }
    return false;
  }
}

/// App metadata fetched from a single store (Google Play, Cafe Bazaar, Myket, F-Droid).
class StoreListing {
  const StoreListing({
    required this.store,
    required this.packageName,
    required this.title,
    this.developer = '',
    this.iconUrl = '',
    this.versionName = '',
    this.versionCode = 0,
    this.sizeLabel = '',
    this.sizeBytes = 0,
    this.minAndroidLabel = '',
    this.minSdk,
    this.priceLabel = '',
    this.isFree = true,
    this.rating = 0,
    this.ratingCount = 0,
    this.downloadsLabel = '',
    this.lastUpdatedLabel = '',
    this.description = '',
    this.changelog = '',
    this.category = '',
    this.screenshots = const [],
    this.permissions = const [],
    this.similarPackages = const [],
    this.storeUrl = '',
    this.deepLinkUrl = '',
    this.fetchedAtMs = 0,
  });

  final StoreId store;
  final String packageName;
  final String title;
  final String developer;
  final String iconUrl;
  final String versionName;
  final int versionCode;
  final String sizeLabel;
  final int sizeBytes;
  final String minAndroidLabel;
  final int? minSdk;
  final String priceLabel;
  final bool isFree;
  final double rating;
  final int ratingCount;
  final String downloadsLabel;
  final String lastUpdatedLabel;
  final String description;
  final String changelog;
  final String category;
  final List<String> screenshots;
  final List<String> permissions;
  final List<String> similarPackages;
  final String storeUrl;
  final String deepLinkUrl;
  final int fetchedAtMs;

  bool get isPriceKnown => priceLabel.trim().isNotEmpty || !isFree;

  StoreListing copyWith({
    String? title,
    String? developer,
    String? iconUrl,
    String? versionName,
    int? versionCode,
    String? sizeLabel,
    int? sizeBytes,
    String? minAndroidLabel,
    int? minSdk,
    String? priceLabel,
    bool? isFree,
    double? rating,
    int? ratingCount,
    String? downloadsLabel,
    String? lastUpdatedLabel,
    String? description,
    String? changelog,
    String? category,
    List<String>? screenshots,
    List<String>? permissions,
    List<String>? similarPackages,
    String? storeUrl,
    String? deepLinkUrl,
    int? fetchedAtMs,
  }) => StoreListing(
    store: store,
    packageName: packageName,
    title: title ?? this.title,
    developer: developer ?? this.developer,
    iconUrl: iconUrl ?? this.iconUrl,
    versionName: versionName ?? this.versionName,
    versionCode: versionCode ?? this.versionCode,
    sizeLabel: sizeLabel ?? this.sizeLabel,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    minAndroidLabel: minAndroidLabel ?? this.minAndroidLabel,
    minSdk: minSdk ?? this.minSdk,
    priceLabel: priceLabel ?? this.priceLabel,
    isFree: isFree ?? this.isFree,
    rating: rating ?? this.rating,
    ratingCount: ratingCount ?? this.ratingCount,
    downloadsLabel: downloadsLabel ?? this.downloadsLabel,
    lastUpdatedLabel: lastUpdatedLabel ?? this.lastUpdatedLabel,
    description: description ?? this.description,
    changelog: changelog ?? this.changelog,
    category: category ?? this.category,
    screenshots: screenshots ?? this.screenshots,
    permissions: permissions ?? this.permissions,
    similarPackages: similarPackages ?? this.similarPackages,
    storeUrl: storeUrl ?? this.storeUrl,
    deepLinkUrl: deepLinkUrl ?? this.deepLinkUrl,
    fetchedAtMs: fetchedAtMs ?? this.fetchedAtMs,
  );

  Map<String, Object?> toJson() => {
    'store': store.key,
    'package': packageName,
    'title': title,
    'developer': developer,
    'icon_url': iconUrl,
    'version_name': versionName,
    'version_code': versionCode,
    'size_label': sizeLabel,
    'size_bytes': sizeBytes,
    'min_android': minAndroidLabel,
    'min_sdk': minSdk,
    'price_label': priceLabel,
    'is_free': isFree,
    'rating': rating,
    'rating_count': ratingCount,
    'downloads_label': downloadsLabel,
    'last_updated': lastUpdatedLabel,
    'description': description,
    'changelog': changelog,
    'category': category,
    'screenshots': screenshots,
    'permissions': permissions,
    'similar_packages': similarPackages,
    'store_url': storeUrl,
    'deep_link': deepLinkUrl,
    'fetched_at': fetchedAtMs,
  };

  factory StoreListing.fromJson(Map<String, Object?> j) => StoreListing(
    store: StoreId.fromKey('${j['store']}') ?? StoreId.googlePlay,
    packageName: '${j['package'] ?? ''}',
    title: '${j['title'] ?? ''}',
    developer: '${j['developer'] ?? ''}',
    iconUrl: '${j['icon_url'] ?? ''}',
    versionName: '${j['version_name'] ?? ''}',
    versionCode: j['version_code'] is int ? j['version_code']! as int : 0,
    sizeLabel: '${j['size_label'] ?? ''}',
    sizeBytes: j['size_bytes'] is int ? j['size_bytes']! as int : 0,
    minAndroidLabel: '${j['min_android'] ?? ''}',
    minSdk: j['min_sdk'] is int ? j['min_sdk']! as int : null,
    priceLabel: '${j['price_label'] ?? ''}',
    isFree: j['is_free'] != false,
    rating: j['rating'] is num ? (j['rating']! as num).toDouble() : 0,
    ratingCount: j['rating_count'] is int ? j['rating_count']! as int : 0,
    downloadsLabel: '${j['downloads_label'] ?? ''}',
    lastUpdatedLabel: '${j['last_updated'] ?? ''}',
    description: '${j['description'] ?? ''}',
    changelog: '${j['changelog'] ?? ''}',
    category: '${j['category'] ?? ''}',
    screenshots: [
      for (final s in (j['screenshots'] as List<Object?>? ?? const [])) '$s',
    ],
    permissions: [
      for (final s in (j['permissions'] as List<Object?>? ?? const [])) '$s',
    ],
    similarPackages: [
      for (final s in (j['similar_packages'] as List<Object?>? ?? const []))
        '$s',
    ],
    storeUrl: '${j['store_url'] ?? ''}',
    deepLinkUrl: '${j['deep_link'] ?? ''}',
    fetchedAtMs: j['fetched_at'] is int ? j['fetched_at']! as int : 0,
  );
}

/// Unified app entry merging listings for the same [packageName] across
/// Google Play, Cafe Bazaar, and Myket into a single deduplicated card/profile.
class UnifiedAppResult {
  UnifiedAppResult({
    required this.packageName,
    Map<StoreId, StoreListing>? listings,
    this.relevanceScore = 0,
    this.reasonText = '',
  }) : listings = listings ?? {};

  final String packageName;
  final Map<StoreId, StoreListing> listings;
  final double relevanceScore;
  final String reasonText;

  static const _priority = [
    StoreId.googlePlay,
    StoreId.bazaar,
    StoreId.myket,
    StoreId.fdroid,
  ];

  StoreListing? get primary {
    for (final s in _priority) {
      final l = listings[s];
      if (l != null) return l;
    }
    return listings.values.isEmpty ? null : listings.values.first;
  }

  String get displayTitle {
    for (final s in _priority) {
      final t = listings[s]?.title.trim() ?? '';
      if (t.isNotEmpty) return t;
    }
    return packageName;
  }

  String get developer {
    for (final s in _priority) {
      final d = listings[s]?.developer.trim() ?? '';
      if (d.isNotEmpty) return d;
    }
    return '';
  }

  String get iconUrl {
    for (final s in _priority) {
      final u = listings[s]?.iconUrl.trim() ?? '';
      if (u.isNotEmpty) return u;
    }
    return '';
  }

  String get description {
    String best = '';
    for (final l in listings.values) {
      if (l.description.trim().length > best.length) {
        best = l.description.trim();
      }
    }
    return best;
  }

  String get category {
    for (final s in _priority) {
      final c = listings[s]?.category.trim() ?? '';
      if (c.isNotEmpty) return c;
    }
    return '';
  }

  bool get hasKnownPrice => listings.values.any((l) => l.isPriceKnown);

  bool get isFreeAnywhere =>
      listings.isNotEmpty && listings.values.any((l) => l.isFree);

  bool get hasPaidListing => listings.values.any((l) => !l.isFree);

  double get bestRating {
    double best = 0;
    for (final l in listings.values) {
      if (l.rating > best) best = l.rating;
    }
    return best;
  }

  int get totalRatingCount {
    int sum = 0;
    for (final l in listings.values) {
      sum += l.ratingCount;
    }
    return sum;
  }

  int get smallestSizeBytes {
    int best = 0;
    for (final l in listings.values) {
      if (l.sizeBytes > 0 && (best == 0 || l.sizeBytes < best)) {
        best = l.sizeBytes;
      }
    }
    return best;
  }

  String get bestSizeLabel {
    for (final l in listings.values) {
      if (l.sizeBytes > 0) return formatStorageBytes(l.sizeBytes);
    }
    for (final l in listings.values) {
      if (l.sizeLabel.trim().isNotEmpty) return l.sizeLabel.trim();
    }
    return '';
  }

  int? get minSdkRequired {
    for (final l in listings.values) {
      if (l.minSdk != null && l.minSdk! > 0) return l.minSdk;
      final parsed = parseMinSdkFromLabel(l.minAndroidLabel);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String get minAndroidLabel {
    for (final l in listings.values) {
      if (l.minAndroidLabel.trim().isNotEmpty) return l.minAndroidLabel.trim();
    }
    return formatMinAndroidFromSdk(minSdkRequired);
  }

  bool isCompatibleWith(DeviceEnvironment device) {
    final req = minSdkRequired;
    if (req == null) return true;
    return device.sdkInt >= req;
  }

  List<String> get allScreenshots {
    final seen = <String>{};
    final out = <String>[];
    for (final s in _priority) {
      final l = listings[s];
      if (l == null) continue;
      for (final url in l.screenshots) {
        if (url.isNotEmpty && seen.add(url)) out.add(url);
      }
    }
    return out;
  }

  List<String> get allPermissions {
    final seen = <String>{};
    final out = <String>[];
    for (final l in listings.values) {
      for (final p in l.permissions) {
        if (p.isNotEmpty && seen.add(p)) out.add(p);
      }
    }
    return out;
  }

  List<String> get similarPackages {
    final seen = <String>{packageName};
    final out = <String>[];
    for (final l in listings.values) {
      for (final p in l.similarPackages) {
        if (p.isNotEmpty && seen.add(p)) out.add(p);
      }
    }
    return out;
  }

  void mergeListing(StoreListing listing) {
    final existing = listings[listing.store];
    if (existing == null) {
      listings[listing.store] = listing;
      return;
    }
    listings[listing.store] = existing.copyWith(
      title: listing.title.isNotEmpty ? listing.title : null,
      developer: listing.developer.isNotEmpty ? listing.developer : null,
      iconUrl: listing.iconUrl.isNotEmpty ? listing.iconUrl : null,
      versionName: listing.versionName.isNotEmpty ? listing.versionName : null,
      versionCode: listing.versionCode > 0 ? listing.versionCode : null,
      sizeLabel: listing.sizeLabel.isNotEmpty ? listing.sizeLabel : null,
      sizeBytes: listing.sizeBytes > 0 ? listing.sizeBytes : null,
      minAndroidLabel:
          listing.minAndroidLabel.isNotEmpty ? listing.minAndroidLabel : null,
      minSdk: listing.minSdk ?? existing.minSdk,
      priceLabel: listing.priceLabel.isNotEmpty ? listing.priceLabel : null,
      isFree: listing.isFree,
      rating: listing.rating > 0 ? listing.rating : null,
      ratingCount: listing.ratingCount > 0 ? listing.ratingCount : null,
      downloadsLabel:
          listing.downloadsLabel.isNotEmpty ? listing.downloadsLabel : null,
      lastUpdatedLabel:
          listing.lastUpdatedLabel.isNotEmpty ? listing.lastUpdatedLabel : null,
      description: listing.description.isNotEmpty ? listing.description : null,
      changelog: listing.changelog.isNotEmpty ? listing.changelog : null,
      category: listing.category.isNotEmpty ? listing.category : null,
      screenshots: listing.screenshots.isNotEmpty ? listing.screenshots : null,
      permissions: listing.permissions.isNotEmpty ? listing.permissions : null,
      similarPackages:
          listing.similarPackages.isNotEmpty ? listing.similarPackages : null,
      storeUrl: listing.storeUrl.isNotEmpty ? listing.storeUrl : null,
      deepLinkUrl: listing.deepLinkUrl.isNotEmpty ? listing.deepLinkUrl : null,
      fetchedAtMs:
          listing.fetchedAtMs > 0 ? listing.fetchedAtMs : existing.fetchedAtMs,
    );
  }
}

/// Historical or cross-store version entry for an app (#11 & #16).
class AppVersionRecord {
  const AppVersionRecord({
    required this.versionName,
    this.versionCode = 0,
    required this.source,
    this.dateLabel = '',
    this.sizeLabel = '',
    this.notes = '',
  });

  final String versionName;
  final int versionCode;
  final String source;
  final String dateLabel;
  final String sizeLabel;
  final String notes;

  Map<String, Object?> toJson() => {
    'version_name': versionName,
    'version_code': versionCode,
    'source': source,
    'date': dateLabel,
    'size': sizeLabel,
    'notes': notes,
  };

  factory AppVersionRecord.fromJson(Map<String, Object?> j) =>
      AppVersionRecord(
        versionName: '${j['version_name'] ?? ''}',
        versionCode: j['version_code'] is int ? j['version_code']! as int : 0,
        source: '${j['source'] ?? ''}',
        dateLabel: '${j['date'] ?? ''}',
        sizeLabel: '${j['size'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
      );
}

/// Lightweight entry for a non-installed app saved inside a Collection (#14).
class CollectionAppEntry {
  const CollectionAppEntry({
    required this.packageName,
    required this.title,
    this.iconUrl = '',
    this.storeUrl = '',
  });

  final String packageName;
  final String title;
  final String iconUrl;
  final String storeUrl;

  Map<String, Object?> toJson() => {
    'package': packageName,
    'title': title,
    'icon_url': iconUrl,
    'store_url': storeUrl,
  };

  factory CollectionAppEntry.fromJson(Map<String, Object?> j) =>
      CollectionAppEntry(
        packageName: '${j['package'] ?? ''}',
        title: '${j['title'] ?? ''}',
        iconUrl: '${j['icon_url'] ?? ''}',
        storeUrl: '${j['store_url'] ?? ''}',
      );
}

/// User collection of apps (#14).
class AppCollection {
  const AppCollection({
    required this.id,
    required this.nameEn,
    required this.nameFa,
    this.descriptionEn = '',
    this.descriptionFa = '',
    this.iconKey = 'collections_bookmark',
    this.items = const [],
    this.isPreset = false,
  });

  final String id;
  final String nameEn;
  final String nameFa;
  final String descriptionEn;
  final String descriptionFa;
  final String iconKey;
  final List<CollectionAppEntry> items;
  final bool isPreset;

  String label({required bool fa}) =>
      fa ? (nameFa.isNotEmpty ? nameFa : nameEn) : (nameEn.isNotEmpty ? nameEn : nameFa);

  String description({required bool fa}) => fa
      ? (descriptionFa.isNotEmpty ? descriptionFa : descriptionEn)
      : (descriptionEn.isNotEmpty ? descriptionEn : descriptionFa);

  bool containsPackage(String pkg) =>
      items.any((item) => item.packageName == pkg);

  AppCollection copyWith({
    String? nameEn,
    String? nameFa,
    String? descriptionEn,
    String? descriptionFa,
    List<CollectionAppEntry>? items,
  }) => AppCollection(
    id: id,
    nameEn: nameEn ?? this.nameEn,
    nameFa: nameFa ?? this.nameFa,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    descriptionFa: descriptionFa ?? this.descriptionFa,
    iconKey: iconKey,
    items: items ?? this.items,
    isPreset: isPreset,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name_en': nameEn,
    'name_fa': nameFa,
    'desc_en': descriptionEn,
    'desc_fa': descriptionFa,
    'icon': iconKey,
    'is_preset': isPreset,
    'items': [for (final i in items) i.toJson()],
  };

  factory AppCollection.fromJson(Map<String, Object?> j) => AppCollection(
    id: '${j['id'] ?? ''}',
    nameEn: '${j['name_en'] ?? j['name'] ?? ''}',
    nameFa: '${j['name_fa'] ?? j['name'] ?? ''}',
    descriptionEn: '${j['desc_en'] ?? j['description'] ?? ''}',
    descriptionFa: '${j['desc_fa'] ?? j['description'] ?? ''}',
    iconKey: '${j['icon'] ?? 'collections_bookmark'}',
    isPreset: j['is_preset'] == true,
    items: [
      for (final raw in (j['items'] as List<Object?>? ?? const []))
        if (raw is Map<String, Object?>) CollectionAppEntry.fromJson(raw),
    ],
  );

  /// Encodes a shareable payload containing both readable summary and JSON.
  String toShareText({required bool fa}) {
    final buf = StringBuffer()
      ..writeln('📦 ${label(fa: fa)}')
      ..writeln(description(fa: fa))
      ..writeln('');
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      buf.writeln('${i + 1}. ${item.title} (${item.packageName})');
    }
    buf
      ..writeln('')
      ..writeln('---ICEDRAGON-COLLECTION---')
      ..write(base64Url.encode(utf8.encode(jsonEncode(toJson()))));
    return buf.toString();
  }

  /// Parses either raw JSON or a shared text payload containing
  /// `---ICEDRAGON-COLLECTION---`.
  static AppCollection? tryParseShared(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      const marker = '---ICEDRAGON-COLLECTION---';
      if (trimmed.contains(marker)) {
        final b64 = trimmed.split(marker).last.trim().split(RegExp(r'\s+')).first;
        final decoded = utf8.decode(base64Url.decode(b64));
        final json = jsonDecode(decoded);
        if (json is Map<String, Object?>) {
          final parsed = AppCollection.fromJson(json);
          return AppCollection(
            id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
            nameEn: parsed.nameEn,
            nameFa: parsed.nameFa,
            descriptionEn: parsed.descriptionEn,
            descriptionFa: parsed.descriptionFa,
            iconKey: parsed.iconKey,
            items: parsed.items,
            isPreset: false,
          );
        }
      }
      final json = jsonDecode(trimmed);
      if (json is Map<String, Object?>) {
        final parsed = AppCollection.fromJson(json);
        if (parsed.label(fa: false).isNotEmpty) {
          return AppCollection(
            id: 'imported_${DateTime.now().millisecondsSinceEpoch}',
            nameEn: parsed.nameEn,
            nameFa: parsed.nameFa,
            descriptionEn: parsed.descriptionEn,
            descriptionFa: parsed.descriptionFa,
            iconKey: parsed.iconKey,
            items: parsed.items,
            isPreset: false,
          );
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

/// Starter collections matching requirement #14.
const defaultAppCollections = <AppCollection>[
  AppCollection(
    id: 'essential',
    nameEn: 'Essential Apps',
    nameFa: 'اپلیکیشن‌های ضروری',
    descriptionEn: 'Core daily tools every Android phone needs',
    descriptionFa: 'برنامه‌های کاربردی و ضروری برای استفاده روزمره',
    iconKey: 'star',
    isPreset: true,
  ),
  AppCollection(
    id: 'best_games',
    nameEn: 'Best Games',
    nameFa: 'بهترین بازی‌ها',
    descriptionEn: 'Top picked mobile games',
    descriptionFa: 'گلچین بهترین بازی‌های موبایل',
    iconKey: 'sports_esports',
    isPreset: true,
  ),
  AppCollection(
    id: 'ai_tools',
    nameEn: 'AI Tools',
    nameFa: 'ابزارهای هوش مصنوعی',
    descriptionEn: 'Assistants, image generators, and AI utilities',
    descriptionFa: 'دستیارهای هوش مصنوعی، تولید تصویر و ابزارهای هوشمند',
    iconKey: 'auto_awesome',
    isPreset: true,
  ),
  AppCollection(
    id: 'video_editing',
    nameEn: 'Video Editing',
    nameFa: 'برنامه‌های ادیت ویدئو',
    descriptionEn: 'Cut, grade, and export mobile videos',
    descriptionFa: 'تدوین، افکت و خروجی حرفه‌ای ویدئو در موبایل',
    iconKey: 'movie',
    isPreset: true,
  ),
  AppCollection(
    id: 'install_later',
    nameEn: 'Install Later',
    nameFa: 'اپلیکیشن‌هایی که بعداً می‌خوام نصب کنم',
    descriptionEn: 'Bookmarked apps from stores for later installation',
    descriptionFa: 'برنامه‌های نشان‌شده از فروشگاه‌ها برای نصب در آینده',
    iconKey: 'bookmark',
    isPreset: true,
  ),
];

/// Available update record for an installed app (#7 & #15).
class UpdateCandidate {
  const UpdateCandidate({
    required this.app,
    required this.listing,
  });

  final InstalledAppDetail app;
  final StoreListing listing;

  Map<String, Object?> toJson() => {
    'package': app.package,
    'listing': listing.toJson(),
  };
}

/// Result of running non-root Speed Boost before launching an app (#5).
class BoostReport {
  const BoostReport({
    required this.beforeAvailBytes,
    required this.afterAvailBytes,
    required this.totalRamBytes,
    required this.processesTrimmed,
    required this.launchedPackage,
  });

  final int beforeAvailBytes;
  final int afterAvailBytes;
  final int totalRamBytes;
  final int processesTrimmed;
  final String launchedPackage;

  int get gainedBytes => math.max(0, afterAvailBytes - beforeAvailBytes);

  factory BoostReport.fromPlatformMap(
    Map<Object?, Object?> m,
    String launchedPackage,
  ) {
    int asInt(String k) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return BoostReport(
      beforeAvailBytes: asInt('beforeAvailBytes'),
      afterAvailBytes: asInt('afterAvailBytes'),
      totalRamBytes: asInt('totalBytes'),
      processesTrimmed: asInt('touchedCount'),
      launchedPackage: launchedPackage,
    );
  }
}

/// Cluster of installed apps with overlapping functionality (#12 & #16).
class DuplicateGroup {
  const DuplicateGroup({
    required this.roleKey,
    required this.titleEn,
    required this.titleFa,
    required this.apps,
  });

  final String roleKey;
  final String titleEn;
  final String titleFa;
  final List<InstalledAppDetail> apps;

  String label({required bool fa}) => fa ? titleFa : titleEn;
}

/// App flagged for unnecessary or elevated sensitive permissions (#12).
class PermissionAuditItem {
  const PermissionAuditItem({
    required this.app,
    required this.flaggedPermissions,
    required this.grantedFlagged,
    required this.riskScore,
  });

  final InstalledAppDetail app;
  final List<String> flaggedPermissions;
  final List<String> grantedFlagged;
  final int riskScore;
}

/// Full diagnostic report produced by the Phone Management Assistant (#12).
class AssistantReport {
  const AssistantReport({
    required this.device,
    required this.largeApps,
    required this.outdatedApps,
    required this.staleApps,
    required this.duplicateGroups,
    required this.permissionAudits,
    required this.potentialReclaimBytes,
    required this.generatedAt,
  });

  final DeviceEnvironment device;
  final List<InstalledAppDetail> largeApps;
  final List<UpdateCandidate> outdatedApps;
  final List<InstalledAppDetail> staleApps;
  final List<DuplicateGroup> duplicateGroups;
  final List<PermissionAuditItem> permissionAudits;
  final int potentialReclaimBytes;
  final DateTime generatedAt;
}

/// Sort options for Unified Multi-Store Search (#10).
enum StoreSortMode {
  relevance,
  popularity,
  sizeAsc,
  sizeDesc,
  storeCount,
}
