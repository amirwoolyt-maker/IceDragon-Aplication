import 'package:flutter/material.dart';

import 'app_hub/hub_controller.dart';
import 'app_hub/hub_strings.dart';
import 'app_hub/pages/apps_manager_page.dart';
import 'app_hub/pages/assistant_hub_page.dart';
import 'app_hub/pages/hub_settings_page.dart';
import 'app_hub/pages/store_hub_page.dart';
import 'hub_settings.dart';

/// Top-level 4-tab navigation shell for standalone IceDragon App Hub.
class HubShell extends StatefulWidget {
  const HubShell({
    super.key,
    required this.hub,
    required this.settings,
  });

  final HubController hub;
  final HubAppSettings settings;

  @override
  State<HubShell> createState() => _HubShellState();
}

class _HubShellState extends State<HubShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = HubStrings.of(context);
    final page = switch (_tab) {
      0 => AppsManagerPage(hub: widget.hub),
      1 => StoreHubPage(hub: widget.hub),
      2 => AssistantHubPage(hub: widget.hub),
      _ => Scaffold(
        appBar: AppBar(title: Text(s.appHubSettingsTitle)),
        body: HubSettingsPage(hub: widget.hub, settings: widget.settings),
      ),
    };

    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: SafeArea(top: false, child: page),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.apps_outlined),
              selectedIcon: const Icon(Icons.apps_rounded),
              label: s.navApps,
            ),
            NavigationDestination(
              icon: const Icon(Icons.travel_explore_outlined),
              selectedIcon: const Icon(Icons.travel_explore_rounded),
              label: s.navStores,
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome_rounded),
              label: s.navAssistant,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: s.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
