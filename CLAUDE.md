# DPad Pilot — Claude Context
**Last updated:** July 2026
**Version:** 2.1.0+3

## What This Is
A clean, minimal LG WebOS TV remote for Android. Connects over local WiFi via SSDP discovery and SSAP WebSocket protocol. No ads, no account, no subscription. PWYW via Ko-fi. Built in Flutter 3.x — single codebase for Android and iOS (iOS deferred, no Mac). Can also be controlled without the app in foreground via a floating overlay and a home-screen widget (see below).

## Current Status
- **Live:** Google Play Store (searchable, full listing pending)
- **Version:** 2.1.0+3
- **Platform:** Android (iOS codebase ready, deferred)
- **Play Store listing:** All assets ready. Full listing pending device verification step.
- **minSdk 26** (raised from Flutter's default) — required by `TYPE_APPLICATION_OVERLAY` for the floating overlay.
- **Release signing configured** — upload keystore wired into `build.gradle.kts` via `key.properties` (was falling back to debug signing before).

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
  services/       ssdp_service.dart, ssap_service.dart, saved_tvs_service.dart,
                  overlay_bridge_service.dart
  providers/      discovery_provider.dart, remote_provider.dart, saved_tvs_provider.dart
  screens/        splash_screen.dart, discovery_screen.dart, remote_screen.dart, about_screen.dart
assets/
  DPad-Pilot.png  app icon

android/app/src/main/kotlin/com/mysterwolf/lg_remote/
  MainActivity.kt          — dpadpilot/overlay_bridge channel, PIP-style Home-leave hook
  OverlayBridge.kt         — in-process relay singleton (widget/overlay → main isolate)
  OverlayService.kt        — floating overlay: foreground Service + native Views
  RemoteWidgetProvider.kt  — home-screen widget (RemoteViews)
  WidgetActionReceiver.kt  — widget button taps → OverlayBridge

android/app/src/main/res/
  drawable/  ic_arrow_*.xml, ic_back.xml, ic_drag_handle.xml, ic_expand.xml (vector icons),
             bg_widget_*.xml, dot_*.xml (widget shape/status drawables)
  layout/    remote_widget.xml   — widget layout (RemoteViews, weighted rows)
  xml/       remote_widget_info.xml — AppWidgetProviderInfo
```

## Key Files
| File | Purpose |
|------|---------|
| lib/screens/splash_screen.dart | Reusable MWS splash widget. Dark mark, static, 3 seconds. Copy to other apps unchanged. |
| lib/services/ssap_service.dart | Core WebSocket service. Contains all SSAP logic and invariants. |
| lib/providers/remote_provider.dart | Riverpod .family per IP. App launcher cache lives here. |
| lib/screens/remote_screen.dart | Main remote UI. Four collapsible sections + app launcher bar. Also owns overlay/widget command dispatch and status push. |
| lib/services/overlay_bridge_service.dart | Dart side of the overlay/widget MethodChannel bridge. |
| android/.../OverlayService.kt | Floating overlay — draggable native-View cluster, no second Flutter engine. |
| android/.../RemoteWidgetProvider.kt | Home-screen widget — same button set/relay as the overlay, rendered via RemoteViews. |

## Architecture Decisions
- GPS/WiFi connection only — no Bluetooth
- Runtime listApps() for all app launches — no hardcoded app IDs ever
- App launcher bar: Disney+, YouTube, Amazon Prime, Netflix (4 apps)
- Single saved TV → skips discovery, connects directly on launch
- Auto-reconnect fires once on unexpected disconnect, never loops
- Splash screen is a reusable widget shared across all mysterwolf studios apps
- **Floating overlay + home-screen widget, both hand-rolled native (no third-party overlay plugin)** — matches this repo's existing pattern of hand-rolling SSDP/SSAP/prefs rather than depending on protocol packages. Native PIP (`enterPictureInPictureMode`) was tried first and rejected — the OS controls window size/aspect ratio, too cramped for a multi-button remote.
- **One TV connection, two extra surfaces** — the overlay and widget never open their own socket. Both relay button taps through `OverlayBridge` into the same `RemoteNotifier` the full UI uses. Both are only functional while `RemoteScreen` is mounted with a live connection.
- Overlay shows on `onUserLeaveHint()` (Home press or gesture-nav swipe-up, gated by a user-toggleable "auto-show" preference so overlay and widget can be tested/used independently), dismissed on `onResume()`.

## Invariants — Never Change These
- **All key events through pointer socket in format: type:button\nname:KEY\n\n**
- **Volume and channel use direct SSAP endpoints as fallback**
- **Settings launches via runtime listApps() lookup — no hardcoded app IDs**
- **No hardcoding of any TV model, IP, or app ID anywhere**
- **Auto-reconnect fires once on unexpected disconnect, never loops**
- **WRITE_WITHOUT_RESPONSE for all pointer socket writes**
- **The pointer socket's stream must be listened to, not just written to** — it was silently unlistened for a while, meaning its death went undetected and every keypress vanished into a dead socket with the UI still showing "ready." `_onPointerDead()` in `ssap_service.dart` is what catches this now; don't remove that listener.
- **"Return to app" intents from a non-Activity context (Service, BroadcastReceiver) must use `FLAG_ACTIVITY_NEW_TASK or FLAG_ACTIVITY_CLEAR_TOP or FLAG_ACTIVITY_SINGLE_TOP`, never `FLAG_ACTIVITY_REORDER_TO_FRONT`** — MainActivity has `taskAffinity=""` (Flutter's own default), and REORDER_TO_FRONT combined with that can spawn a duplicate task instead of resuming the existing one.
- **RemoteViews (the widget) does not support plain `<View>`** — throws `InflateException` on inflate. Use `<FrameLayout>` for spacers/blank cells instead.
- **Widget buttons use `layout_weight`, not fixed dp** — RemoteViews content doesn't auto-scale, so weighting is what lets the widget actually grow when resized.

## Pending Work
1. Complete Play Store full listing (device verification pending)
2. Post-launch: r/LGTV, r/homeautomation, r/androidapps, XDA Developers
3. iOS release (deferred — no Mac currently)
4. Samsung has its own separate background battery management (distinct from AOSP Doze) that may need its own exclusion via Settings if overlay/widget staleness shows up there too — Pixel was fixed via `adb shell dumpsys deviceidle whitelist`, Samsung wasn't.
5. Lock screen quick-controls explored and explicitly skipped — Android blocks third-party overlays over a *secured* lock screen at the OS level; notification-action-button alternative caps at ~3 buttons, not enough to be useable.

## Claude Code Session Starter
"I'm working on DPad Pilot — a Flutter LG WebOS TV remote app. Pull the repo and read CLAUDE.md and the full codebase. Respect all invariants listed in CLAUDE.md before making any changes. Confirm you understand the structure before I give you the next task."

## Changelog
### July 2026
- Release signing configured (upload keystore via key.properties); minSdk raised to 26
- Floating remote overlay added — draggable native-View cluster over other apps, foreground Service, vector icons (Samsung/OEM fonts render Unicode glyphs like ▲▼◀▶ as low-quality fallback glyphs — use vector drawables, not text glyphs, for any icon-like symbol)
- Home-screen widget added — same button set/relay as the overlay via RemoteViews, weighted rows so it fills/grows with whatever frame size it's given
- Persisted top-bar toggle to disable the overlay's auto-show independently of the widget
- Fixed: pointer socket death was completely undetected (no listener at all) — was very likely the cause of "press once or twice" after an idle period; now detected and keypresses retry transparently once
- Fixed: overlay/widget status could go stale (frozen on "connected") if the app process died outright; status dot now tappable to force a reconnect on both surfaces
- Fixed: "return to app" intents (overlay expand icon, notification tap, widget header) could spawn a duplicate app instance due to MainActivity's empty taskAffinity — switched to CLEAR_TOP|SINGLE_TOP

### May 2026
- Netflix added to app launcher (4 streaming apps total)
- Reusable MWS splash screen widget built (dark mark, static, 3 seconds)
- Play Store assets complete: feature graphic, descriptions, screenshots
- Version 2.1.0+3 submitted to Play Store

## Available Skills
Skills live at github.com/MysterWolf/skills. Pull that repo and read README.md
to see all available skills before starting work.

Relevant skills for this repo:
- edit-component — safe editing protocol, context first, invariants respected
- update-context — update this CLAUDE.md after session, commit and push
- audit-repo — read-only snapshot of repo state
- update-portfolio — add or update DPad Pilot entry on mysterwolf.studio

## Updated Claude Code Session Starter
"I'm working on DPad Pilot — a Flutter LG WebOS TV remote at github.com/MysterWolf/dpad_pilot.
First pull github.com/MysterWolf/skills and read README.md so you know what skills are available.
Then pull this repo and read CLAUDE.md in full. Respect all invariants before making any changes.
Confirm you understand the structure and available skills before I give you the next task."
