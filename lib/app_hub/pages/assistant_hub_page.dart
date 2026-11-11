import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';
import 'app_compare_page.dart';
import 'app_profile_page.dart';
import 'hub_widgets.dart';

enum _AssistantSubTab { doctor, updates, collections, ai }

/// Assistant Hub containing:
/// 1) Phone Management Assistant (#12 & Duplicate Finder #16)
/// 2) Central Update Center (#15)
/// 3) Personal App Collections (#14)
/// 4) App Intelligence AI (#16)
class AssistantHubPage extends StatefulWidget {
  const AssistantHubPage({super.key, required this.hub});

  final HubController hub;

  @override
  State<AssistantHubPage> createState() => _AssistantHubPageState();
}

class _AssistantHubPageState extends State<AssistantHubPage> {
  _AssistantSubTab _subTab = _AssistantSubTab.doctor;
  final _aiCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await widget.hub.ensureLoaded();
      if (mounted && widget.hub.assistantReport == null) {
        await widget.hub.runDiagnostics();
      }
    });
  }

  @override
  void dispose() {
    _aiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.hub,
      builder: (context, _) {
        final hub = widget.hub;
        return Scaffold(
          appBar: AppBar(title: Text(s.navAssistant)),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_AssistantSubTab>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: _AssistantSubTab.doctor,
                        label: Text(s.assistantTab),
                      ),
                      ButtonSegment(
                        value: _AssistantSubTab.updates,
                        label: Text(
                          hub.availableUpdates.isNotEmpty
                              ? '${s.updatesTab} (${hub.availableUpdates.length})'
                              : s.updatesTab,
                        ),
                      ),
                      ButtonSegment(
                        value: _AssistantSubTab.collections,
                        label: Text(s.collectionsTab),
                      ),
                      ButtonSegment(
                        value: _AssistantSubTab.ai,
                        label: Text(s.aiTab),
                      ),
                    ],
                    selected: {_subTab},
                    onSelectionChanged: (v) => setState(() => _subTab = v.first),
                  ),
                ),
              ),
              Expanded(
                child: switch (_subTab) {
                  _AssistantSubTab.doctor => _DoctorView(hub: hub, s: s),
                  _AssistantSubTab.updates => _UpdatesView(hub: hub, s: s),
                  _AssistantSubTab.collections =>
                    _CollectionsView(hub: hub, s: s),
                  _AssistantSubTab.ai => _AiView(
                    hub: hub,
                    s: s,
                    controller: _aiCtrl,
                    theme: theme,
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DoctorView extends StatelessWidget {
  const _DoctorView({required this.hub, required this.s});

  final HubController hub;
  final HubStrings s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final dev = hub.device;
    final report = hub.assistantReport;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GlassCard(
          dark: dark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_android_rounded, color: DarkGlassPalette.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${s.deviceOverview} · ${dev.model}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => hub.runDiagnostics(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(s.runDiagnostics),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _MiniMetric(
                    label: s.androidVersion,
                    value: '${dev.androidRelease} (API ${dev.sdkInt})',
                  ),
                  if (dev.freeStorageBytes > 0)
                    _MiniMetric(
                      label: s.freeStorage,
                      value: formatStorageBytes(dev.freeStorageBytes),
                    ),
                  if (dev.availRamBytes > 0)
                    _MiniMetric(
                      label: s.freeRam,
                      value: formatStorageBytes(dev.availRamBytes),
                    ),
                ],
              ),
              if (!dev.hasUsageAccess) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DarkGlassPalette.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DarkGlassPalette.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: DarkGlassPalette.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.usageAccessMissing,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => hub.platform.openUsageAccessSettings(),
                        child: Text(s.grantUsageAccess),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (report != null) ...[
          // Free space recommendations
          GlassCard(
            dark: dark,
            borderColor: DarkGlassPalette.mint.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cleaning_services_rounded,
                      color: DarkGlassPalette.mint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.spaceTipsTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.reclaimableSpace(
                    formatStorageBytes(report.potentialReclaimBytes),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: DarkGlassPalette.mint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.speedBoostHonestNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Large apps
          if (report.largeApps.isNotEmpty) ...[
            Text(
              '${s.largeAppsTitle} (${report.largeApps.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final app in report.largeApps.take(6)) ...[
              GlassCard(
                dark: dark,
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppProfilePage(
                      hub: hub,
                      packageName: app.package,
                      installed: app,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    AppIconBadge(
                      iconFuture: hub.iconFor(app.package),
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${formatStorageBytes(app.totalBytes)}'
                            '${app.cacheBytes > 0 ? ' (Cache ${formatStorageBytes(app.cacheBytes)})' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: DarkGlassPalette.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          hub.platform.openAppSettings(app.package),
                      child: Text(s.openAndroidStorage),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          // Duplicate / Similar Function Finder (#12 & #16)
          if (report.duplicateGroups.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${s.duplicateAppsTitle} (${report.duplicateGroups.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final grp in report.duplicateGroups) ...[
              GlassCard(
                dark: dark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${grp.label(fa: s.isFa)} (${grp.apps.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (grp.apps.length >= 2)
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AppComparePage(
                                  hub: hub,
                                  initialA: CompareTarget(
                                    packageName: grp.apps[0].package,
                                    installed: grp.apps[0],
                                  ),
                                  initialB: CompareTarget(
                                    packageName: grp.apps[1].package,
                                    installed: grp.apps[1],
                                  ),
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.compare_arrows_rounded,
                              size: 16,
                            ),
                            label: Text(s.compare),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final a in grp.apps)
                          ActionChip(
                            label: Text(
                              '${a.label} (${formatStorageBytes(a.totalBytes)})',
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AppProfilePage(
                                  hub: hub,
                                  packageName: a.package,
                                  installed: a,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          // Unnecessary Permissions Auditor (#12)
          if (report.permissionAudits.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${s.riskyPermsTitle} (${report.permissionAudits.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in report.permissionAudits.take(6)) ...[
              GlassCard(
                dark: dark,
                child: Row(
                  children: [
                    AppIconBadge(
                      iconFuture: hub.iconFor(item.app.package),
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.app.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              for (final p in item.flaggedPermissions.take(4))
                                friendlyPermissionName(p, fa: s.isFa),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: DarkGlassPalette.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          hub.platform.openAppSettings(item.app.package),
                      child: Text(s.reviewPermissions),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          // Outdated / Stale apps
          if (report.staleApps.isNotEmpty || report.outdatedApps.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              s.outdatedAppsTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final u in report.outdatedApps) ...[
              GlassCard(
                dark: dark,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppProfilePage(
                      hub: hub,
                      packageName: u.app.package,
                      installed: u.app,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${u.app.label}: v${u.app.versionName} → v${u.listing.versionName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    StoreChip(
                      store: u.listing.store,
                      fa: s.isFa,
                      compact: true,
                      onTap: () => hub.platform.openStore(
                        u.app.package,
                        u.listing.store.key,
                        fallbackUrl: u.listing.storeUrl,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (final a in report.staleApps.take(5)) ...[
              GlassCard(
                dark: dark,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppProfilePage(
                      hub: hub,
                      packageName: a.package,
                      installed: a,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(a.label)),
                    Text(
                      '${a.ageDays()}d',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: DarkGlassPalette.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }
}

class _UpdatesView extends StatelessWidget {
  const _UpdatesView({required this.hub, required this.s});

  final HubController hub;
  final HubStrings s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final updates = hub.availableUpdates;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GlassCard(
          dark: dark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.system_update_rounded,
                    color: DarkGlassPalette.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.updatesTab,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: hub.scanningUpdates
                        ? null
                        : () => hub.scanUpdates(hl: s.isFa ? 'fa' : 'en'),
                    icon: const Icon(Icons.radar_rounded, size: 18),
                    label: Text(s.checkAllUpdates),
                  ),
                ],
              ),
              if (hub.scanningUpdates) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: hub.scanTotal > 0 ? hub.scanDone / hub.scanTotal : null,
                ),
                const SizedBox(height: 6),
                Text(
                  '${s.scanningUpdates} (${hub.scanDone}/${hub.scanTotal})',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (updates.isEmpty && !hub.scanningUpdates)
          GlassCard(
            dark: dark,
            child: Text(
              hub.repo.updateCache.isEmpty ? s.noUpdatesYet : s.allUpToDate,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final u in updates) ...[
            GlassCard(
              dark: dark,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppProfilePage(
                    hub: hub,
                    packageName: u.app.package,
                    installed: u.app,
                  ),
                ),
              ),
              child: Row(
                children: [
                  AppIconBadge(
                    iconFuture: hub.iconFor(u.app.package),
                    size: 46,
                    hasUpdate: true,
                    updateTooltip: s.updateAvailableBadge,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.app.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'v${u.app.versionName} → v${u.listing.versionName}'
                          '${u.listing.sizeLabel.isNotEmpty ? ' · ${u.listing.sizeLabel}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: DarkGlassPalette.amber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => hub.platform.openStore(
                      u.app.package,
                      u.listing.store.key,
                      fallbackUrl: u.listing.storeUrl,
                    ),
                    child: Text(u.listing.store.label(fa: s.isFa)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _CollectionsView extends StatelessWidget {
  const _CollectionsView({required this.hub, required this.s});

  final HubController hub;
  final HubStrings s;

  Future<void> _showNewCollection(BuildContext context) =>
      showNewCollectionDialog(context, hub: hub, showDescription: true);

  Future<void> _showImportDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _ImportCollectionDialog(hub: hub, s: s),
  );

  void _openCollectionDetail(BuildContext context, AppCollection col) {
    final nav = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final current = hub.repo.collections.firstWhere(
            (c) => c.id == col.id,
            orElse: () => col,
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          current.label(fa: s.isFa),
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: s.shareCollection,
                        onPressed: () => hub.platform.shareText(
                          current.toShareText(fa: s.isFa),
                          subject: current.label(fa: s.isFa),
                        ),
                        icon: const Icon(Icons.share_rounded),
                      ),
                    ],
                  ),
                  if (current.description(fa: s.isFa).isNotEmpty)
                    Text(
                      current.description(fa: s.isFa),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  if (current.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        s.emptyCollection,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: current.items.length,
                        itemBuilder: (ctx, i) {
                          final item = current.items[i];
                          final installed = hub.findInstalled(item.packageName);
                          return ListTile(
                            leading: AppIconBadge(
                              iconFuture: installed != null
                                  ? hub.iconFor(installed.package)
                                  : null,
                              iconUrl: item.iconUrl,
                              size: 40,
                            ),
                            title: Text(item.title),
                            subtitle: Text(item.packageName),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () async {
                                await hub.removeFromCollection(
                                  current.id,
                                  item.packageName,
                                );
                                if (ctx.mounted) setState(() {});
                              },
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              nav.push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AppProfilePage(
                                    hub: hub,
                                    packageName: item.packageName,
                                    installed: installed,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _showNewCollection(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.newCollection),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _showImportDialog(context),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(s.importCollection),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final col in hub.repo.collections) ...[
          GlassCard(
            dark: dark,
            onTap: () => _openCollectionDetail(context, col),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.18,
                  ),
                  child: Icon(
                    Icons.collections_bookmark_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        col.label(fa: s.isFa),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (col.description(fa: s.isFa).isNotEmpty)
                        Text(
                          col.description(fa: s.isFa),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${col.items.length}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: DarkGlassPalette.cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: s.shareCollection,
                  onPressed: () => hub.platform.shareText(
                    col.toShareText(fa: s.isFa),
                    subject: col.label(fa: s.isFa),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                ),
                if (!col.isPreset)
                  IconButton(
                    tooltip: s.delete,
                    onPressed: () => hub.deleteCollection(col.id),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AiView extends StatelessWidget {
  const _AiView({
    required this.hub,
    required this.s,
    required this.controller,
    required this.theme,
  });

  final HubController hub;
  final HubStrings s;
  final TextEditingController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    final hasGemini = hub.repo.geminiApiKey.trim().isNotEmpty;
    final res = hub.aiResult;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GlassCard(
          dark: dark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: DarkGlassPalette.mint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasGemini ? s.aiModeGemini : s.aiModeLocal,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: DarkGlassPalette.mint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(s.aiIntro, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: InputDecoration(hintText: s.aiInputHint),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: hub.runningAi
                    ? null
                    : () => hub.runAiRecommendation(
                        controller.text,
                        fa: s.isFa,
                      ),
                icon: hub.runningAi
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_rounded, size: 18),
                label: Text(s.askAi),
              ),
            ],
          ),
        ),
        if (hub.lastError.isNotEmpty) ...[
          const SizedBox(height: 12),
          GlassCard(
            dark: dark,
            borderColor: DarkGlassPalette.coral.withValues(alpha: 0.45),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: DarkGlassPalette.coral,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.aiErrorSummary(hub.lastError),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: DarkGlassPalette.coral,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (res != null) ...[
          const SizedBox(height: 12),
          if (res.summary.isNotEmpty)
            GlassCard(
              dark: dark,
              borderColor: DarkGlassPalette.purple.withValues(alpha: 0.45),
              child: Text(res.summary, style: theme.textTheme.bodyMedium),
            ),
          if (res.apps.isEmpty) ...[
            const SizedBox(height: 10),
            GlassCard(
              dark: dark,
              child: Row(
                children: [
                  const Icon(Icons.search_off_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.aiNoMatches,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final app in res.apps) ...[
            GlassCard(
              dark: dark,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppProfilePage(
                    hub: hub,
                    packageName: app.packageName,
                    installed: hub.findInstalled(app.packageName),
                    initialUnified: app,
                  ),
                ),
              ),
              child: Row(
                children: [
                  AppIconBadge(iconUrl: app.iconUrl, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.displayTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [
                            if (app.bestRating > 0)
                              '${app.bestRating.toStringAsFixed(1)} ★',
                            !app.hasKnownPrice
                                ? s.unknown
                                : (app.isFreeAnywhere ? s.free : s.paid),
                            if (app.bestSizeLabel.isNotEmpty) app.bestSizeLabel,
                            s.availableInStores(app.listings.length),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

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

class _ImportCollectionDialog extends StatefulWidget {
  const _ImportCollectionDialog({required this.hub, required this.s});

  final HubController hub;
  final HubStrings s;

  @override
  State<_ImportCollectionDialog> createState() =>
      _ImportCollectionDialogState();
}

class _ImportCollectionDialogState extends State<_ImportCollectionDialog> {
  final _ctrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.importCollection),
      content: TextField(
        controller: _ctrl,
        maxLines: 4,
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        decoration: InputDecoration(
          hintText: s.importHint,
          errorText: _errorText,
          errorMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await widget.hub.importSharedCollection(_ctrl.text);
            if (!mounted) return;
            if (ok) {
              Navigator.of(context).pop();
            } else {
              setState(() => _errorText = s.importCollectionInvalid);
            }
          },
          child: Text(s.apply),
        ),
      ],
    );
  }
}
