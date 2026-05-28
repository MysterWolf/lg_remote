# DPad Pilot — Latest Context Document

A clean, minimal LG WebOS TV remote. No ads, no subscriptions.
Package: `dpad_pilot` | Version: 2.1.0+3 | Portrait-only | Dark Catppuccin theme

---

## Models

- `lib/models/saved_tv.dart` — `SavedTv(ip, name, lastSeen)` with JSON round-trip and `copyWith`
- `lib/models/tv_device.dart` — `TvDevice(name, ip)`, equality and hashCode by IP only

---

## Services

### `lib/services/ssdp_service.dart`
UDP multicast SSDP, 5-second scan window, parses `Friendly-Name` / `X-Friendly-Name` headers, returns `List<TvDevice>`.

### `lib/services/ssap_service.dart`
WebSocket on `:3000`. Full 37-permission manifest. Two sockets:
- **Main socket** — SSAP JSON protocol (`request()` / `command()`)
- **Pointer socket** — plain-text key events

Key facts:
- `pressKey(name)` writes `type:button\nname:$name\n\n` to pointer socket (fire-and-forget)
- `request(uri)` has 6-second timeout, returns `Future<Map>`
- `command(uri)` is one-way, no response expected
- `SsapStatus` enum: `disconnected / connecting / pairing / connected / ready / error`
- `TvConnectionState` 3-state enum for UI: `disconnected / connecting / connected`
- `toConnectionState()` maps `connected|ready → connected`, `connecting|pairing → connecting`, rest → `disconnected`
- Client key persisted in SharedPreferences under `lg_ck_<ip>`
- Pointer socket tries `wss://` then falls back to `ws://`; on failure emits `connected` (limited nav)

### `lib/services/saved_tvs_service.dart`
All persistence under `saved_tvs` key in SharedPreferences. Methods: `load`, `add` (dedupes by IP), `remove`, `rename`, `updateLastSeen`.

---

## Providers

### `lib/providers/discovery_provider.dart`
Plain `StateNotifier<DiscoveryState>`. `scan()` wraps `SsdpService.discover()`. `ScanStatus` enum: `idle / scanning / done / error`.

### `lib/providers/saved_tvs_provider.dart`
`SavedTvsNotifier` wrapping the service. Starts empty; `SplashScreen` calls `init(tvs)` after loading to populate before navigation. Methods: `init`, `add`, `remove`, `rename`, `updateLastSeen`, `isSaved(ip)`, `find(ip)`.

### `lib/providers/remote_provider.dart`
`StateNotifierProvider.family` keyed by IP — each TV gets isolated state.

`RemoteNotifier` wraps `SsapService` and exposes:

**Connection**
- `connect()`, `disconnect()`, `reconnect()` — `reconnect()` closes, waits 500 ms, reopens
- Three guard flags prevent reconnect loops: `_intentionalDisconnect`, `_reconnecting`, `_didAutoReconnect`
- Auto-reconnect fires once (2-second delay) on unexpected disconnect; resets on successful connection

**Key events** (always via pointer socket)
- `key(name)` → `pressKey(name)`
- `volumeUp/Down`, `channelUp/Down` → pointer socket if `isReady`, SSAP fallback otherwise
- `powerOff()` sets `_intentionalDisconnect = true` before commanding (TV closes socket after processing)

**App launching**
- `listApps()` — queries `ssap://com.webos.applicationManager/listApps`, **caches result in `_cachedApps`**; all subsequent calls return cache without a network round-trip
- `launchSettings()` — calls `listApps()`, scores candidates by closeness to `com.webos.app.settings`, opens via `ssap://system.launcher/open`
- `launchApp(appId)` — fires `ssap://system.launcher/launch` via `command()` (fire-and-forget)
- `launchStreamingApp(terms)` — searches cached app list for first ID containing any term, calls `launchApp()`, returns `bool` (found/not found)

**Text input**
- `insertText(text)` → `ssap://com.webos.service.ime/insertText`
- `deleteChar()` → `ssap://com.webos.service.ime/deleteCharacters` (count: 1)

---

## Screens

### `lib/screens/splash_screen.dart`
First screen shown on launch. `ConsumerStatefulWidget` — runs `Future.wait([Future.delayed(3s), _loadTvs()])` in `initState`, then calls `savedTvsProvider.notifier.init(tvs)` and navigates via `pushReplacement`. Routing logic: single saved TV → `RemoteScreen` with `onSwitchTv`; otherwise → `DiscoveryScreen`. UI: MWS mark (`assets/mws_mark_dark.png`, 120×120), "mysterwolf" (serif), "studios" (mono), tagline — all centered on `#1e1e2e`.

Native white flash eliminated: `drawable/launch_background.xml` and `drawable-v21/launch_background.xml` both use `@color/ic_launcher_background` (`#1e1e2e`); both `values/styles.xml` and `values-night/styles.xml` use `Theme.Black.NoTitleBar` with `#1e1e2e` for both `LaunchTheme` and `NormalTheme`.

### `lib/screens/discovery_screen.dart`
- Saved TVs section at top (deduped — SSDP results filter out any IP already saved)
- SSDP scan results below; bookmark icon to save with custom name
- Pencil to rename, trash to delete (with confirmation dialog)
- Manual IP entry at bottom
- `updateLastSeen` called on connect
- Single tap → `RemoteScreen`; also updates `selectedTvProvider`

### `lib/screens/remote_screen.dart`
**AppBar:** TV name | Switch TV button (when `onSwitchTv` set) | ⓘ About | status chip

**Body (Column):**
1. `_PersistentTopBar` — status dot + reconnect button (green/amber/red), Power, Settings, keyboard toggle
2. `_PairingBanner` (conditional) — orange prompt banner
3. `_ErrorBanner` (conditional) — red error banner with Retry
4. `Expanded` — either `_QwertyKeyboard` or `_RemoteSections`

No `bottomNavigationBar` — the Scaffold body fills to the bottom edge. `_RemoteSections` uses `MediaQuery.of(context).padding.bottom` to add scroll clearance for the system nav bar.

**`_RemoteSections`** — five collapsible sections:
- Volume & Channel (collapsed by default) — VOL+/−, MUTE, CH+/−
- Navigation (expanded) — D-pad + OK + BACK + HOME
- Playback (collapsed) — REWIND, PLAY, PAUSE, FASTFORWARD
- Keypad (collapsed) — 0–9
- Apps (collapsed) — four equal-width `_AppButton`s: Disney+ `['disney']`, YouTube `['youtube']`, Amazon Prime `['amazon', 'prime']`, Netflix `['netflix']`. Each calls `launchStreamingApp(terms)`; shows a snackbar if no match found. Buttons dim when disconnected. All five launchers (Settings + 4 app buttons) share `_cachedApps`.

**`_QwertyKeyboard`** — swaps entire body, sends via `insertText`, backspace via `deleteChar`

### `lib/screens/about_screen.dart`
App icon, tagline, version via `package_info_plus`, MysterWolf Development credit, MWS mark (`assets/mws_mark_dark.png`, height 36) below the credit, Ko-fi link via `url_launcher`.

---

## Widgets

### `lib/widgets/remote_button.dart`
`RemoteButton(child, onPressed, color, size, width, borderRadius)` — `Material` + `InkWell`, default size 52, circular by default. `DefaultTextStyle` sets white70 / w600 / 12px for child text.

---

## App Behavior

- **Always** → `SplashScreen` first (min 3s), then routes based on saved TV count
- **Single saved TV** → `RemoteScreen` with `onSwitchTv` callback
- **Multiple / zero saved TVs** → `DiscoveryScreen`
- App icon: `assets/DPad-Pilot.png`, adaptive icon with `#1e1e2e` background
- App display name: DPad Pilot | Package: `dpad_pilot`
- Theme: dark Catppuccin (`scaffold: 0xFF0F0F1A`, `surface: 0xFF1E1E2E`, `onSurface: 0xFFCDD6F4`, seed: `0xFF7B82FF`)

---

## Key Invariants — Never Break These

- All key events through pointer socket in format `type:button\nname:KEY\n\n`
- Volume/channel use direct SSAP endpoints as fallback when pointer socket isn't ready
- Settings and streaming apps launched via runtime `listApps()` lookup — no hardcoded app IDs
- No hardcoding of any TV model, IP, or app ID anywhere
- Auto-reconnect fires once on unexpected disconnect, never loops
- `powerOff()` always sets `_intentionalDisconnect = true` before commanding
- `listApps()` result is cached in `_cachedApps` — never makes more than one network request per session
