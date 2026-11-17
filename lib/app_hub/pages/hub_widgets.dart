import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';

/// Displays an app's icon (from Android PackageManager bytes or store URL)
/// with an optional small update-alert warning badge beside the logo (#7).
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    super.key,
    this.iconFuture,
    this.iconUrl = '',
    this.size = 46,
    this.hasUpdate = false,
    this.updateTooltip = '',
  });

  final Future<Uint8List?>? iconFuture;
  final String iconUrl;
  final double size;
  final bool hasUpdate;
  final String updateTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(size * 0.25);

    Widget coreIcon() {
      if (iconFuture != null) {
        return FutureBuilder<Uint8List?>(
          future: iconFuture,
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes != null && bytes.isNotEmpty) {
              return Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            }
            return _networkOrPlaceholder(theme);
          },
        );
      }
      return _networkOrPlaceholder(theme);
    }

    final dark = theme.brightness == Brightness.dark;
    final clipped = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.square(dimension: size, child: coreIcon()),
      ),
    );

    if (!hasUpdate) return clipped;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        clipped,
        PositionedDirectional(
          top: -4,
          end: -4,
          child: Tooltip(
            message: updateTooltip,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: DarkGlassPalette.amber,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 1.8,
                ),
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                size: 11,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _networkOrPlaceholder(ThemeData theme) {
    if (iconUrl.startsWith('http')) {
      return Image.network(
        iconUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(theme),
      );
    }
    return _fallback(theme);
  }

  Widget _fallback(ThemeData theme) => Container(
    width: size,
    height: size,
    color: theme.colorScheme.primary.withValues(alpha: 0.16),
    child: Icon(
      Icons.android_rounded,
      color: theme.colorScheme.primary,
      size: size * 0.56,
    ),
  );
}

Color storeColor(StoreId store) => switch (store) {
  StoreId.googlePlay => const Color(0xFF00C896),
  StoreId.bazaar => const Color(0xFF28B463),
  StoreId.myket => const Color(0xFF00B4D8),
  StoreId.appStore => const Color(0xFF007AFF),
  StoreId.fdroid => const Color(0xFF3F88C5),
};

/// Compact store badge pill (`Google Play`, `Cafe Bazaar`, `Myket`, `App Store`, `F-Droid`).
class StoreChip extends StatelessWidget {
  const StoreChip({
    super.key,
    required this.store,
    required this.fa,
    this.compact = false,
    this.onTap,
  });

  final StoreId store;
  final bool fa;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = storeColor(store);
    return Material(
      color: c.withValues(alpha: 0.14),
      shape: StadiumBorder(side: BorderSide(color: c.withValues(alpha: 0.45))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 7 : 10,
            vertical: compact ? 3 : 5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (store == StoreId.appStore) ...[
                Icon(Icons.apple, size: compact ? 12 : 14, color: c),
                const SizedBox(width: 4),
              ],
              Text(
                store.label(fa: fa),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 10.5 : 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runs Speed Boost (when enabled) and launches [app] with a cyber-turbine animation (#5).
Future<void> boostAndLaunchApp(
  BuildContext context,
  HubController hub,
  InstalledAppDetail app,
) async {
  if (hub.repo.boostBeforeLaunch) {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => IceSpeedBoostDialog(hub: hub, app: app),
    );
    return;
  }

  final s = HubStrings.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final (launched, _) = await hub.boostAndLaunch(app.package);
  if (!context.mounted) return;
  if (!launched) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(s.appLaunchFailed(app.label)),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  messenger?.showSnackBar(
    SnackBar(
      content: Text(s.appLaunchedPlain(app.label)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Cyber-turbine Speed Boost animation dialog before launching an application.
class IceSpeedBoostDialog extends StatefulWidget {
  const IceSpeedBoostDialog({
    super.key,
    required this.hub,
    required this.app,
  });

  final HubController hub;
  final InstalledAppDetail app;

  @override
  State<IceSpeedBoostDialog> createState() => _IceSpeedBoostDialogState();
}

class _IceSpeedBoostDialogState extends State<IceSpeedBoostDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(() {
        final progress = _animCtrl.value;
        final newStage = progress < 0.35
            ? 0
            : progress < 0.70
                ? 1
                : progress < 0.95
                    ? 2
                    : 3;
        if (newStage != _stage && mounted) {
          setState(() => _stage = newStage);
        }
      });

    unawaited(_executeBoostAndLaunch());
  }

  Future<void> _executeBoostAndLaunch() async {
    _animCtrl.forward();
    // Execute memory trim in parallel with the first half of animation
    await widget.hub.boostAndLaunch(widget.app.package);
    if (!mounted) return;
    if (_animCtrl.isAnimating) {
      await _animCtrl.forward();
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final stageText = switch (_stage) {
      0 => s.speedBoostOptimizingRam,
      1 => s.speedBoostAllocatingCpu,
      2 => s.speedBoostPreparingExecution,
      _ => s.speedBoostLaunchingTarget,
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassCard(
        dark: dark,
        radius: 28,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        accentColor: DarkGlassPalette.cyan,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: DarkGlassPalette.cyan,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  s.speedBoostActiveTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 110,
                    child: CircularProgressIndicator(
                      value: _animCtrl.value,
                      strokeWidth: 4.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation(
                        DarkGlassPalette.cyan,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: _animCtrl.value * 6.28,
                    child: Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: DarkGlassPalette.cyan.withValues(
                            alpha: 0.28 * (1 - _animCtrl.value),
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  AppIconBadge(
                    iconFuture: widget.hub.appIcon(widget.app.package),
                    size: 64,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, _) {
                final percent = (_animCtrl.value * 100).toInt();
                return Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: DarkGlassPalette.cyan,
                    letterSpacing: -0.5,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              widget.app.label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Text(
                stageText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DarkGlassPalette.muted,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating a custom user category (#4).
Future<AppCategory?> showCreateCategoryDialog(
  BuildContext context,
  HubController hub,
) => showDialog<AppCategory>(
  context: context,
  builder: (_) => _CreateCategoryDialog(hub: hub, s: HubStrings.of(context)),
);

/// Dialog for creating a new personal collection (#14).
Future<AppCollection?> showNewCollectionDialog(
  BuildContext context, {
  required HubController hub,
  bool showDescription = false,
}) => showDialog<AppCollection>(
  context: context,
  builder: (_) => _NewCollectionDialog(
    hub: hub,
    s: HubStrings.of(context),
    showDescription: showDescription,
  ),
);

class _CreateCategoryDialog extends StatefulWidget {
  const _CreateCategoryDialog({required this.hub, required this.s});

  final HubController hub;
  final HubStrings s;

  @override
  State<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends State<_CreateCategoryDialog> {
  static const _swatches = [
    0xFF816BFF,
    0xFF00D2FF,
    0xFF00E5A3,
    0xFFFFB547,
    0xFFFF5C7A,
    0xFF56CCF2,
  ];

  final _enCtrl = TextEditingController();
  final _faCtrl = TextEditingController();
  int _selectedColor = 0xFF816BFF;

  @override
  void dispose() {
    _enCtrl.dispose();
    _faCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.newCategory),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _faCtrl,
            decoration: InputDecoration(labelText: s.categoryNameFa),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _enCtrl,
            decoration: InputDecoration(labelText: s.categoryNameEn),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: [
              for (final hex in _swatches)
                InkWell(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == hex
                            ? Colors.white
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (_enCtrl.text.trim().isEmpty && _faCtrl.text.trim().isEmpty) {
              return;
            }
            final created = await widget.hub.createCustomCategory(
              nameEn: _enCtrl.text,
              nameFa: _faCtrl.text,
              colorValue: _selectedColor,
            );
            if (context.mounted) Navigator.of(context).pop(created);
          },
          child: Text(s.create),
        ),
      ],
    );
  }
}

class _NewCollectionDialog extends StatefulWidget {
  const _NewCollectionDialog({
    required this.hub,
    required this.s,
    required this.showDescription,
  });

  final HubController hub;
  final HubStrings s;
  final bool showDescription;

  @override
  State<_NewCollectionDialog> createState() => _NewCollectionDialogState();
}

class _NewCollectionDialogState extends State<_NewCollectionDialog> {
  final _nameCtrl = TextEditingController();
  late final TextEditingController? _descCtrl = widget.showDescription
      ? TextEditingController()
      : null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.newCollection),
      content: widget.showDescription
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: s.collectionName),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(labelText: s.collectionDesc),
                ),
              ],
            )
          : TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: s.collectionName),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty) return;
            final col = await widget.hub.createCollection(
              name: _nameCtrl.text,
              description: _descCtrl?.text ?? '',
            );
            if (context.mounted) Navigator.of(context).pop(col);
          },
          child: Text(s.create),
        ),
      ],
    );
  }
}

/// Bottom sheet to assign one or multiple categories to [packages] (#4).
Future<void> showAssignCategoriesSheet(
  BuildContext context,
  HubController hub,
  List<String> packages,
) async {
  if (packages.isEmpty) return;
  final s = HubStrings.of(context);
  final single = packages.length == 1 ? packages.first : null;
  final selected = <String>{
    if (single != null) ...(hub.repo.appCategories[single] ?? const {}),
  };

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
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
                      s.assignCategories,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final created = await showCreateCategoryDialog(ctx, hub);
                      if (created != null && ctx.mounted) {
                        setState(() => selected.add(created.id));
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.newCategory),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final cat in hub.repo.categories)
                      CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        value: selected.contains(cat.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            selected.add(cat.id);
                          } else {
                            selected.remove(cat.id);
                          }
                        }),
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: Color(cat.colorValue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(cat.label(fa: s.isFa))),
                          ],
                        ),
                        secondary: cat.builtIn
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                onPressed: () async {
                                  await hub.deleteCustomCategory(cat.id);
                                  if (ctx.mounted) {
                                    setState(() => selected.remove(cat.id));
                                  }
                                },
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (single != null) {
                    await hub.setAppCategories(single, selected);
                  } else {
                    for (final catId in selected) {
                      await hub.addAppsToCategory(packages, catId);
                    }
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(s.apply),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Bottom sheet to add one or more [entries] to a personal Collection (#14).
Future<void> showAddToCollectionSheet(
  BuildContext context,
  HubController hub,
  List<CollectionAppEntry> entries,
) async {
  if (entries.isEmpty) return;
  final s = HubStrings.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
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
                    s.addToCollection,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final created = await showNewCollectionDialog(ctx, hub: hub);
                    if (created != null) {
                      for (final e in entries) {
                        await hub.addEntryToCollection(created.id, e);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(s.newCollection),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final col in hub.repo.collections)
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_rounded),
                      title: Text(col.label(fa: s.isFa)),
                      subtitle: Text('${col.items.length}'),
                      onTap: () async {
                        for (final e in entries) {
                          await hub.addEntryToCollection(col.id, e);
                        }
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(col.label(fa: s.isFa)),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

IconData categoryIcon(String key) => switch (key) {
  'sports_esports' => Icons.sports_esports_rounded,
  'school' => Icons.school_rounded,
  'chat' => Icons.forum_rounded,
  'photo_camera' => Icons.photo_camera_rounded,
  'auto_awesome' => Icons.auto_awesome_rounded,
  'work' => Icons.work_outline_rounded,
  'account_balance' => Icons.account_balance_rounded,
  'build' => Icons.build_rounded,
  'map' => Icons.map_rounded,
  'shopping_bag' => Icons.shopping_bag_outlined,
  _ => Icons.label_rounded,
};

/// Compact frosted pill badge for versions, sizes, and status metadata.
class IcePillBadge extends StatelessWidget {
  const IcePillBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final label = Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            if (constraints.hasBoundedWidth) Flexible(child: label) else label,
          ],
        ),
      );
    },
  );
}

/// Consistent section header with a glowing icon chip and optional trailing widget.
class IceSectionTitle extends StatelessWidget {
  const IceSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
