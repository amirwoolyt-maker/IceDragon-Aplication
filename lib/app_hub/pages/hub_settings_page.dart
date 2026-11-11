import 'dart:io';

import 'package:flutter/material.dart';

import '../../hub_settings.dart';
import '../../theme/hub_theme.dart';
import '../hub_controller.dart';
import '../hub_strings.dart';

/// Standalone App Hub preferences page (#5, #8, #12, #16 + external VPN options).
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
  late final TextEditingController _proxyCtrl;
  bool _obscureKey = true;
  String? _proxyError;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.hub.repo.geminiApiKey);
    _proxyCtrl = TextEditingController(
      text: widget.hub.repo.externalProxyAddress,
    );
    Future.microtask(() async {
      await widget.hub.ensureLoaded();
      if (!mounted) return;
      setState(() {
        if (_keyCtrl.text != widget.hub.repo.geminiApiKey) {
          _keyCtrl.text = widget.hub.repo.geminiApiKey;
        }
        if (_proxyCtrl.text != widget.hub.repo.externalProxyAddress) {
          _proxyCtrl.text = widget.hub.repo.externalProxyAddress;
        }
      });
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _proxyCtrl.dispose();
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
        final bypassCount = hub.repo.vpnBypassPackages.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                      leading: Icon(
                        hub.device.hasUsageAccess
                            ? Icons.verified_user_rounded
                            : Icons.admin_panel_settings_outlined,
                        color: hub.device.hasUsageAccess
                            ? DarkGlassPalette.mint
                            : DarkGlassPalette.amber,
                      ),
                      title: Text(s.freeStorage),
                      subtitle: Text(
                        hub.device.hasUsageAccess
                            ? s.usageAccessGranted
                            : s.usageAccessMissing,
                      ),
                      trailing: hub.device.hasUsageAccess
                          ? const Icon(
                              Icons.check_circle_outline_rounded,
                              color: DarkGlassPalette.mint,
                              size: 20,
                            )
                          : TextButton(
                              onPressed: () =>
                                  hub.platform.openUsageAccessSettings(),
                              child: Text(s.grantUsageAccess),
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
                        Icons.vpn_lock_outlined,
                        color: DarkGlassPalette.cyan,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.openVpnSettingsLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: hub.openVpnSettings,
                        child: Text(s.open),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.vpnStandaloneInfo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.useVpnForStoresLabel),
                    value: hub.repo.useVpnProxyForStores,
                    onChanged: hub.setUseVpnProxyForStores,
                  ),
                  TextField(
                    controller: _proxyCtrl,
                    onChanged: (_) {
                      if (_proxyError != null) {
                        setState(() => _proxyError = null);
                      } else {
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: s.externalProxyLabel,
                      hintText: s.externalProxyHint,
                      errorText: _proxyError,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_proxyCtrl.text.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            setState(() {
                              _proxyCtrl.clear();
                              _proxyError = null;
                            });
                            await hub.setExternalProxyAddress('');
                          },
                          child: Text(s.delete),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () async {
                          final ok = await hub.setExternalProxyAddress(
                            _proxyCtrl.text,
                          );
                          if (!context.mounted) return;
                          if (!ok) {
                            setState(() => _proxyError = s.externalProxyInvalid);
                            return;
                          }
                          setState(() => _proxyError = null);
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
                  if (bypassCount > 0) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.savedBypassListTitle(bypassCount),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: s.share,
                          onPressed: () => hub.platform.shareText(
                            (hub.repo.vpnBypassPackages.toList()..sort()).join(
                              '\n',
                            ),
                            subject: s.savedBypassListTitle(bypassCount),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 19),
                        ),
                        IconButton(
                          tooltip: s.delete,
                          onPressed: hub.clearVpnBypassPlan,
                          icon: const Icon(Icons.delete_outline_rounded, size: 19),
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
