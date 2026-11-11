import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';
import 'app_compare_page.dart';
import 'app_profile_page.dart';
import 'hub_widgets.dart';

/// Unified Multi-Store Smart Search & App Radar across Google Play,
/// Cafe Bazaar, and Myket (#9, #10, #16).
class StoreHubPage extends StatefulWidget {
  const StoreHubPage({super.key, required this.hub});

  final HubController hub;

  @override
  State<StoreHubPage> createState() => _StoreHubPageState();
}

class _StoreHubPageState extends State<StoreHubPage> {
  final _searchCtrl = TextEditingController();
  bool _radarMode = false;
  StoreSortMode _sort = StoreSortMode.relevance;
  bool _freeOnly = false;
  bool _compatibleOnly = false;
  StoreId? _storeFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => widget.hub.ensureLoaded());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searchCtrl.text = trimmed;
    setState(() => _radarMode = false);
    final hl = HubStrings.of(context).isFa ? 'fa' : 'en';
    await widget.hub.searchStores(trimmed, hl: hl);
  }

  List<UnifiedAppResult> _sortedAndFiltered(
    List<UnifiedAppResult> raw,
    DeviceEnvironment device,
  ) {
    final list = [
      for (final item in raw)
        if ((!_freeOnly || item.isFreeAnywhere) &&
            (!_compatibleOnly || item.isCompatibleWith(device)) &&
            (_storeFilter == null || item.listings.containsKey(_storeFilter)))
          item,
    ];

    switch (_sort) {
      case StoreSortMode.relevance:
        break;
      case StoreSortMode.popularity:
        list.sort((a, b) {
          final rc = b.bestRating.compareTo(a.bestRating);
          if (rc != 0) return rc;
          return b.totalRatingCount.compareTo(a.totalRatingCount);
        });
      case StoreSortMode.sizeAsc:
        list.sort((a, b) {
          final sa = a.smallestSizeBytes;
          final sb = b.smallestSizeBytes;
          if (sa == 0 && sb == 0) return 0;
          if (sa == 0) return 1;
          if (sb == 0) return -1;
          return sa.compareTo(sb);
        });
      case StoreSortMode.sizeDesc:
        list.sort(
          (a, b) => b.smallestSizeBytes.compareTo(a.smallestSizeBytes),
        );
      case StoreSortMode.storeCount:
        list.sort((a, b) => b.listings.length.compareTo(a.listings.length));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) {
        final hub = widget.hub;
        final resp = hub.searchResponse;
        final items = _sortedAndFiltered(
          _radarMode ? hub.radarApps : (resp?.results ?? const []),
          hub.device,
        );

        return IceDragonBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(s.storesTitle),
              actions: [
                if (hub.activeProxyAddress != null)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 12),
                    child: IcePillBadge(
                      text: 'VPN',
                      icon: Icons.shield_rounded,
                      color: DarkGlassPalette.mint,
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                  child: GlassCard(
                    dark: dark,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    radius: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: false,
                              label: Text(s.searchTab),
                            ),
                            ButtonSegment(value: true, label: Text(s.radarTab)),
                          ],
                          selected: {_radarMode},
                          onSelectionChanged: (v) {
                            final radar = v.first;
                            setState(() => _radarMode = radar);
                            if (radar &&
                                hub.radarApps.isEmpty &&
                                !hub.loadingRadar) {
                              hub.loadRadar(hl: s.isFa ? 'fa' : 'en');
                            }
                          },
                        ),
                        if (!_radarMode) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _runSearch,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                    ),
                                    hintText: s.smartSearchHint,
                                    suffixIcon: _searchCtrl.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                            onPressed: () =>
                                                setState(_searchCtrl.clear),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: hub.searchingStores
                                    ? null
                                    : () => _runSearch(_searchCtrl.text),
                                child: Text(s.search),
                              ),
                            ],
                          ),
                          if (resp != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final e in resp.storeReachable.entries)
                                  IcePillBadge(
                                    text: e.key.label(fa: s.isFa),
                                    icon: e.value
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded,
                                    color: e.value
                                        ? DarkGlassPalette.mint
                                        : DarkGlassPalette.coral,
                                  ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 8),
                        // Sort & Filter strip (#10)
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 6,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: DropdownButton<StoreSortMode>(
                                      value: _sort,
                                      isDense: true,
                                      items: [
                                        DropdownMenuItem(
                                          value: StoreSortMode.relevance,
                                          child: Text(s.sortRelevance),
                                        ),
                                        DropdownMenuItem(
                                          value: StoreSortMode.popularity,
                                          child: Text(s.sortPopularity),
                                        ),
                                        DropdownMenuItem(
                                          value: StoreSortMode.sizeAsc,
                                          child: Text(s.sortSizeAsc),
                                        ),
                                        DropdownMenuItem(
                                          value: StoreSortMode.sizeDesc,
                                          child: Text(s.sortSizeDesc),
                                        ),
                                        DropdownMenuItem(
                                          value: StoreSortMode.storeCount,
                                          child: Text(s.sortStoreCount),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _sort = v);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 6,
                                ),
                                child: FilterChip(
                                  label: Text(s.filterFreeOnly),
                                  selected: _freeOnly,
                                  onSelected: (v) =>
                                      setState(() => _freeOnly = v),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 6,
                                ),
                                child: FilterChip(
                                  label: Text(s.filterCompatibleOnly),
                                  selected: _compatibleOnly,
                                  onSelected: (v) =>
                                      setState(() => _compatibleOnly = v),
                                ),
                              ),
                              for (final st in [
                                StoreId.googlePlay,
                                StoreId.bazaar,
                                StoreId.myket,
                              ])
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 6,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(st.label(fa: s.isFa)),
                                    selected: _storeFilter == st,
                                    onSelected: (_) => setState(() {
                                      _storeFilter =
                                          _storeFilter == st ? null : st;
                                    }),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (hub.searchingStores || hub.loadingRadar)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(
                          _radarMode ? s.appRadarSubtitle : s.searchingStores,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else if (items.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: GlassCard(
                        dark: dark,
                        accentColor: DarkGlassPalette.cyan,
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    DarkGlassPalette.cyan.withValues(alpha: 0.24),
                                    DarkGlassPalette.purple.withValues(alpha: 0.24),
                                  ],
                                ),
                                border: Border.all(
                                  color: DarkGlassPalette.cyan.withValues(
                                    alpha: 0.36,
                                  ),
                                ),
                              ),
                              child: Icon(
                                _radarMode
                                    ? Icons.radar_rounded
                                    : Icons.travel_explore_rounded,
                                size: 34,
                                color: DarkGlassPalette.cyan,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _radarMode ? s.appRadarSubtitle : s.noStoreResults,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (!_radarMode) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final sample in s.isFa
                                      ? const [
                                          'برنامه ویرایش عکس',
                                          'ادیت ویدئو',
                                          'هوش مصنوعی',
                                        ]
                                      : const [
                                          'photo editor',
                                          'video editor',
                                          'AI assistant',
                                        ])
                                    ActionChip(
                                      label: Text(sample),
                                      onPressed: () => _runSearch(sample),
                                    ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 14),
                              FilledButton.tonal(
                                onPressed: () =>
                                    hub.loadRadar(hl: s.isFa ? 'fa' : 'en'),
                                child: Text(s.refresh),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final app = items[i];
                      final compatible = app.isCompatibleWith(hub.device);
                      final installed = hub.findInstalled(app.packageName);

                      return GlassCard(
                        dark: dark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AppProfilePage(
                              hub: hub,
                              packageName: app.packageName,
                              installed: installed,
                              initialUnified: app,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppIconBadge(
                                  iconUrl: app.iconUrl,
                                  size: 52,
                                  hasUpdate: hub.updateAvailablePackages
                                      .contains(app.packageName),
                                  updateTooltip: s.updateAvailableBadge,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.displayTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      if (app.developer.isNotEmpty)
                                        Text(
                                          app.developer,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                        ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (app.bestRating > 0)
                                            _MetaBadge(
                                              text:
                                                  '${app.bestRating.toStringAsFixed(1)} ★',
                                              color: DarkGlassPalette.amber,
                                            ),
                                          _MetaBadge(
                                            text: !app.hasKnownPrice
                                                ? s.unknown
                                                : (app.isFreeAnywhere
                                                      ? s.free
                                                      : (app.primary?.priceLabel ??
                                                            s.paid)),
                                            color: !app.hasKnownPrice
                                                ? Colors.blueGrey
                                                : (app.isFreeAnywhere
                                                      ? DarkGlassPalette.mint
                                                      : DarkGlassPalette.coral),
                                          ),
                                          if (app.bestSizeLabel.isNotEmpty)
                                            _MetaBadge(
                                              text: app.bestSizeLabel,
                                              color: DarkGlassPalette.cyan,
                                            ),
                                          if (app.minAndroidLabel.isNotEmpty)
                                            _MetaBadge(
                                              text: app.minAndroidLabel,
                                              color: compatible
                                                  ? DarkGlassPalette.mint
                                                  : DarkGlassPalette.coral,
                                            ),
                                          if (installed != null)
                                            _MetaBadge(
                                              text: s.installedBadge,
                                              color: DarkGlassPalette.purple,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: s.compare,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AppComparePage(
                                        hub: hub,
                                        initialA: CompareTarget(
                                          packageName: app.packageName,
                                          installed: installed,
                                          unified: app,
                                        ),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.compare_arrows_rounded,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Side-by-side store offerings inside the ONE unified card (#10)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final l in app.listings.values)
                                  StoreChip(
                                    store: l.store,
                                    fa: s.isFa,
                                    compact: true,
                                    onTap: () => hub.platform.openStore(
                                      app.packageName,
                                      l.store.key,
                                      fallbackUrl: l.storeUrl,
                                    ),
                                  ),
                              ],
                            ),
                            if (app.listings.values.any(
                              (l) =>
                                  l.versionName.isNotEmpty ||
                                  l.sizeLabel.isNotEmpty,
                            )) ...[
                              const SizedBox(height: 6),
                              Text(
                                [
                                  for (final l in app.listings.values)
                                    if (l.versionName.isNotEmpty ||
                                        l.sizeLabel.isNotEmpty)
                                      '${l.store.label(fa: s.isFa)}: '
                                          '${[if (l.versionName.isNotEmpty) 'v${l.versionName}', if (l.sizeLabel.isNotEmpty) l.sizeLabel].join(' · ')}',
                                ].join('  |  '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
