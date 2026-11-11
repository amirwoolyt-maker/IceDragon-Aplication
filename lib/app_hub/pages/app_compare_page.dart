import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';
import 'hub_widgets.dart';

/// Bundle pairing optional local [installed] stats and [unified] store data
/// for comparison in [AppComparePage].
class CompareTarget {
  const CompareTarget({
    required this.packageName,
    this.installed,
    this.unified,
  });

  final String packageName;
  final InstalledAppDetail? installed;
  final UnifiedAppResult? unified;

  String get title =>
      unified?.displayTitle ?? installed?.label ?? packageName;

  String get sizeText {
    if (installed != null && installed!.totalBytes > 0) {
      return formatStorageBytes(installed!.totalBytes);
    }
    final s = unified?.bestSizeLabel ?? '';
    return s;
  }

  int get sizeNumeric {
    if (installed != null && installed!.totalBytes > 0) {
      return installed!.totalBytes;
    }
    return unified?.smallestSizeBytes ?? 0;
  }

  String priceText(HubStrings s) {
    final u = unified;
    if (u == null || u.listings.isEmpty || !u.hasKnownPrice) {
      return s.unknown;
    }
    return u.isFreeAnywhere ? s.free : (u.primary?.priceLabel ?? s.paid);
  }

  String storesText(HubStrings s) {
    final u = unified;
    if (u != null && u.listings.isNotEmpty) {
      return [
        for (final st in u.listings.keys) st.label(fa: s.isFa),
      ].join(' · ');
    }
    final inst = installed?.installerStore;
    if (inst != null) return inst.label(fa: s.isFa);
    return s.unknown;
  }

  int get permissionsCount {
    if (installed != null) return installed!.permissions.length;
    return unified?.allPermissions.length ?? 0;
  }

  int get sensitiveCount => installed?.sensitivePermissions.length ?? 0;

  String get versionText {
    final v = installed?.versionName ?? '';
    if (v.isNotEmpty) return v;
    return unified?.primary?.versionName ?? '';
  }

  String get minAndroidText {
    final u = unified?.minAndroidLabel ?? '';
    if (u.isNotEmpty) return u;
    if (installed != null && installed!.minSdk > 0) {
      return formatMinAndroidFromSdk(installed!.minSdk);
    }
    return '';
  }

  String get ratingText {
    final r = unified?.bestRating ?? 0;
    return r > 0 ? '${r.toStringAsFixed(1)} ★' : '—';
  }
}

/// Side-by-side real comparison screen for two apps (#13).
class AppComparePage extends StatefulWidget {
  const AppComparePage({
    super.key,
    required this.hub,
    required this.initialA,
    this.initialB,
  });

  final HubController hub;
  final CompareTarget initialA;
  final CompareTarget? initialB;

  @override
  State<AppComparePage> createState() => _AppComparePageState();
}

class _AppComparePageState extends State<AppComparePage> {
  late CompareTarget _a = widget.initialA;
  CompareTarget? _b;
  bool _loadingA = false;
  bool _loadingB = false;
  bool _startedEnrich = false;

  @override
  void initState() {
    super.initState();
    _b = widget.initialB;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedEnrich) return;
    _startedEnrich = true;
    final hl = HubStrings.of(context).isFa ? 'fa' : 'en';
    Future<void>.microtask(() {
      if (!mounted) return;
      _enrich(_a, isA: true, hl: hl);
      if (_b != null) _enrich(_b!, isA: false, hl: hl);
    });
  }

  Future<void> _enrich(
    CompareTarget t, {
    required bool isA,
    String? hl,
  }) async {
    if (t.unified != null && t.unified!.listings.isNotEmpty) return;
    final lang = hl ?? (HubStrings.of(context).isFa ? 'fa' : 'en');
    if (!mounted) return;
    setState(() {
      if (isA) {
        _loadingA = true;
      } else {
        _loadingB = true;
      }
    });
    try {
      final unified = await widget.hub.stores.fetchUnifiedApp(
        t.packageName,
        hl: lang,
        proxyAddress: widget.hub.activeProxyAddress,
      );
      if (!mounted) return;
      final next = CompareTarget(
        packageName: t.packageName,
        installed: t.installed ?? widget.hub.findInstalled(t.packageName),
        unified: unified,
      );
      setState(() {
        if (isA) {
          _a = next;
        } else {
          _b = next;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          if (isA) {
            _loadingA = false;
          } else {
            _loadingB = false;
          }
        });
      }
    }
  }

  Future<void> _pickApp({required bool isA}) async {
    final s = HubStrings.of(context);
    final apps = widget.hub.installedApps.where((a) => !a.system).toList();
    final picked = await showModalBottomSheet<InstalledAppDetail>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, ctrl) => ListView.builder(
          controller: ctrl,
          itemCount: apps.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isA ? s.selectAppA : s.selectAppB,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }
            final app = apps[i - 1];
            return ListTile(
              leading: AppIconBadge(
                iconFuture: widget.hub.iconFor(app.package),
                size: 38,
              ),
              title: Text(app.label),
              subtitle: Text(
                '${app.versionName} · ${formatStorageBytes(app.totalBytes)}',
              ),
              onTap: () => Navigator.of(ctx).pop(app),
            );
          },
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final next = CompareTarget(packageName: picked.package, installed: picked);
    setState(() {
      if (isA) {
        _a = next;
      } else {
        _b = next;
      }
    });
    await _enrich(next, isA: isA);
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final b = _b;

    return Scaffold(
      appBar: AppBar(title: Text(s.compareTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _HeaderSlot(
                  hub: widget.hub,
                  target: _a,
                  loading: _loadingA,
                  label: s.selectAppA,
                  onPick: () => _pickApp(isA: true),
                  dark: dark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: b == null
                    ? GlassCard(
                        dark: dark,
                        onTap: () => _pickApp(isA: false),
                        child: SizedBox(
                          height: 92,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  s.selectAppB,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _HeaderSlot(
                        hub: widget.hub,
                        target: b,
                        loading: _loadingB,
                        label: s.selectAppB,
                        onPick: () => _pickApp(isA: false),
                        dark: dark,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (b != null)
            GlassCard(
              dark: dark,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _CompareRow(
                    feature: s.downloadSize,
                    valA: _a.sizeText.isEmpty ? s.unknown : _a.sizeText,
                    valB: b.sizeText.isEmpty ? s.unknown : b.sizeText,
                    winner: _smallerWinner(_a.sizeNumeric, b.sizeNumeric),
                  ),
                  const Divider(height: 1),
                  _CompareRow(
                    feature: s.price,
                    valA: _a.priceText(s),
                    valB: b.priceText(s),
                  ),
                  const Divider(height: 1),
                  _CompareRow(
                    feature: s.storeColumn,
                    valA: _a.storesText(s),
                    valB: b.storesText(s),
                  ),
                  const Divider(height: 1),
                  _CompareRow(
                    feature: s.permissionsColumn,
                    valA: _permLabel(s, _a),
                    valB: _permLabel(s, b),
                    winner: _smallerWinner(
                      _a.permissionsCount,
                      b.permissionsCount,
                    ),
                  ),
                  const Divider(height: 1),
                  _CompareRow(
                    feature: s.version,
                    valA: _a.versionText.isEmpty ? s.unknown : _a.versionText,
                    valB: b.versionText.isEmpty ? s.unknown : b.versionText,
                  ),
                  const Divider(height: 1),
                  _CompareRow(
                    feature: s.minAndroidColumn,
                    valA: _a.minAndroidText.isEmpty ? s.unknown : _a.minAndroidText,
                    valB: b.minAndroidText.isEmpty ? s.unknown : b.minAndroidText,
                  ),
                  const Divider(height: 1),
                  _CompareRow(
                    feature: s.ratingColumn,
                    valA: _a.ratingText,
                    valB: b.ratingText,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _permLabel(HubStrings s, CompareTarget t) {
    if (t.permissionsCount == 0) {
      return t.installed == null ? s.unknown : '0';
    }
    return t.sensitiveCount > 0
        ? '${t.permissionsCount} (${t.sensitiveCount} ${s.sensitivePermissions})'
        : '${t.permissionsCount}';
  }

  /// Returns `-1` when A is strictly better (smaller > 0), `1` when B is better,
  /// `0` for tie/unknown.
  static int _smallerWinner(int a, int b) {
    if (a <= 0 || b <= 0 || a == b) return 0;
    return a < b ? -1 : 1;
  }
}

class _HeaderSlot extends StatelessWidget {
  const _HeaderSlot({
    required this.hub,
    required this.target,
    required this.loading,
    required this.label,
    required this.onPick,
    required this.dark,
  });

  final HubController hub;
  final CompareTarget target;
  final bool loading;
  final String label;
  final VoidCallback onPick;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      dark: dark,
      onTap: onPick,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          AppIconBadge(
            iconFuture: target.installed != null
                ? hub.iconFor(target.packageName)
                : null,
            iconUrl: target.unified?.iconUrl ?? '',
            size: 46,
          ),
          const SizedBox(height: 8),
          Text(
            target.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            loading ? '...' : target.packageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.feature,
    required this.valA,
    required this.valB,
    this.winner = 0,
  });

  final String feature;
  final String valA;
  final String valB;
  final int winner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              valA,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: winner == -1 ? FontWeight.w800 : FontWeight.w500,
                color: winner == -1 ? DarkGlassPalette.mint : null,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              valB,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: winner == 1 ? FontWeight.w800 : FontWeight.w500,
                color: winner == 1 ? DarkGlassPalette.mint : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
