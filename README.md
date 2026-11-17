# IceDragon App Hub

Standalone Flutter + Android application for installed app management, multi-store search (Apple App Store, Google Play, Cafe Bazaar, Myket), Turbine Speed Boost launcher, Phone Assistant diagnostics, App Profile & Compare, Collections, Download storage configuration, and bilingual (Persian / English) AI recommendations.

## Features & Architecture

- **100% Standalone**: Completely decoupled from VPN cores, proxies, or tunnel infrastructure.
- **Package name**: `icedragon_app_hub` (`applicationId = "com.icedragon.apphub"`).
- **Multi-Store Radar**: Searches Apple App Store (iTunes API), Google Play, Cafe Bazaar, and Myket in parallel.
- **Turbine Speed Boost**: Animated pre-launch optimization gauge trimming background tasks and optimizing RAM before launching apps.
- **Smart Sorting & Categorization**: Sort installed apps by Name (A-Z / Z-A), APK Size (Largest / Smallest), Recently Updated, and Install Date.
- **Download Storage Configuration**: Choose between Recommended (`Downloads/IceDragonHub`), Public Downloads, or a Custom storage directory.
- **Zero-Permission Ready**: Requires zero nagging permissions (no `PACKAGE_USAGE_STATS` or all-files access needed).

## Commands (run in a Flutter/Android SDK environment)

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
