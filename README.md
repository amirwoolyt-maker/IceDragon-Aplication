# IceDragon App Hub

Standalone Flutter + Android application for installed app management, multi-store search (Google Play, Cafe Bazaar, Myket), Phone Assistant diagnostics, App Profile & Compare, Collections, and bilingual (Persian / English) AI recommendations.

## Independence from `arman-vpn-mobile`

- Zero dependencies on `arman-vpn-mobile`, `core/` (Go VPN engine), `CoreService.kt`, or VPN UI screens.
- Package name: `icedragon_app_hub` (`applicationId = "com.icedragon.apphub"`).
- **VPN / Proxy boundary**:
  - Store lookups work directly over HTTPS, or optionally through an external VPN app's local HTTP proxy configured in **Settings** (`external_proxy_address`, e.g. `127.0.0.1:10808`).
  - Multi-select **+ VPN Bypass / - VPN Bypass** manages the user's persistent local Bypass List and offers one-tap navigation to **Android VPN Settings** (or sharing the list), without embedding a fake VPN service.

## Commands (run in a Flutter/Android SDK environment)

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
