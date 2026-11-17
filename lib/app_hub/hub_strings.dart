import 'package:flutter/widgets.dart';

/// Bilingual localization (Persian & English) for the App Manager,
/// Multi-Store Hub, Phone Assistant, Collections, Updates, and AI Intelligence.
class HubStrings {
  const HubStrings._(this.lang);

  final String lang;

  static HubStrings of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return HubStrings._(code);
  }

  static HubStrings forCode(String code) => HubStrings._(code);

  bool get isFa => lang == 'fa';

  String tr(String en, String fa) => isFa ? fa : en;

  // Navigation tabs
  String get navApps => tr('Apps', 'برنامه‌ها');
  String get navStores => tr('Stores', 'فروشگاه‌ها');
  String get navAssistant => tr('Assistant & Storage', 'دستیار و حافظه');

  // Common actions
  String get search => tr('Search', 'جستجو');
  String get refresh => tr('Refresh', 'بروزرسانی');
  String get all => tr('All', 'همه');
  String get cancel => tr('Cancel', 'انصراف');
  String get save => tr('Save', 'ذخیره');
  String get delete => tr('Delete', 'حذف');
  String get create => tr('Create', 'ساخت');
  String get close => tr('Close', 'بستن');
  String get share => tr('Share', 'اشتراک‌گذاری');
  String get compare => tr('Compare', 'مقایسه');
  String get open => tr('Open', 'باز کردن');
  String get install => tr('Install', 'نصب');
  String get update => tr('Update', 'آپدیت');
  String get free => tr('Free', 'رایگان');
  String get paid => tr('Paid', 'پولی');
  String get unknown => tr('Unknown', 'نامشخص');
  String get compatible => tr('Compatible', 'سازگار');
  String get incompatible => tr('Incompatible', 'ناسازگار');
  String get systemApps => tr('System apps', 'برنامه‌های سیستمی');
  String get updatesOnly => tr('Updates', 'دارای آپدیت');
  String get selectAll => tr('Select all', 'انتخاب همه');
  String get clearSelection => tr('Clear', 'لغو انتخاب');
  String get done => tr('Done', 'انجام شد');
  String get retry => tr('Retry', 'تلاش دوباره');
  String get apply => tr('Apply', 'اعمال');

  // Stores
  String get storeGooglePlay => tr('Google Play', 'گوگل‌پلی');
  String get storeBazaar => tr('Cafe Bazaar', 'کافه‌بازار');
  String get storeMyket => tr('Myket', 'مایکت');
  String get storeAppStore => tr('App Store (Apple)', 'اپ استور (اپل)');
  String get storeFdroid => tr('F-Droid', 'اف‌دروید');

  // Apps Manager (#1, #2, #4, #5, #6, #7)
  String get appsTitle => tr('Installed Apps', 'مدیریت برنامه‌ها');
  String get searchAppsHint => tr(
    'Search apps, packages, categories…',
    'جستجو بین نام برنامه، پکیج یا دسته‌بندی…',
  );
  String get multiSelect => tr('Multi-select', 'انتخاب چندتایی');
  String selectedCount(int n) => tr('$n selected', '$n انتخاب شده');
  String get categories => tr('Categories', 'دسته‌بندی‌ها');
  String get newCategory => tr('New category', 'دسته‌بندی جدید');
  String get categoryNameEn => tr('Name (English)', 'نام انگلیسی');
  String get categoryNameFa => tr('Name (Persian)', 'نام فارسی');
  String get autoCategorize => tr('Auto-categorize', 'دسته‌بندی خودکار');
  String get autoCategorizing =>
      tr('Categorizing from store tags…', 'در حال دسته‌بندی با تگ فروشگاه‌ها…');
  String autoCategorizedDone(int n) =>
      tr('Updated categories for $n apps', 'دسته‌بندی $n برنامه بروزرسانی شد');
  String get assignCategories => tr('Assign categories', 'تعیین دسته‌بندی');
  String get addToCollection => tr('Add to collection', 'افزودن به مجموعه');
  String get batchUninstall => tr('Uninstall', 'حذف گروهی');
  String get appSettings => tr('App settings', 'تنظیمات برنامه');
  String get uninstall => tr('Uninstall', 'حذف برنامه');
  String get boostAndLaunch => tr('Boost & Launch', 'اسپید بوست و اجرا');
  String get launch => tr('Launch', 'اجرا');
  String get updateAvailableBadge =>
      tr('Update available', 'نسخه جدید موجود است');
  String get noAppsFound =>
      tr('No matching apps found', 'هیچ برنامه‌ای پیدا نشد');
  String get scanUpdates => tr('Check updates', 'بررسی آپدیت');
  String get scanningUpdates =>
      tr('Checking stores for updates…', 'در حال بررسی نسخه جدید در فروشگاه‌ها…');
  String updatesFoundCount(int n) =>
      tr('$n updates found', '$n آپدیت جدید پیدا شد');
  String get pickTwoToCompare =>
      tr('Select exactly 2 apps to compare', 'برای مقایسه دقیقاً ۲ برنامه را انتخاب کنید');

  // Sorting
  String get sortBy => tr('Sort by', 'مرتب‌سازی');
  String get sortOrder => tr('Order', 'ترتیب');
  String get sortByNameAsc => tr('Name (A-Z)', 'نام (الف - ی)');
  String get sortByNameDesc => tr('Name (Z-A)', 'نام (ی - الف)');
  String get sortBySizeDesc => tr('Largest Size', 'بزرگ‌ترین حجم');
  String get sortBySizeAsc => tr('Smallest Size', 'کمترین حجم');
  String get sortByUpdateDesc => tr('Recently Updated', 'تازه‌ترین به‌روزرسانی');
  String get sortByInstallDesc => tr('Recently Installed', 'تازه‌ترین نصب');
  String get sortByInstallAsc => tr('Oldest Installed', 'قدیمی‌ترین نصب');
  String appsFoundCount(int n) => tr('$n apps found', '$n برنامه پیدا شد');

  // Speed Boost (#5)
  String get speedBoostTitle => tr('Speed Boost', 'اسپید بوست موبایل');
  String get speedBoostActiveTitle => tr('Turbine Speed Boost', 'اسپید بوست توربو');
  String get speedBoostOptimizingRam =>
      tr('Freeing background RAM & tasks…', 'آزادسازی رم و بستن برنامه‌های زائد…');
  String get speedBoostAllocatingCpu =>
      tr('Optimizing CPU priority…', 'تنظیم اولویت پردازنده برای اجرای روان…');
  String get speedBoostPreparingExecution =>
      tr('Preparing execution buffer…', 'آماده‌سازی بافر اجرای سریع برنامه…');
  String get speedBoostLaunchingTarget =>
      tr('Boost complete! Launching app…', 'بوست با موفقیت انجام شد! در حال اجرا…');
  String get speedBoostRunning => tr(
    'Optimizing available RAM and launching…',
    'در حال بررسی رم و اجرای برنامه…',
  );
  String speedBoostDone(String freed, String freeNow, int procs) {
    if (procs > 0) {
      return tr(
        'RAM check · $procs active task(s) stopped · $freeNow free ($freed gained)',
        'بهینه‌سازی رم · $procs پردازش متوقف شد · رم آزاد: $freeNow ($freed افزایش)',
      );
    }
    return tr(
      'RAM checked · $freeNow free ($freed gained) · Launching directly',
      'رم بررسی شد · رم آزاد فعلی: $freeNow ($freed تغییر) · در حال اجرا',
    );
  }
  String get speedBoostHonestNote => tr(
    'Note: Non-rooted Android restricts global cache wiping; IceDragon trims allowed background processes and launches directly.',
    'نکته: اندروید بدون روت اجازه پاک کردن اجباری کش سایر اپ‌ها را نمی‌دهد؛ برنامه فرایندهای مجاز پس‌زمینه را آزاد و اپ را با اولویت اجرا می‌کند.',
  );

  // Store Search & Hub (#9, #10, #16)
  String get storesTitle => tr('Multi-Store Hub', 'جستجوی یکپارچه فروشگاه‌ها');
  String get smartSearchHint => tr(
    'Try "photo editor" or "برنامه ویرایش عکس"…',
    'مثلاً بنویسید «برنامه ویرایش عکس» یا «photo editor»…',
  );
  String get searchStoresButton => tr('Search across stores', 'جستجو در فروشگاه‌ها');
  String get searchingStores => tr(
    'Querying Apple App Store, Google Play, Bazaar & Myket…',
    'در حال جستجوی همزمان در اپ‌استور، مایکت، بازار و گوگل‌پلی…',
  );
  String get sortRelevance => tr('Relevance', 'مرتبط‌ترین');
  String get sortPopularity => tr('Popularity', 'محبوبیت');
  String get sortSizeAsc => tr('Smallest size', 'کمترین حجم');
  String get sortSizeDesc => tr('Largest size', 'بیشترین حجم');
  String get sortStoreCount => tr('Most stores', 'تعداد فروشگاه');
  String get filterFreeOnly => tr('Free only', 'فقط رایگان');
  String get filterCompatibleOnly => tr('Compatible', 'سازگار با گوشی');
  String get appRadar => tr('App Radar', 'رادار برنامه‌ها');
  String get appRadarSubtitle => tr(
    'New & trending apps discovered across stores',
    'شناسایی جدیدترین و محبوب‌ترین برنامه‌های فروشگاه‌ها',
  );
  String get searchTab => tr('Smart Search', 'جستجوی هوشمند');
  String get radarTab => tr('App Radar', 'رادار برنامه‌ها');
  String get noStoreResults => tr(
    'Search for an app or keyword across Myket, Bazaar and Google Play',
    'نام یا کاربرد برنامه را بنویسید تا در مایکت، بازار و گوگل‌پلی پیدا شود',
  );
  String availableInStores(int count) =>
      tr('In $count store(s)', 'موجود در $count فروشگاه');
  String get requiredAndroid => tr('Android req.', 'اندروید موردنیاز');
  String get downloadSize => tr('Download size', 'حجم دانلود');
  String get version => tr('Version', 'نسخه');
  String get price => tr('Price', 'قیمت');
  String get installedBadge => tr('Installed', 'نصب‌شده');

  // App Profile (#11, #16)
  String get appProfile => tr('App Profile', 'پروفایل اختصاصی برنامه');
  String get screenshots => tr('Screenshots', 'تصاویر برنامه');
  String get descriptionAndFeatures =>
      tr('Description & Features', 'توضیحات و امکانات');
  String get whatsNew => tr("What's new", 'تغییرات نسخه جدید');
  String get lastUpdated => tr('Last updated', 'آخرین بروزرسانی');
  String get apkSize => tr('APK size', 'حجم APK');
  String get permissions => tr('Permissions', 'مجوزهای دسترسی');
  String get sensitivePermissions => tr('Sensitive', 'حساس');
  String get granted => tr('Granted', 'مجاز');
  String get notGranted => tr('Denied', 'غیرمجاز');
  String get noPermissions =>
      tr('No special permissions requested', 'مجوز خاصی درخواست نشده است');
  String get offeringStores =>
      tr('Offering Stores & Versions', 'فروشگاه‌های ارائه‌دهنده و نسخه‌ها');
  String get similarApps => tr('Similar Apps', 'برنامه‌های مشابه');
  String get versionHistory => tr('Version History', 'تاریخچه نسخه‌ها');
  String get noVersionHistory => tr(
    'Public stores only publish the latest build for this closed-source app. Locally tracked updates and F-Droid builds appear here.',
    'فروشگاه‌های عمومی فقط آخرین نسخه این برنامه را منتشر می‌کنند. تاریخچه آپدیت‌های ثبت‌شده و نسخه‌های متن‌باز F-Droid اینجا نمایش داده می‌شود.',
  );
  String get smartAlternativeTitle =>
      tr('Smart Free Alternatives', 'جایگزین رایگان هوشمند');
  String get shareAppSummary => tr('Share App Profile', 'اشتراک‌گذاری صفحه برنامه');
  String get compatibilityCheck => tr('App Compatibility', 'سازگاری با گوشی');
  String compatibleDetail(String deviceVer, String reqVer) => tr(
    'Compatible with your device (Android $deviceVer · requires $reqVer)',
    'کاملاً سازگار با گوشی شما (اندروید $deviceVer · نیازمند $reqVer)',
  );
  String incompatibleDetail(String deviceVer, String reqVer) => tr(
    'May not work on your device (Android $deviceVer · requires $reqVer)',
    'احتمال ناسازگاری با گوشی شما (اندروید $deviceVer · نیازمند $reqVer)',
  );
  String get compareWithAnother =>
      tr('Compare with another app', 'مقایسه با برنامه دیگر');

  // Assistant, Updates, Collections, AI (#12, #14, #15, #16)
  String get assistantTab => tr('Phone Doctor', 'دستیار گوشی');
  String get updatesTab => tr('Update Center', 'آپدیت مرکزی');
  String get collectionsTab => tr('Collections', 'مجموعه‌ها');
  String get aiTab => tr('App Intelligence', 'هوش مصنوعی');

  String get deviceOverview => tr('Device Health', 'وضعیت دستگاه');
  String get freeStorage => tr('Free storage', 'فضای آزاد');
  String get freeRam => tr('Free RAM', 'رم آزاد');
  String get androidVersion => tr('Android', 'نسخه اندروید');
  String get runDiagnostics => tr('Scan phone now', 'بررسی هوشمند گوشی');

  String get largeAppsTitle => tr('Large Storage Apps', 'برنامه‌های پرحجم');
  String get outdatedAppsTitle =>
      tr('Outdated / Stale Apps', 'برنامه‌های قدیمی');
  String get duplicateAppsTitle =>
      tr('Similar / Duplicate Apps', 'برنامه‌های مشابه');
  String get riskyPermsTitle =>
      tr('Unnecessary Permissions', 'مجوزهای غیرضروری');
  String get spaceTipsTitle =>
      tr('How to Free More Space', 'پیشنهاد آزادسازی فضا');
  String reclaimableSpace(String size) =>
      tr('Potential savings: ~$size', 'فضای قابل آزادسازی: حدود $size');
  String get nothingToReclaim => tr(
    'No duplicate apps found to free space',
    'موردی برای آزادسازی پیدا نشد',
  );
  String get openAndroidStorage =>
      tr('Clear cache in settings', 'تنظیمات حافظه / کش');
  String get reviewPermissions => tr('Review permissions', 'بررسی مجوزها');

  // Central Updates (#15)
  String get checkAllUpdates =>
      tr('Scan all installed apps', 'بررسی همه برنامه‌ها');
  String get noUpdatesYet => tr(
    'Tap scan to check installed apps across Google Play, Cafe Bazaar, and Myket.',
    'برای بررسی نسخه جدید برنامه‌های نصب‌شده در گوگل‌پلی، بازار و مایکت دکمه اسکن را بزنید.',
  );
  String get allUpToDate =>
      tr('All checked apps are up to date!', 'همه برنامه‌های بررسی‌شده بروز هستند!');
  String get openTargetStore => tr('Update in store', 'آپدیت از فروشگاه');

  // Collections (#14)
  String get newCollection => tr('New collection', 'مجموعه جدید');
  String get collectionName => tr('Collection name', 'نام مجموعه');
  String get collectionDesc => tr('Description', 'توضیحات');
  String get shareCollection => tr('Share collection', 'اشتراک‌گذاری مجموعه');
  String get importCollection => tr('Import shared', 'درون‌ریزی مجموعه');
  String get importHint => tr(
    'Paste a shared collection code or JSON here',
    'کد یا متن مجموعه اشتراک‌گذاری‌شده را اینجا وارد کنید',
  );
  String get emptyCollection => tr(
    'No apps in this collection yet. Add from Apps or Store Search.',
    'هنوز برنامه‌ای در این مجموعه نیست. از بخش برنامه‌ها یا فروشگاه اضافه کنید.',
  );

  // App Intelligence AI (#16)
  String get aiIntro => tr(
    'Describe what you need (e.g. "lightweight photo editor without ads" or "AI voice assistant") and App Intelligence will find & rank the best options for your Android device.',
    'نیاز خودتان را بنویسید (مثلاً «برنامه سبک ویرایش عکس بدون تبلیغ» یا «ابزار هوش مصنوعی») تا App Intelligence بهترین گزینه‌های سازگار با گوشی شما را پیشنهاد دهد.',
  );
  String get aiInputHint => tr(
    'What app do you need?',
    'چه نوع برنامه‌ای لازم دارید؟',
  );
  String get askAi => tr('Recommend apps', 'پیشنهاد هوشمند');
  String get aiModeLocal =>
      tr('Built-in Smart Engine (Offline + Live Stores)', 'موتور هوشمند داخلی + فروشگاه‌های زنده');
  String get aiModeGemini => tr('Gemini AI + Live Stores', 'هوش مصنوعی Gemini + فروشگاه‌های زنده');
  String get geminiApiKeyLabel =>
      tr('Optional Gemini API Key', 'کلید Gemini API (اختیاری)');
  String get geminiApiKeyHint => tr(
    'Leave empty to use the built-in offline App Intelligence engine',
    'در صورت خالی بودن از موتور هوشمند داخلی بدون نیاز به کلید استفاده می‌شود',
  );

  // Comparison (#13)
  String get compareTitle => tr('Compare Apps', 'مقایسه واقعی اپلیکیشن‌ها');
  String get featureColumn => tr('Feature', 'ویژگی');
  String get storeColumn => tr('Stores', 'فروشگاه');
  String get permissionsColumn => tr('Permissions', 'مجوزها');
  String get ratingColumn => tr('Rating', 'امتیاز');
  String get minAndroidColumn => tr('Min Android', 'حداقل اندروید');
  String get categoryColumn => tr('Category', 'دسته‌بندی');
  String get selectAppA => tr('Select App A', 'انتخاب برنامه اول');
  String get selectAppB => tr('Select App B', 'انتخاب برنامه دوم');

  // Settings section
  String get appHubSettingsTitle =>
      tr('App Manager & Smart Hub', 'مدیریت برنامه و فروشگاه‌ها');
  String get boostBeforeLaunchLabel => tr(
    'Speed Boost when launching apps',
    'اجرای اسپید بوست هنگام باز کردن برنامه‌ها',
  );
  String get quickLanguageLabel => tr('App Language', 'زبان اپلیکیشن');
  String get appTitle => tr('IceDragon App Hub', 'مدیریت هوشمند آیس‌دراگون');
  String get navSettings => tr('Settings', 'تنظیمات');
  String get themeLabel => tr('Appearance', 'ظاهر برنامه');
  String get themeDark => tr('Dark Glass', 'شیشه‌ای تیره');
  String get themeLight => tr('Light', 'روشن');
  String get themeSystem => tr('System', 'سیستم');
  // Download Storage Location
  String get downloadLocationTitle =>
      tr('Download Storage Location', 'محل ذخیره فایل‌ها و دانلودها');
  String get downloadLocationSubtitle => tr(
    'Choose where downloaded apps and updates are saved (App default, Downloads, or custom)',
    'انتخاب مسیر ذخیره فایل‌ها و برنامه‌های دانلودی (پیشنهادی برنامه، پوشه دانلودها یا دلخواه)',
  );
  String get downloadLocationRecommended => tr(
    'Recommended (Downloads/IceDragonHub)',
    'پیشنهادی برنامه (Downloads/IceDragonHub)',
  );
  String get downloadLocationPublic =>
      tr('Public Downloads folder', 'پوشه عمومی دانلودهای سیستم');
  String get downloadLocationCustom =>
      tr('Custom storage directory', 'مسیر سفارشی دلخواه');
  String get customDownloadPathHint =>
      tr('e.g. /storage/emulated/0/MyApps', 'مثلاً: /storage/emulated/0/MyApps');
  String get customPathInvalid => tr(
    'Please enter a valid directory path',
    'لطفاً یک مسیر معتبر پوشه وارد کنید',
  );
  String get downloadPathSaved =>
      tr('Download location saved', 'مسیر دانلود با موفقیت ذخیره شد');

  // Honest feedback & status strings
  String appLaunchFailed(String name) => tr(
    'Could not launch $name (no launchable activity)',
    'امکان اجرای «$name» وجود ندارد (صفحه اجرا ندارد)',
  );
  String appLaunchedPlain(String name) =>
      tr('Launched $name', '«$name» اجرا شد');
  String get uninstallCanceled => tr(
    'Uninstall was canceled or unavailable',
    'حذف برنامه لغو شد یا در دسترس نبود',
  );
  String uninstallBatchResult(int removed, int total) => tr(
    '$removed of $total app(s) uninstalled',
    '$removed از $total برنامه حذف شد',
  );
  String get importCollectionInvalid => tr(
    'Invalid or corrupted collection code. Paste a valid IceDragon code or JSON.',
    'کد یا متن مجموعه نامعتبر است. لطفاً یک کد یا JSON معتبر وارد کنید.',
  );
  String get aiNoMatches => tr(
    'No matching apps found across local intelligence or connected stores.',
    'برنامه مناسبی در موتور هوشمند و فروشگاه‌ها پیدا نشد.',
  );
  String aiErrorSummary(String error) =>
      tr('Recommendation failed: $error', 'خطا در پیشنهاد هوشمند: $error');

  String get zeroPermsTitle => tr(
    'Zero-permission ready',
    'آماده بدون نیاز به دسترسی حساس',
  );
  String get zeroPermsDesc => tr(
    'Works right away with no Restricted Settings or file access required.',
    'بلافاصله بعد از نصب بدون هیچ دسترسی پیچیده یا دسترسی به فایل‌های شخصی کار می‌کند.',
  );
  String get appHubTagline => tr(
    'Standalone Smart App Hub · Release v1.1.0',
    'هاب هوشمند مستقل برنامه‌ها · نسخه ۱.۱.۰',
  );
  String get storageUsedLabel => tr('Used storage', 'فضای پر شده');
  String get ramAvailableLabel => tr('Available RAM', 'رم در دسترس');

  // Storage Breakdown & Cleaner
  String get storageBreakdownTitle =>
      tr('Storage Breakdown', 'تحلیل و نمودار حافظه گوشی');
  String get storageBreakdownSubtitle => tr(
    'Visual breakdown of videos, photos, files & apps',
    'نمودار تفکیک فضای اشغال‌شده توسط عکس‌ها، ویدیوها، فایل‌ها و برنامه‌ها',
  );
  String get manageStorageAction =>
      tr('Manage & Clean Storage', 'مدیریت و پاکسازی فایل‌ها');
  String get categoryPhotos => tr('Photos', 'عکس‌ها');
  String get categoryVideos => tr('Videos', 'ویدیوها');
  String get categoryAudio => tr('Audio', 'موسیقی و صوت');
  String get categoryDocuments => tr('Files & Downloads', 'فایل‌ها و اسناد');
  String get categoryApps => tr('Apps & Data', 'برنامه‌ها و دیتا');
  String get categoryOther => tr('System & Other', 'سیستم و متفرقه');
  String get categoryFree => tr('Free Space', 'فضای آزاد');
  String get categoryLargeFiles => tr('Large Files (>20MB)', 'فایل‌های حجیم (>۲۰ مگ)');

  String countItemsLabel(int n) => tr('$n items', '$n مورد');
  String get playVideoAction => tr('Play Video', 'پخش ویدیو');
  String get previewPhotoAction => tr('Preview Photo', 'پیش‌نمایش عکس');
  String get openFileAction => tr('Open File', 'باز کردن فایل');
  String get deleteFileAction => tr('Delete File', 'حذف فایل');
  String get deleteSelectedAction =>
      tr('Delete Selected', 'حذف فایل‌های انتخاب‌شده');
  String confirmDeleteCount(int n, String size) => tr(
    'Permanently delete $n selected file(s) to free $size?',
    'آیا از حذف دائمی $n فایل انتخاب‌شده و آزادسازی $size اطمینان دارید؟',
  );
  String confirmDeleteSingle(String name, String size) => tr(
    'Permanently delete "$name" ($size)?',
    'آیا از حذف دائمی «$name» ($size) اطمینان دارید؟',
  );
  String filesDeletedSuccess(int n, String size) => tr(
    'Successfully deleted $n file(s) and freed $size.',
    '$n فایل با موفقیت حذف شد و $size فضا آزاد گردید.',
  );
  String get noFilesInCategory => tr(
    'No files found in this category.',
    'هیچ فایلی در این بخش یافت نشد.',
  );
  String get videoDetailsTitle => tr('Video Details', 'مشخصات ویدیو');
  String get durationLabel => tr('Duration', 'مدت زمان');
  String get filePathLabel => tr('Path', 'مسیر');
  String get fileSizeLabel => tr('Size', 'حجم');

  // Usage access & storage shortcuts
  String get usageAccessWarning => tr(
    'Enable Usage Access to calculate exact per-app data & cache (e.g. Chrome 5 GB)',
    'برای محاسبه دقیق حجم دیتا و کش اپ‌ها (مثل کروم ۵ گیگابایت) دسترسی استفاده را فعال کنید',
  );
  String get enableUsageAccess => tr('Enable Access', 'فعال‌سازی دسترسی');
  String get viewFilesAndVideos =>
      tr('Files, Videos & Cleaner', 'مشاهده فایل‌ها، ویدیوها و پاکسازی');
  String get storageSummaryTitle =>
      tr('Device Storage & Cleaner', 'تحلیل و پاکسازی حافظه گوشی');
  String get openStorageCleaner =>
      tr('Open Storage Cleaner', 'ورود به پاکسازی حافظه');
}
