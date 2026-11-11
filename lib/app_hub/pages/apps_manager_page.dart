import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';
import 'app_compare_page.dart';
import 'app_profile_page.dart';
import 'hub_widgets.dart';

/// Installed Apps Manager (#1, #2, #4, #5, #6, #7, #11, #13).
class AppsManagerPage extends StatefulWidget {
  const AppsManagerPage({super.key, required this.hub});

  final HubController hub;

  @override
  State<AppsManagerPage> createState() => _AppsManagerPageState();
}

class _AppsManagerPageState extends State<AppsManagerPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'all';
  bool _showSystem = false;
  bool _updatesOnly = false;
  bool _multiSelect = false;
  final Set<String> _selected = {};

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

  List<InstalledAppDetail> _filteredApps(
    HubController hub,
    HubStrings s,
    Set<String> updatePkgs,
  ) {
    final q = _query.trim().toLowerCase();
    final catMap = {for (final c in hub.repo.categories) c.id: c};
    return [
      for (final app in hub.installedApps)
        if ((_showSystem || !app.system) &&
            (!_updatesOnly || updatePkgs.contains(app.package)) &&
            (_selectedCategory == 'all' ||
                hub.categoriesForApp(app).contains(_selectedCategory)) &&
            (q.isEmpty ||
                app.label.toLowerCase().contains(q) ||
                app.package.toLowerCase().contains(q) ||
                hub.categoriesForApp(app).any((cid) {
                  final cat = catMap[cid];
                  if (cat == null) return false;
                  return cat.nameEn.toLowerCase().contains(q) ||
                      cat.nameFa.toLowerCase().contains(q);
                })))
          app,
    ];
  }

  Future<void> _batchUninstall(
    HubStrings s,
    List<InstalledAppDetail> visible,
  ) async {
    final targets = [
      for (final a in visible)
        if (_selected.contains(a.package) && !a.system) a.package,
    ];
    var removedCount = 0;
    for (final pkg in targets) {
      if (!mounted) return;
      final removed = await widget.hub.platform.uninstallApp(pkg);
      if (removed) removedCount++;
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _multiSelect = false;
    });
    await widget.hub.refreshInstalledApps();
    if (!mounted) return;
    if (targets.isNotEmpty) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            removedCount == 0
                ? s.uninstallCanceled
                : s.uninstallBatchResult(removedCount, targets.length),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _batchVpnBypass(HubStrings s, {required bool bypass}) async {
    final count = _selected.length;
    final ok = await widget.hub.setVpnBypassForPackages(
      _selected,
      bypass: bypass,
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (bypass ? s.addedToBypass : s.removedFromBypass)
              : s.bypassListSavedCount(count, bypass),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: ok
            ? null
            : SnackBarAction(
                label: s.openVpnSettingsLabel,
                onPressed: widget.hub.openVpnSettings,
              ),
      ),
    );
  }

  void _compareSelected(HubStrings s, List<InstalledAppDetail> visible) {
    final chosen = [
      for (final a in visible)
        if (_selected.contains(a.package)) a,
    ];
    if (chosen.length != 2) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(s.pickTwoToCompare),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppComparePage(
          hub: widget.hub,
          initialA: CompareTarget(
            packageName: chosen[0].package,
            installed: chosen[0],
          ),
          initialB: CompareTarget(
            packageName: chosen[1].package,
            installed: chosen[1],
          ),
        ),
      ),
    );
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
        final updatePkgs = hub.updateAvailablePackages;
        final visible = _filteredApps(hub, s, updatePkgs);
        final catMap = {for (final c in hub.repo.categories) c.id: c};

        return IceDragonBackdrop(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                _multiSelect
                    ? s.selectedCount(_selected.length)
                    : '${s.appsTitle} (${visible.length})',
              ),
              actions: [
              IconButton(
                tooltip: s.scanUpdates,
                onPressed: hub.scanningUpdates
                    ? null
                    : () async {
                        final found = await hub.scanUpdates(
                          hl: s.isFa ? 'fa' : 'en',
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text(s.updatesFoundCount(found.length)),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                icon: hub.scanningUpdates
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Badge(
                        isLabelVisible: updatePkgs.isNotEmpty,
                        label: Text('${updatePkgs.length}'),
                        child: const Icon(Icons.system_update_rounded),
                      ),
              ),
              IconButton(
                tooltip: s.autoCategorize,
                onPressed: hub.categorizing
                    ? null
                    : () async {
                        final count = await hub.autoCategorizeFromStores(
                          hl: s.isFa ? 'fa' : 'en',
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(
                            content: Text(s.autoCategorizedDone(count)),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                icon: hub.categorizing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_rounded),
              ),
              IconButton(
                tooltip: s.multiSelect,
                onPressed: () => setState(() {
                  _multiSelect = !_multiSelect;
                  if (!_multiSelect) _selected.clear();
                }),
                icon: Icon(
                  _multiSelect
                      ? Icons.check_box_rounded
                      : Icons.check_box_outlined,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'system') {
                    setState(() => _showSystem = !_showSystem);
                  } else if (value == 'new_cat') {
                    showCreateCategoryDialog(context, hub);
                  } else if (value == 'refresh') {
                    hub.refreshInstalledApps();
                  }
                },
                itemBuilder: (ctx) => [
                  CheckedPopupMenuItem<String>(
                    value: 'system',
                    checked: _showSystem,
                    child: Text(s.systemApps),
                  ),
                  PopupMenuItem<String>(
                    value: 'new_cat',
                    child: Text(s.newCategory),
                  ),
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Text(s.refresh),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Frosted Search & category filter bar
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: GlassCard(
                  dark: dark,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  radius: 22,
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: s.searchAppsHint,
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: ChoiceChip(
                                label: Text(s.all),
                                selected:
                                    _selectedCategory == 'all' && !_updatesOnly,
                                onSelected: (_) => setState(() {
                                  _selectedCategory = 'all';
                                  _updatesOnly = false;
                                }),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: FilterChip(
                                label: Text(
                                  '${s.updatesOnly} (${updatePkgs.length})',
                                ),
                                selected: _updatesOnly,
                                onSelected: (v) =>
                                    setState(() => _updatesOnly = v),
                              ),
                            ),
                            for (final cat in hub.repo.categories)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 6),
                                child: ChoiceChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: Color(cat.colorValue),
                                    radius: 5,
                                  ),
                                  label: Text(cat.label(fa: s.isFa)),
                                  selected: _selectedCategory == cat.id,
                                  onSelected: (_) => setState(() {
                                    _selectedCategory =
                                        _selectedCategory == cat.id
                                            ? 'all'
                                            : cat.id;
                                  }),
                                ),
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 16),
                              label: Text(s.newCategory),
                              onPressed: () =>
                                  showCreateCategoryDialog(context, hub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hub.loadingApps && hub.installedApps.isEmpty)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visible.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      s.noAppsFound,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final app = visible[i];
                      final hasUpdate = updatePkgs.contains(app.package);
                      final isSel = _selected.contains(app.package);
                      final cats = hub.categoriesForApp(app);
                      final catText = [
                        for (final cid in cats.take(3))
                          if (catMap[cid] case final c?) c.label(fa: s.isFa),
                      ].join(' · ');

                      return GlassCard(
                        dark: dark,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        accentColor: isSel
                            ? theme.colorScheme.primary
                            : (hasUpdate ? DarkGlassPalette.amber : null),
                        borderColor: isSel
                            ? theme.colorScheme.primary
                            : null,
                        onTap: () {
                          if (_multiSelect) {
                            setState(() {
                              if (!isSel) {
                                _selected.add(app.package);
                              } else {
                                _selected.remove(app.package);
                              }
                            });
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AppProfilePage(
                                  hub: hub,
                                  packageName: app.package,
                                  installed: app,
                                ),
                              ),
                            );
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () => setState(() {
                            _multiSelect = true;
                            _selected.add(app.package);
                          }),
                          child: Row(
                            children: [
                              if (_multiSelect) ...[
                                Checkbox(
                                  value: isSel,
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(app.package);
                                    } else {
                                      _selected.remove(app.package);
                                    }
                                  }),
                                ),
                              ],
                              AppIconBadge(
                                iconFuture: hub.iconFor(app.package),
                                size: 48,
                                hasUpdate: hasUpdate,
                                updateTooltip: s.updateAvailableBadge,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (app.versionName.isNotEmpty)
                                          IcePillBadge(
                                            text: 'v${app.versionName}',
                                            color: theme.colorScheme.primary,
                                          ),
                                        if (app.totalBytes > 0)
                                          IcePillBadge(
                                            text: formatStorageBytes(
                                              app.totalBytes,
                                            ),
                                            color: DarkGlassPalette.cyan,
                                          ),
                                        if (catText.isNotEmpty)
                                          Text(
                                            catText,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (app.launcher) ...[
                                const SizedBox(width: 4),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: DarkGlassPalette.cyan.withValues(
                                      alpha: dark ? 0.14 : 0.10,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: DarkGlassPalette.cyan.withValues(
                                        alpha: 0.30,
                                      ),
                                    ),
                                  ),
                                  child: IconButton(
                                    tooltip: s.boostAndLaunch,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        boostAndLaunchApp(context, hub, app),
                                    icon: Icon(
                                      Icons.rocket_launch_rounded,
                                      size: 19,
                                      color: dark
                                          ? DarkGlassPalette.cyan
                                          : theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  switch (action) {
                                    case 'settings':
                                      await hub.platform.openAppSettings(
                                        app.package,
                                      );
                                    case 'uninstall':
                                      final removed = await hub.platform
                                          .uninstallApp(app.package);
                                      if (context.mounted) {
                                        if (removed) {
                                          await hub.refreshInstalledApps();
                                        } else {
                                          ScaffoldMessenger.maybeOf(
                                            context,
                                          )?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                s.uninstallCanceled,
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    case 'categories':
                                      await showAssignCategoriesSheet(
                                        context,
                                        hub,
                                        [app.package],
                                      );
                                    case 'collection':
                                      await showAddToCollectionSheet(
                                        context,
                                        hub,
                                        [
                                          CollectionAppEntry(
                                            packageName: app.package,
                                            title: app.label,
                                          ),
                                        ],
                                      );
                                    case 'share':
                                      await hub.platform.shareText(
                                        '${app.label} (${app.package})',
                                        subject: app.label,
                                      );
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'settings',
                                    child: Text(s.appSettings),
                                  ),
                                  PopupMenuItem(
                                    value: 'categories',
                                    child: Text(s.assignCategories),
                                  ),
                                  PopupMenuItem(
                                    value: 'collection',
                                    child: Text(s.addToCollection),
                                  ),
                                  PopupMenuItem(
                                    value: 'share',
                                    child: Text(s.share),
                                  ),
                                  if (!app.system)
                                    PopupMenuItem(
                                      value: 'uninstall',
                                      child: Text(s.uninstall),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _multiSelect && _selected.isNotEmpty
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      border: Border(
                        top: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _selected
                                ..clear()
                                ..addAll(visible.map((e) => e.package));
                            }),
                            child: Text(s.selectAll),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selected.clear()),
                            child: Text(s.clearSelection),
                          ),
                          const SizedBox(width: 6),
                          FilledButton.tonalIcon(
                            onPressed: () => showAssignCategoriesSheet(
                              context,
                              hub,
                              _selected.toList(),
                            ),
                            icon: const Icon(Icons.label_outline, size: 17),
                            label: Text(s.categories),
                          ),
                          const SizedBox(width: 6),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              final map = {
                                for (final a in hub.installedApps) a.package: a,
                              };
                              showAddToCollectionSheet(context, hub, [
                                for (final p in _selected)
                                  CollectionAppEntry(
                                    packageName: p,
                                    title: map[p]?.label ?? p,
                                  ),
                              ]);
                            },
                            icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                            label: Text(s.collectionsTab),
                          ),
                          const SizedBox(width: 6),
                          if (_selected.length == 2) ...[
                            FilledButton.icon(
                              onPressed: () => _compareSelected(s, visible),
                              icon: const Icon(
                                Icons.compare_arrows_rounded,
                                size: 17,
                              ),
                              label: Text(s.compare),
                            ),
                            const SizedBox(width: 6),
                          ],
                          OutlinedButton.icon(
                            onPressed: () =>
                                _batchVpnBypass(s, bypass: true),
                            icon: const Icon(Icons.alt_route_rounded, size: 17),
                            label: Text(s.vpnBypassAdd),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _batchVpnBypass(s, bypass: false),
                            icon: const Icon(Icons.vpn_lock_rounded, size: 17),
                            label: Text(s.vpnBypassRemove),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () => _batchUninstall(s, visible),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                            ),
                            label: Text(s.batchUninstall),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
          ),
        );
      },
    );
  }
}
