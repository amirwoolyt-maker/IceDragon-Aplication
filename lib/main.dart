import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_hub/hub_controller.dart';
import 'app_hub/hub_strings.dart';
import 'hub_settings.dart';
import 'hub_shell.dart';
import 'platform/app_hub_platform.dart';
import 'theme/hub_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dataDir = await AppHubPlatformChannel.dataDir();
  final settings = await HubAppSettings.load(dataDir);
  final hub = HubController();
  runApp(IceDragonHubApp(hub: hub, settings: settings));
}

class IceDragonHubApp extends StatefulWidget {
  const IceDragonHubApp({
    super.key,
    required this.hub,
    required this.settings,
  });

  final HubController hub;
  final HubAppSettings settings;

  @override
  State<IceDragonHubApp> createState() => _IceDragonHubAppState();
}

class _IceDragonHubAppState extends State<IceDragonHubApp> {
  @override
  void dispose() {
    widget.hub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final lang = widget.settings.language.trim();
        return MaterialApp(
          onGenerateTitle: (ctx) => HubStrings.of(ctx).appTitle,
          debugShowCheckedModeBanner: false,
          theme: buildLightGlassTheme(),
          darkTheme: buildDarkGlassTheme(),
          themeMode: widget.settings.themeMode,
          locale: lang.isEmpty ? null : Locale(lang),
          supportedLocales: const [Locale('en'), Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HubShell(hub: widget.hub, settings: widget.settings),
        );
      },
    );
  }
}
