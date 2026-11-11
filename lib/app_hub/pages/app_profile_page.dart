import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';
import 'app_compare_page.dart';
import 'hub_widgets.dart';

/// Dedicated profile page for an installed or store-discovered app (#11 & #16).
class AppProfilePage extends StatefulWidget {
  const AppProfilePage({
    super.key,
    required this.hub,
    required this.packageName,
    this.installed,
    this.initialUnified,
  });

  final HubController hub;
  final String packageName;
  final InstalledAppDetail? installed;
  final UnifiedAppResult? initialUnified;

  @override
  State<AppProfilePage> createState() => _AppProfilePageState();
}

class _AppProfilePageState extends State<AppProfilePage> {
  bool _startedLoad = false;
  bool _loadingStore = false;
  bool _loadingHistory = false;
  bool _loadingAlts = false;

  late UnifiedAppResult _unified;
  List<AppVersionRecord> _history = const [];
  List<UnifiedAppResult> _alternatives = const [];
  List<UnifiedAppResult> _similarResolved = const [];

  @override
  void initState() {
    super.initState();
    _unified =
        widget.initialUnified ??
        UnifiedAppResult(packageName: widget.packageName);
    _history = widget.hub.repo.versionHistory[widget.packageName] ?? const [];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedLoad) {
      _startedLoad = true;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    final fa = HubStrings.of(context).isFa;
    final hl = fa ? 'fa' : 'en';
    final proxy = widget.hub.activeProxyAddress;

    setState(() {
      _loadingStore = true;
      _loadingHistory = true;
    });

    try {
      await widget.hub.stores.enrichUnifiedApp(
        _unified,
        hl: hl,
        proxyAddress: proxy,
      );
      if (!mounted) return;
      setState(() => _loadingStore = false);

      // Update local version history observations from stores
      for (final l in _unified.listings.values) {
        if (l.versionName.isNotEmpty) {
          widget.hub.repo.recordVersionObservation(
            widget.packageName,
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

      // Fetch version history + similar apps + free alternatives if paid
      final hist = await widget.hub.stores.fetchVersionHistory(
        widget.packageName,
        proxyAddress: proxy,
        localRecords:
            widget.hub.repo.versionHistory[widget.packageName] ?? const [],
        unified: _unified,
      );
      if (!mounted) return;
      setState(() {
        _history = hist;
        _loadingHistory = false;
      });

      final simPkgs = _unified.similarPackages.take(6).toList();
      if (simPkgs.isNotEmpty) {
        final resolved = await Future.wait([
          for (final p in simPkgs)
            widget.hub.stores
                .fetchUnifiedApp(p, hl: hl, proxyAddress: proxy)
                .catchError((_) => UnifiedAppResult(packageName: p)),
        ]);
        if (mounted) {
          setState(() {
            _similarResolved = [
              for (final r in resolved)
                if (r.listings.isNotEmpty) r,
            ];
          });
        }
      }

      if (_unified.hasPaidListing || !_unified.isFreeAnywhere) {
        await _loadAlternatives();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingStore = false;
          _loadingHistory = false;
        });
      }
    }
  }

  Future<void> _loadAlternatives() async {
    final hl = HubStrings.of(context).isFa ? 'fa' : 'en';
    setState(() => _loadingAlts = true);
    try {
      final alts = await widget.hub.intelligence.findFreeAlternatives(
        _unified,
        hl: hl,
        proxyAddress: widget.hub.activeProxyAddress,
      );
      if (mounted) {
        setState(() => _alternatives = alts);
      }
    } finally {
      if (mounted) setState(() => _loadingAlts = false);
    }
  }

  Future<void> _shareApp(HubStrings s) async {
    final installed =
        widget.installed ?? widget.hub.findInstalled(widget.packageName);
    final title = _unified.displayTitle != widget.packageName
        ? _unified.displayTitle
        : (installed?.label ?? widget.packageName);
    final buf = StringBuffer()
      ..writeln('📱 $title (${widget.packageName})');
    if (_unified.developer.isNotEmpty) {
      buf.writeln(_unified.developer);
    }
    if (_unified.bestRating > 0) {
      buf.writeln('${s.ratingColumn}: ${_unified.bestRating.toStringAsFixed(1)} ★');
    }
    if (_unified.bestSizeLabel.isNotEmpty) {
      buf.writeln('${s.downloadSize}: ${_unified.bestSizeLabel}');
    }
    for (final l in _unified.listings.values) {
      if (l.storeUrl.isNotEmpty) {
        buf.writeln('${l.store.label(fa: s.isFa)}: ${l.storeUrl}');
      }
    }
    await widget.hub.platform.shareText(buf.toString(), subject: title);
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final installed =
        widget.installed ?? widget.hub.findInstalled(widget.packageName);
    final hasUpdate =
        widget.hub.updateAvailablePackages.contains(widget.packageName);
    final title = _unified.displayTitle != widget.packageName
        ? _unified.displayTitle
        : (installed?.label ?? widget.packageName);

    final cats = installed != null
        ? widget.hub.categoriesForApp(installed)
        : (widget.hub.repo.appCategories[widget.packageName] ??
              const <String>{});
    final catMap = {for (final c in widget.hub.repo.categories) c.id: c};

    final reqSdk = _unified.minSdkRequired ?? installed?.minSdk;
    final isCompatible = reqSdk == null || widget.hub.device.sdkInt >= reqSdk;
    final reqLabel = _unified.minAndroidLabel.isNotEmpty
        ? _unified.minAndroidLabel
        : (reqSdk != null ? 'Android ${sdkToAndroidVersion(reqSdk)}+' : '');

    final screenshots = _unified.allScreenshots;
    final perms = installed != null
        ? installed.permissions
        : _unified.allPermissions;
    final grantedSet = installed?.grantedPermissions.toSet() ?? const <String>{};

    return IceDragonBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.appProfile),
          actions: [
            IconButton(
              tooltip: s.compare,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppComparePage(
                    hub: widget.hub,
                    initialA: CompareTarget(
                      packageName: widget.packageName,
                      installed: installed,
                      unified: _unified,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.compare_arrows_rounded),
            ),
            IconButton(
              tooltip: s.shareAppSummary,
              onPressed: () => _shareApp(s),
              icon: const Icon(Icons.share_rounded),
            ),
          ],
        ),
        body: ListenableBuilder(
        listenable: widget.hub,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // Header card
            GlassCard(
              dark: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIconBadge(
                        iconFuture: installed != null
                            ? widget.hub.iconFor(installed.package)
                            : null,
                        iconUrl: _unified.iconUrl,
                        size: 64,
                        hasUpdate: hasUpdate,
                        updateTooltip: s.updateAvailableBadge,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_unified.developer.isNotEmpty)
                              Text(
                                _unified.developer,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              widget.packageName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Category chips (multi-category + editable)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final cid in cats)
                        if (catMap[cid] case final cat?)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: CircleAvatar(
                              backgroundColor: Color(cat.colorValue),
                              radius: 8,
                            ),
                            label: Text(cat.label(fa: s.isFa)),
                          ),
                      if (_unified.category.isNotEmpty && cats.isEmpty)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(_unified.category),
                        ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.edit_outlined, size: 15),
                        label: Text(s.categories),
                        onPressed: () => showAssignCategoriesSheet(
                          context,
                          widget.hub,
                          [widget.packageName],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (installed != null && installed.launcher)
                        FilledButton.icon(
                          onPressed: () =>
                              boostAndLaunchApp(context, widget.hub, installed),
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: Text(s.boostAndLaunch),
                        ),
                      if (installed != null) ...[
                        FilledButton.tonalIcon(
                          onPressed: () => widget.hub.platform.openAppSettings(
                            installed.package,
                          ),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: Text(s.appSettings),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final removed = await widget.hub.platform
                                .uninstallApp(installed.package);
                            if (!context.mounted) return;
                            if (removed) {
                              await widget.hub.refreshInstalledApps();
                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            } else {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(s.uninstallCanceled),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(s.uninstall),
                        ),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => showAddToCollectionSheet(
                          context,
                          widget.hub,
                          [
                            CollectionAppEntry(
                              packageName: widget.packageName,
                              title: title,
                              iconUrl: _unified.iconUrl,
                              storeUrl: _unified.primary?.storeUrl ?? '',
                            ),
                          ],
                        ),
                        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                        label: Text(s.addToCollection),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Compatibility banner (#16)
            if (reqLabel.isNotEmpty)
              GlassCard(
                dark: dark,
                borderColor: (isCompatible
                        ? DarkGlassPalette.mint
                        : DarkGlassPalette.coral)
                    .withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Icon(
                      isCompatible
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded,
                      color: isCompatible
                          ? DarkGlassPalette.mint
                          : DarkGlassPalette.coral,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCompatible
                            ? s.compatibleDetail(
                                widget.hub.device.androidRelease,
                                reqLabel,
                              )
                            : s.incompatibleDetail(
                                widget.hub.device.androidRelease,
                                reqLabel,
                              ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (reqLabel.isNotEmpty) const SizedBox(height: 12),

            // Quick metrics grid (Version, Size, Updated, Rating)
            GlassCard(
              dark: dark,
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _StatPill(
                    label: s.version,
                    value: installed != null && installed.versionName.isNotEmpty
                        ? installed.versionName
                        : (_unified.primary?.versionName.isNotEmpty == true
                              ? _unified.primary!.versionName
                              : s.unknown),
                  ),
                  _StatPill(
                    label: installed != null ? s.installedSize : s.downloadSize,
                    value: installed != null && installed.totalBytes > 0
                        ? formatStorageBytes(installed.totalBytes)
                        : (_unified.bestSizeLabel.isNotEmpty
                              ? _unified.bestSizeLabel
                              : s.unknown),
                  ),
                  if (_unified.primary?.lastUpdatedLabel.isNotEmpty == true)
                    _StatPill(
                      label: s.lastUpdated,
                      value: _unified.primary!.lastUpdatedLabel,
                    ),
                  if (_unified.bestRating > 0)
                    _StatPill(
                      label: s.ratingColumn,
                      value: '${_unified.bestRating.toStringAsFixed(1)} ★',
                    ),
                  if (installed != null && installed.cacheBytes > 0)
                    _StatPill(
                      label: 'Cache',
                      value: formatStorageBytes(installed.cacheBytes),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Screenshots (#11)
            if (screenshots.isNotEmpty) ...[
              _SectionHeading(title: s.screenshots),
              const SizedBox(height: 8),
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: screenshots.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      screenshots[i],
                      height: 210,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Offering stores (#10 & #11)
            _SectionHeading(
              title: s.offeringStores,
              trailing: _loadingStore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            if (_unified.listings.isEmpty && !_loadingStore)
              GlassCard(
                dark: dark,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final store in [
                      StoreId.googlePlay,
                      StoreId.bazaar,
                      StoreId.myket,
                    ])
                      OutlinedButton(
                        onPressed: () => widget.hub.platform.openStore(
                          widget.packageName,
                          store.key,
                          fallbackUrl: switch (store) {
                            StoreId.googlePlay =>
                              'https://play.google.com/store/apps/details?id=${Uri.encodeComponent(widget.packageName)}',
                            StoreId.bazaar =>
                              'https://cafebazaar.ir/app/${Uri.encodeComponent(widget.packageName)}',
                            StoreId.myket =>
                              'https://myket.ir/app/${Uri.encodeComponent(widget.packageName)}',
                            StoreId.fdroid =>
                              'https://f-droid.org/packages/${Uri.encodeComponent(widget.packageName)}/',
                          },
                        ),
                        child: Text(store.label(fa: s.isFa)),
                      ),
                  ],
                ),
              )
            else
              for (final listing in _unified.listings.values) ...[
                GlassCard(
                  dark: dark,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StoreChip(store: listing.store, fa: s.isFa),
                                const SizedBox(width: 8),
                                Text(
                                  !listing.isPriceKnown
                                      ? s.unknown
                                      : (listing.isFree
                                            ? s.free
                                            : listing.priceLabel),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: !listing.isPriceKnown
                                        ? theme.colorScheme.onSurfaceVariant
                                        : (listing.isFree
                                              ? DarkGlassPalette.mint
                                              : DarkGlassPalette.amber),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (listing.versionName.isNotEmpty)
                                  '${s.version}: ${listing.versionName}',
                                if (listing.sizeLabel.isNotEmpty)
                                  listing.sizeLabel,
                                if (listing.minAndroidLabel.isNotEmpty)
                                  listing.minAndroidLabel,
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () => widget.hub.platform.openStore(
                          widget.packageName,
                          listing.store.key,
                          fallbackUrl: listing.storeUrl,
                        ),
                        child: Text(installed != null ? s.update : s.install),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

            // Smart Free Alternatives (#16)
            if (_unified.hasPaidListing ||
                !_unified.isFreeAnywhere ||
                _alternatives.isNotEmpty) ...[
              const SizedBox(height: 6),
              _SectionHeading(
                title: s.smartAlternativeTitle,
                trailing: _loadingAlts
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              for (final alt in _alternatives)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    dark: dark,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AppProfilePage(
                          hub: widget.hub,
                          packageName: alt.packageName,
                          initialUnified: alt,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        AppIconBadge(iconUrl: alt.iconUrl, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alt.displayTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${s.free} · ${alt.bestSizeLabel}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: DarkGlassPalette.mint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
            ] else if (_unified.listings.isNotEmpty) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _loadingAlts ? null : _loadAlternatives,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(s.smartAlternativeTitle),
                ),
              ),
            ],

            // Description & What's new (#11)
            if (_unified.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionHeading(title: s.descriptionAndFeatures),
              const SizedBox(height: 8),
              GlassCard(
                dark: dark,
                child: SelectableText(
                  _unified.description,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
            if (_unified.primary?.changelog.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _SectionHeading(title: s.whatsNew),
              const SizedBox(height: 8),
              GlassCard(
                dark: dark,
                child: Text(
                  _unified.primary!.changelog,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],

            // Permissions (#11 & #12)
            const SizedBox(height: 14),
            _SectionHeading(
              title: '${s.permissions} (${perms.length})',
              trailing: installed != null
                  ? TextButton(
                      onPressed: () =>
                          widget.hub.platform.openAppSettings(installed.package),
                      child: Text(s.reviewPermissions),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            GlassCard(
              dark: dark,
              child: perms.isEmpty
                  ? Text(s.noPermissions, style: theme.textTheme.bodyMedium)
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in perms)
                          _PermissionChip(
                            label: friendlyPermissionName(p, fa: s.isFa),
                            sensitive:
                                sensitivePermissionPrefixes.containsKey(p),
                            granted: grantedSet.contains(p),
                            s: s,
                          ),
                      ],
                    ),
            ),

            // Version history (#11 & #16)
            const SizedBox(height: 14),
            _SectionHeading(
              title: s.versionHistory,
              trailing: _loadingHistory
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            GlassCard(
              dark: dark,
              child: _history.isEmpty
                  ? Text(s.noVersionHistory, style: theme.textTheme.bodySmall)
                  : Column(
                      children: [
                        for (var i = 0; i < _history.length; i++) ...[
                          if (i > 0) const Divider(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'v${_history[i].versionName}'
                                  '${_history[i].versionCode > 0 ? ' (${_history[i].versionCode})' : ''}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                [
                                  _history[i].source,
                                  if (_history[i].dateLabel.isNotEmpty)
                                    _history[i].dateLabel,
                                  if (_history[i].sizeLabel.isNotEmpty)
                                    _history[i].sizeLabel,
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),

            // Similar Apps (#11)
            if (_similarResolved.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionHeading(title: s.similarApps),
              const SizedBox(height: 8),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _similarResolved.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final sim = _similarResolved[i];
                    return SizedBox(
                      width: 112,
                      child: GlassCard(
                        dark: dark,
                        padding: const EdgeInsets.all(10),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AppProfilePage(
                              hub: widget.hub,
                              packageName: sim.packageName,
                              initialUnified: sim,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppIconBadge(iconUrl: sim.iconUrl, size: 46),
                            const SizedBox(height: 8),
                            Text(
                              sim.displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      ?trailing,
    ],
  );
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({
    required this.label,
    required this.sensitive,
    required this.granted,
    required this.s,
  });

  final String label;
  final bool sensitive;
  final bool granted;
  final HubStrings s;

  @override
  Widget build(BuildContext context) {
    final color = sensitive
        ? (granted ? DarkGlassPalette.amber : DarkGlassPalette.coral)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        sensitive
            ? '$label · ${granted ? s.granted : s.notGranted}'
            : label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: sensitive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
