import 'dart:io';

import 'package:flutter/material.dart';

import '../../hub_settings.dart';
import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_models.dart';
import '../hub_strings.dart';
import 'hub_widgets.dart';

/// Standalone App Hub preferences page (#5, #8, #12, #16, download storage & appearance).
class HubSettingsPage extends StatefulWidget {
  const HubSettingsPage({
    super.key,
    required this.hub,
    required this.settings,
  });

  final HubController hub;
  final HubAppSettings settings;

  @override
  State<HubSettingsPage> createState() => _HubSettingsPageState();
}

class _HubSettingsPageState extends State<HubSettingsPage> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _customPathCtrl;
  bool _obscureKey = true;
  String? _pathError;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.hub.repo.geminiApiKey);
    _customPathCtrl = TextEditingController(
      text: widget.hub.repo.customDownloadPath,
    );
    Future.microtask(() async {
      await widget.hub.ensureLoaded();
      if (!mounted) return;
      setState(() {
        if (_keyCtrl.text != widget.hub.repo.geminiApiKey) {
          _keyCtrl.text = widget.hub.repo.geminiApiKey;
        }
        if (_customPathCtrl.text != widget.hub.repo.customDownloadPath) {
          _customPathCtrl.text = widget.hub.repo.customDownloadPath;
        }
      });
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _customPathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: Listenable.merge([widget.hub, widget.settings]),
      builder: (context, _) {
        final hub = widget.hub;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            GlassCard(
              dark: dark,
              accentColor: DarkGlassPalette.cyan,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [DarkGlassPalette.cyan, DarkGlassPalette.purple],
                      ),
                    ),
                    child: const Icon(
                      Icons.ac_unit_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.appTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.appHubTagline,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const IcePillBadge(
                    text: 'v1.1.0',
                    color: DarkGlassPalette.cyan,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              dark: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.quickLanguageLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'fa', label: Text('فارسی')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {
                      widget.settings.language == 'fa' ||
                              (widget.settings.language.isEmpty && s.isFa)
                          ? 'fa'
                          : 'en',
                    },
                    onSelectionChanged: (v) =>
                        widget.settings.update(language: v.first),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.themeLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(s.themeDark),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(s.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(s.themeSystem),
                      ),
                    ],
                    selected: {widget.settings.themeMode},
                    onSelectionChanged: (v) =>
                        widget.settings.update(themeMode: v.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              dark: dark,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.rocket_launch_rounded),
                    title: Text(s.boostBeforeLaunchLabel),
                    subtitle: Text(
                      s.speedBoostHonestNote,
                      style: theme.textTheme.bodySmall,
                    ),
                    value: hub.repo.boostBeforeLaunch,
                    onChanged: hub.setBoostBeforeLaunch,
                  ),
                  if (Platform.isAndroid) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.verified_user_rounded,
                        color: DarkGlassPalette.mint,
                      ),
                      title: Text(s.zeroPermsTitle),
                      subtitle: Text(
                        hub.device.freeStorageBytes > 0
                            ? '${s.zeroPermsDesc}\n${s.freeStorage}: ${formatStorageBytes(hub.device.freeStorageBytes)}'
                            : s.zeroPermsDesc,
                      ),
                      trailing: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: DarkGlassPalette.mint,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              dark: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        color: DarkGlassPalette.cyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.downloadLocationTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.downloadLocationSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RadioListTile<DownloadLocationType>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.downloadLocationRecommended),
                    value: DownloadLocationType.recommended,
                    groupValue: hub.repo.downloadLocation,
                    onChanged: (v) {
                      if (v != null) hub.setDownloadLocation(v);
                    },
                  ),
                  RadioListTile<DownloadLocationType>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.downloadLocationPublic),
                    value: DownloadLocationType.publicDownloads,
                    groupValue: hub.repo.downloadLocation,
                    onChanged: (v) {
                      if (v != null) hub.setDownloadLocation(v);
                    },
                  ),
                  RadioListTile<DownloadLocationType>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.downloadLocationCustom),
                    value: DownloadLocationType.custom,
                    groupValue: hub.repo.downloadLocation,
                    onChanged: (v) {
                      if (v != null) hub.setDownloadLocation(v);
                    },
                  ),
                  if (hub.repo.downloadLocation ==
                      DownloadLocationType.custom) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _customPathCtrl,
                      onChanged: (_) {
                        if (_pathError != null) {
                          setState(() => _pathError = null);
                        } else {
                          setState(() {});
                        }
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: s.downloadLocationCustom,
                        hintText: s.customDownloadPathHint,
                        errorText: _pathError,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_customPathCtrl.text.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              setState(() {
                                _customPathCtrl.clear();
                                _pathError = null;
                              });
                              await hub.setDownloadLocation(
                                DownloadLocationType.recommended,
                                '',
                              );
                            },
                            child: Text(s.delete),
                          ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () async {
                            final raw = _customPathCtrl.text.trim();
                            if (raw.isEmpty) {
                              setState(() => _pathError = s.customPathInvalid);
                              return;
                            }
                            await hub.setDownloadLocation(
                              DownloadLocationType.custom,
                              raw,
                            );
                            if (!context.mounted) return;
                            setState(() => _pathError = null);
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                content: Text(s.downloadPathSaved),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(s.save),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              dark: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.geminiApiKeyLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.geminiApiKeyHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: _obscureKey,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'AIza...',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_keyCtrl.text.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            setState(() => _keyCtrl.clear());
                            await hub.setGeminiApiKey('');
                          },
                          child: Text(s.delete),
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          await hub.setGeminiApiKey(_keyCtrl.text);
                          if (!context.mounted) return;
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text(s.done),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
