import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';

/// Categories of files manageable inside [StorageCleanerPage].
enum StorageViewCategory { large, videos, photos, documents, audio }

/// High-impact visual Storage Breakdown Chart Card.
///
/// Features a multi-segment colored proportional bar and category cards.
/// Can be tapped to jump directly into [StorageCleanerPage].
class StorageBreakdownChartCard extends StatelessWidget {
  const StorageBreakdownChartCard({
    super.key,
    required this.hub,
    this.compact = false,
  });

  final HubController hub;
  final bool compact;

  static const Color colorPhotos = Color(0xFF38BDF8); // Cyan / Sky
  static const Color colorVideos = Color(0xFFF43F5E); // Rose / Ruby
  static const Color colorApps = Color(0xFFA855F7); // Purple / Violet
  static const Color colorDocs = Color(0xFF10B981); // Emerald / Mint
  static const Color colorAudio = Color(0xFFF59E0B); // Amber / Gold
  static const Color colorOther = Color(0xFF64748B); // Slate
  static const Color colorFree = Color(0xFF06B6D4); // Light Cyan

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final b = hub.storageBreakdown ??
        StorageBreakdown(
          totalBytes: hub.device.totalStorageBytes,
          freeBytes: hub.device.freeStorageBytes,
          appsBytes: hub.installedApps.fold<int>(
            0,
            (sum, a) => sum + a.apkBytes,
          ),
        );

    final total = b.totalBytes > 0 ? b.totalBytes : 1;
    final used = b.usedBytes;
    final usedPct = (b.usedRatio * 100).round();

    return GlassCard(
      dark: dark,
      accentColor: DarkGlassPalette.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: DarkGlassPalette.cyan.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DarkGlassPalette.cyan.withValues(alpha: 0.34),
                  ),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: DarkGlassPalette.cyan,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.storageBreakdownTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${formatStorageBytes(used)} ${s.storageUsedLabel} · ${formatStorageBytes(b.freeBytes)} ${s.categoryFree} ($usedPct%)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StorageCleanerPage(hub: hub),
                  ),
                ),
                icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                label: Text(s.manageStorageAction),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Proportional Multi-Segment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  if (b.videosRatio > 0.005)
                    Expanded(
                      flex: (b.videosBytes * 1000 ~/ total).clamp(1, 1000),
                      child: Container(color: colorVideos),
                    ),
                  if (b.imagesRatio > 0.005)
                    Expanded(
                      flex: (b.imagesBytes * 1000 ~/ total).clamp(1, 1000),
                      child: Container(color: colorPhotos),
                    ),
                  if (b.appsRatio > 0.005)
                    Expanded(
                      flex: (b.appsBytes * 1000 ~/ total).clamp(1, 1000),
                      child: Container(color: colorApps),
                    ),
                  if (b.documentsRatio > 0.005)
                    Expanded(
                      flex: (b.documentsBytes * 1000 ~/ total).clamp(1, 1000),
                      child: Container(color: colorDocs),
                    ),
                  if (b.audioRatio > 0.005)
                    Expanded(
                      flex: (b.audioBytes * 1000 ~/ total).clamp(1, 1000),
                      child: Container(color: colorAudio),
                    ),
                  if (b.otherRatio > 0.005)
                    Expanded(
                      flex: (b.otherBytes * 1000 ~/ total).clamp(1, 1000),
                      child: Container(color: colorOther),
                    ),
                  Expanded(
                    flex: (b.freeBytes * 1000 ~/ total).clamp(1, 1000),
                    child: Container(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Categories Breakdown Legend & Quick Navigation Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegendChip(
                color: colorVideos,
                label: s.categoryVideos,
                bytes: b.videosBytes,
                count: b.videosCount,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StorageCleanerPage(
                      hub: hub,
                      initialCategory: StorageViewCategory.videos,
                    ),
                  ),
                ),
              ),
              _LegendChip(
                color: colorPhotos,
                label: s.categoryPhotos,
                bytes: b.imagesBytes,
                count: b.imagesCount,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StorageCleanerPage(
                      hub: hub,
                      initialCategory: StorageViewCategory.photos,
                    ),
                  ),
                ),
              ),
              _LegendChip(
                color: colorDocs,
                label: s.categoryDocuments,
                bytes: b.documentsBytes,
                count: b.documentsCount,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StorageCleanerPage(
                      hub: hub,
                      initialCategory: StorageViewCategory.documents,
                    ),
                  ),
                ),
              ),
              _LegendChip(
                color: colorApps,
                label: s.categoryApps,
                bytes: b.appsBytes,
                count: hub.installedApps.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StorageCleanerPage(
                      hub: hub,
                      initialCategory: StorageViewCategory.large,
                    ),
                  ),
                ),
              ),
              _LegendChip(
                color: colorAudio,
                label: s.categoryAudio,
                bytes: b.audioBytes,
                count: b.audioCount,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StorageCleanerPage(
                      hub: hub,
                      initialCategory: StorageViewCategory.audio,
                    ),
                  ),
                ),
              ),
              _LegendChip(
                color: colorOther,
                label: s.categoryOther,
                bytes: b.otherBytes,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.bytes,
    this.count,
    this.onTap,
  });

  final Color color;
  final String label;
  final int bytes;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              bytes > 0 ? formatStorageBytes(bytes) : '-',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return content;
  }
}

/// Standalone Full-Featured Media, Large Files & Storage Manager Page.
class StorageCleanerPage extends StatefulWidget {
  const StorageCleanerPage({
    super.key,
    required this.hub,
    this.initialCategory = StorageViewCategory.large,
  });

  final HubController hub;
  final StorageViewCategory initialCategory;

  @override
  State<StorageCleanerPage> createState() => _StorageCleanerPageState();
}

class _StorageCleanerPageState extends State<StorageCleanerPage> {
  late StorageViewCategory _category;
  bool _multiSelect = false;
  final Set<String> _selectedIds = {};
  List<StorageMediaFile> _files = [];
  bool _loading = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    final catStr = switch (_category) {
      StorageViewCategory.large => 'large',
      StorageViewCategory.videos => 'videos',
      StorageViewCategory.photos => 'images',
      StorageViewCategory.documents => 'documents',
      StorageViewCategory.audio => 'audio',
    };

    final result = await widget.hub.fetchMediaFiles(catStr);
    if (!mounted) return;
    setState(() {
      _files = result;
      _selectedIds.clear();
      _loading = false;
    });
  }

  void _toggleSelect(StorageMediaFile file) {
    setState(() {
      if (_selectedIds.contains(file.id)) {
        _selectedIds.remove(file.id);
      } else {
        _selectedIds.add(file.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_files.map((f) => f.id));
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  List<StorageMediaFile> get _selectedFiles =>
      _files.where((f) => _selectedIds.contains(f.id)).toList();

  Future<void> _deleteSelected() async {
    final targets = _selectedFiles;
    if (targets.isEmpty) return;

    final s = HubStrings.of(context);
    final totalSize = targets.fold<int>(0, (sum, f) => sum + f.sizeBytes);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteSelectedAction),
        content: Text(
          s.confirmDeleteCount(targets.length, formatStorageBytes(totalSize)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DarkGlassPalette.ruby,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await widget.hub.deleteMediaFiles(targets);
    if (!mounted) return;

    final count = res['successCount'] ?? targets.length;
    final freed = res['deletedBytes'] ?? totalSize;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.filesDeletedSuccess(count, formatStorageBytes(freed))),
        backgroundColor: DarkGlassPalette.mint,
      ),
    );

    await _loadFiles();
  }

  Future<void> _deleteSingle(StorageMediaFile file) async {
    final s = HubStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteFileAction),
        content: Text(
          s.confirmDeleteSingle(
            file.name,
            formatStorageBytes(file.sizeBytes),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DarkGlassPalette.ruby,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await widget.hub.deleteMediaFiles([file]);
    if (!mounted) return;

    final freed = res['deletedBytes'] ?? file.sizeBytes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.filesDeletedSuccess(1, formatStorageBytes(freed))),
        backgroundColor: DarkGlassPalette.mint,
      ),
    );

    await _loadFiles();
  }

  void _previewPhoto(StorageMediaFile file) {
    final s = HubStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: file.path.isNotEmpty && File(file.path).existsSync()
                    ? Image.file(
                        File(file.path),
                        fit: BoxFit.contain,
                      )
                    : const Icon(
                        Icons.image_rounded,
                        size: 96,
                        color: Colors.white54,
                      ),
              ),
            ),
            PositionBar(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  title: Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded),
                      color: DarkGlassPalette.ruby,
                      tooltip: s.deleteFileAction,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _deleteSingle(file);
                      },
                    ),
                  ],
                ),
              ),
            ),
            PositionBar(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatStorageBytes(file.sizeBytes),
                        style: const TextStyle(
                          color: DarkGlassPalette.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (file.path.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.white,
                          ),
                          tooltip: s.openFileAction,
                          onPressed: () => widget.hub.openMediaFile(file),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoDetails(StorageMediaFile file) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: DarkGlassPalette.ruby.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: DarkGlassPalette.ruby.withValues(alpha: 0.34),
                    ),
                  ),
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: DarkGlassPalette.ruby,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${formatStorageBytes(file.sizeBytes)}${file.formattedDuration.isNotEmpty ? " · ${file.formattedDuration}" : ""}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: DarkGlassPalette.ruby,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (file.path.isNotEmpty)
              Text(
                '${s.filePathLabel}: ${file.path}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DarkGlassPalette.ruby,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(s.delete),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _deleteSingle(file);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: DarkGlassPalette.ruby,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(s.playVideoAction),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.hub.openMediaFile(file);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final filtered = _filter.trim().isEmpty
        ? _files
        : _files
            .where((f) =>
                f.name.toLowerCase().contains(_filter.toLowerCase().trim()))
            .toList();

    return IceDragonBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.manageStorageAction),
          actions: [
            IconButton(
              icon: Icon(
                _multiSelect
                    ? Icons.check_circle_rounded
                    : Icons.checklist_rounded,
                color: _multiSelect ? DarkGlassPalette.cyan : null,
              ),
              tooltip: s.multiSelect,
              onPressed: () {
                setState(() {
                  _multiSelect = !_multiSelect;
                  if (!_multiSelect) _selectedIds.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: s.refresh,
              onPressed: _loadFiles,
            ),
          ],
        ),
        body: Column(
          children: [
            // Category Segmented Tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<StorageViewCategory>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: StorageViewCategory.large,
                      icon: const Icon(Icons.sd_storage_rounded, size: 16),
                      label: Text(s.categoryLargeFiles),
                    ),
                    ButtonSegment(
                      value: StorageViewCategory.videos,
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: Text(s.categoryVideos),
                    ),
                    ButtonSegment(
                      value: StorageViewCategory.photos,
                      icon: const Icon(Icons.image_rounded, size: 16),
                      label: Text(s.categoryPhotos),
                    ),
                    ButtonSegment(
                      value: StorageViewCategory.documents,
                      icon: const Icon(Icons.folder_rounded, size: 16),
                      label: Text(s.categoryDocuments),
                    ),
                    ButtonSegment(
                      value: StorageViewCategory.audio,
                      icon: const Icon(Icons.audiotrack_rounded, size: 16),
                      label: Text(s.categoryAudio),
                    ),
                  ],
                  selected: {_category},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      setState(() => _category = set.first);
                      _loadFiles();
                    }
                  },
                ),
              ),
            ),

            // Search filter bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  hintText: s.search,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),

            // Multi-select header bar
            if (_multiSelect)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: DarkGlassPalette.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DarkGlassPalette.cyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      s.selectedCount(_selectedIds.length),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: DarkGlassPalette.cyan,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _selectAll,
                      child: Text(s.selectAll),
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: Text(s.clearSelection),
                    ),
                  ],
                ),
              ),

            // Files List or Loading State
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 56,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                s.noFilesInCategory,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 88),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final file = filtered[i];
                            final isSel = _selectedIds.contains(file.id);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                dark: dark,
                                padding: const EdgeInsets.all(10),
                                borderColor: isSel
                                    ? DarkGlassPalette.cyan
                                    : DarkGlassPalette.glassBorder,
                                onTap: () {
                                  if (_multiSelect) {
                                    _toggleSelect(file);
                                  } else if (file.isVideo) {
                                    _showVideoDetails(file);
                                  } else if (file.isImage) {
                                    _previewPhoto(file);
                                  } else {
                                    widget.hub.openMediaFile(file);
                                  }
                                },
                                child: Row(
                                  children: [
                                    if (_multiSelect)
                                      Checkbox(
                                        value: isSel,
                                        onChanged: (_) => _toggleSelect(file),
                                      ),

                                    // Leading Media Thumbnail / Icon
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        color: dark
                                            ? Colors.white
                                                .withValues(alpha: 0.08)
                                            : Colors.black
                                                .withValues(alpha: 0.05),
                                        child: _buildMediaThumbnail(file),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // File info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                formatStorageBytes(
                                                    file.sizeBytes),
                                                style: theme.textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                  color: _badgeColorFor(file),
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              if (file.formattedDuration
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '⏱ ${file.formattedDuration}',
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action buttons
                                    if (!_multiSelect) ...[
                                      if (file.isVideo)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.play_circle_outline_rounded,
                                            color: DarkGlassPalette.ruby,
                                          ),
                                          tooltip: s.playVideoAction,
                                          onPressed: () =>
                                              _showVideoDetails(file),
                                        )
                                      else if (file.isImage)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                            color: DarkGlassPalette.cyan,
                                          ),
                                          tooltip: s.previewPhotoAction,
                                          onPressed: () => _previewPhoto(file),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(
                                            Icons.open_in_new_rounded,
                                          ),
                                          tooltip: s.openFileAction,
                                          onPressed: () =>
                                              widget.hub.openMediaFile(file),
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: DarkGlassPalette.ruby,
                                        ),
                                        tooltip: s.deleteFileAction,
                                        onPressed: () => _deleteSingle(file),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),

        // Floating Action Bar for Multi-select deletion
        bottomSheet: _multiSelect && _selectedIds.isNotEmpty
            ? Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xFA0B1123) : const Color(0xF6FFFFFF),
                  border: Border(
                    top: BorderSide(
                      color: dark
                          ? DarkGlassPalette.glassBorder
                          : DarkGlassPalette.lightBorder,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} ${s.all} · ${formatStorageBytes(_selectedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes))}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: DarkGlassPalette.ruby,
                        ),
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: Text(s.deleteSelectedAction),
                        onPressed: _deleteSelected,
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildMediaThumbnail(StorageMediaFile file) {
    if (file.isImage && file.path.isNotEmpty && File(file.path).existsSync()) {
      return Image.file(
        File(file.path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.image_rounded,
          color: StorageBreakdownChartCard.colorPhotos,
        ),
      );
    }
    if (file.isVideo) {
      return const Icon(
        Icons.videocam_rounded,
        color: StorageBreakdownChartCard.colorVideos,
        size: 28,
      );
    }
    if (file.isAudio) {
      return const Icon(
        Icons.audiotrack_rounded,
        color: StorageBreakdownChartCard.colorAudio,
        size: 28,
      );
    }
    return const Icon(
      Icons.insert_drive_file_rounded,
      color: StorageBreakdownChartCard.colorDocs,
      size: 28,
    );
  }

  Color _badgeColorFor(StorageMediaFile file) {
    if (file.isVideo) return StorageBreakdownChartCard.colorVideos;
    if (file.isImage) return StorageBreakdownChartCard.colorPhotos;
    if (file.isAudio) return StorageBreakdownChartCard.colorAudio;
    return StorageBreakdownChartCard.colorDocs;
  }
}

/// Helper positioning container used in full-screen lightbox preview.
class PositionBar extends StatelessWidget {
  const PositionBar({
    super.key,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.child,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: child,
    );
  }
}
