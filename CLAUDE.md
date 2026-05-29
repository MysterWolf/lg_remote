# DPad Pilot — Claude Context
**Last updated:** May 2026
**Version:** 2.1.0+3

## What This Is
A clean, minimal LG WebOS TV remote for Android. Connects over local WiFi via SSDP discovery and SSAP WebSocket protocol. No ads, no account, no subscription. PWYW via Ko-fi. Built in Flutter 3.x — single codebase for Android and iOS (iOS deferred, no Mac).

## Current Status
- **Live:** Google Play Store (searchable, full listing pending)
- **Version:** 2.1.0+3
- **Platform:** Android (iOS codebase ready, deferred)
- **Play Store listing:** All assets ready. Full listing pending device verification step.

## Tech Stack
| Layer | Choice | Notes |
|-------|--------|-------|
| Framework | Flutter 3.x | Android + iOS single codebase |
| WebSocket | web_socket_channel | SSAP on :3000 |
| TV Discovery | multicast_dns + SSDP | UDP 239.255.255.250:1900 |
| Persistence | shared_preferences | Client key + saved TVs |
| State | Riverpod (.family) | Per-IP RemoteNotifier |
| Icons | flutter_launcher_icons | Adaptive, #1e1e2e bg |
| Misc | package_info_plus, url_launcher | About screen |

## Directory Structure
```
lib/
  models/         saved_tv.dart, tv_device.dart
  services/       ssdp_service.dart, ssap_service.dart, saved_tvs_service.dart
  providers/      discovery_provider.dart, remote_provider.dart, saved_tvs_provider.dart
  screens/        splash_screen.dart, discovery_screen.dart, remote_screen.dart, about_screen.dart
assets/
  DPad-Pilot.png  app icon
```

## Key Files
| File | Purpose |
|------|---------|
| lib/screens/splash_screen.dart | Reusable MWS splash widget. Dark mark, static, 3 seconds. Copy to other apps unchanged. |
| lib/services/ssap_service.dart | Core WebSocket service. Contains all SSAP logic and invariants. |
| lib/providers/remote_provider.dart | Riverpod .family per IP. App launcher cache lives here. |
| lib/screens/remote_screen.dart | Main remote UI. Four collapsible sections + app launcher bar. |

## Architecture Decisions
- GPS/WiFi connection only — no Bluetooth
- Runtime listApps() for all app launches — no hardcoded app IDs ever
- App launcher bar: Disney+, YouTube, Amazon Prime, Netflix (4 apps)
- Single saved TV → skips discovery, connects directly on launch
- Auto-reconnect fires once on unexpected disconnect, never loops
- Splash screen is a reusable widget shared across all mysterwolf studios apps

## Invariants — Never Change These
- **All key events through pointer socket in format: type:button\nname:KEY\n\n**
- **Volume and channel use direct SSAP endpoints as fallback**
- **Settings launches via runtime listApps() lookup — no hardcoded app IDs**
- **No hardcoding of any TV model, IP, or app ID anywhere**
- **Auto-reconnect fires once on unexpected disconnect, never loops**
- **WRITE_WITHOUT_RESPONSE for all pointer socket writes**

## Pending Work
1. Complete Play Store full listing (device verification pending)
2. Post-launch: r/LGTV, r/homeautomation, r/androidapps, XDA Developers
3. iOS release (deferred — no Mac currently)

## Claude Code Session Starter
"I'm working on DPad Pilot — a Flutter LG WebOS TV remote app. Pull the repo and read CLAUDE.md and the full codebase. Respect all invariants listed in CLAUDE.md before making any changes. Confirm you understand the structure before I give you the next task."

## Changelog
### May 2026
- Netflix added to app launcher (4 streaming apps total)
- Reusable MWS splash screen widget built (dark mark, static, 3 seconds)
- Play Store assets complete: feature graphic, descriptions, screenshots
- Version 2.1.0+3 submitted to Play Store
