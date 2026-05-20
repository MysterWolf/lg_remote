import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tv_device.dart';
import '../services/ssap_service.dart';

final selectedTvProvider = StateProvider<TvDevice?>((ref) => null);

class RemoteState {
  final SsapStatus status;

  const RemoteState({this.status = SsapStatus.disconnected});

  bool get isActive =>
      status == SsapStatus.connected || status == SsapStatus.ready;
  bool get isReady => status == SsapStatus.ready;
  bool get isPairing => status == SsapStatus.pairing;
  bool get isConnecting => status == SsapStatus.connecting;
  bool get isError => status == SsapStatus.error;

  TvConnectionState get connectionState =>
      SsapService.toConnectionState(status);
}

class RemoteNotifier extends StateNotifier<RemoteState> {
  final SsapService _svc;
  late final StreamSubscription<SsapStatus> _sub;

  // ── Reconnect guard flags ─────────────────────────────
  // Prevents auto-reconnect when the socket close was deliberate.
  bool _intentionalDisconnect = false;
  // True while reconnect() is mid-flight (disconnect→delay→connect).
  // Blocks auto-reconnect from firing on the intermediate disconnect event.
  bool _reconnecting = false;
  // Ensures only one automatic reconnect attempt per unexpected drop.
  bool _didAutoReconnect = false;
  Timer? _reconnectTimer;

  RemoteNotifier(this._svc) : super(const RemoteState()) {
    _sub = _svc.statusStream.listen(_onStatus);
  }

  void _onStatus(SsapStatus s) {
    if (!mounted) return;
    state = RemoteState(status: s);

    if (s == SsapStatus.connected || s == SsapStatus.ready) {
      // Successful connection resets the one-shot auto-reconnect gate.
      _didAutoReconnect = false;
    }

    if (s == SsapStatus.disconnected || s == SsapStatus.error) {
      if (!_intentionalDisconnect && !_reconnecting && !_didAutoReconnect) {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted) return;
          _didAutoReconnect = true;
          _svc.connect();
        });
      }
      // Only clear the flag once we've fully landed in a terminal state,
      // and not while a reconnect() call is managing the lifecycle itself.
      if (!_reconnecting) _intentionalDisconnect = false;
    }
  }

  Future<void> connect() => _svc.connect();

  void disconnect() {
    _reconnectTimer?.cancel();
    _intentionalDisconnect = true;
    _svc.disconnect();
  }

  /// Closes the existing socket cleanly, waits 500 ms, then re-initiates
  /// the full connection and pairing flow. Safe to call in any state.
  Future<void> reconnect() async {
    _reconnectTimer?.cancel();
    _reconnecting = true;
    _didAutoReconnect = false;
    _intentionalDisconnect = true;
    _svc.disconnect(); // emits disconnected synchronously; _onStatus ignores it
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _reconnecting = false;
    _intentionalDisconnect = false;
    await _svc.connect();
  }

  // Navigation — always via pointer socket
  void key(String name) => _svc.pressKey(name);

  // Volume/channel: pointer socket if ready, SSAP fallback
  void volumeUp() => state.isReady
      ? _svc.pressKey('VOLUMEUP')
      : _svc.command('ssap://audio/volumeUp');

  void volumeDown() => state.isReady
      ? _svc.pressKey('VOLUMEDOWN')
      : _svc.command('ssap://audio/volumeDown');

  void channelUp() => state.isReady
      ? _svc.pressKey('CHANNELUP')
      : _svc.command('ssap://tv/channelUp');

  void channelDown() => state.isReady
      ? _svc.pressKey('CHANNELDOWN')
      : _svc.command('ssap://tv/channelDown');

  void powerOff() {
    // TV will close the WebSocket after processing this; mark it intentional
    // so the resulting disconnect does not trigger auto-reconnect.
    _intentionalDisconnect = true;
    _svc.command('ssap://system/turnOff');
  }

  void openSettings(String appId) => _svc.command(
        'ssap://system.launcher/open',
        {'id': appId},
      );

  Future<List<Map<String, dynamic>>> listApps() async {
    final result = await _svc.request(
        'ssap://com.webos.applicationManager/listApps');
    final raw = result['apps'] as List<dynamic>? ?? [];
    final apps = raw.cast<Map<String, dynamic>>();
    debugPrint('[LG] listApps — ${apps.length} total apps:');
    for (final app in apps) {
      debugPrint('  id="${app['id']}"  title="${app['title']}"');
    }
    return apps;
  }

  /// Queries the app list at runtime, finds the best settings app, and
  /// launches it. Returns false if no settings app is found.
  Future<bool> launchSettings() async {
    final apps = await listApps();

    final candidates = apps
        .where((a) =>
            (a['id'] as String? ?? '').toLowerCase().contains('settings'))
        .toList();

    if (candidates.isEmpty) return false;

    // Score by closeness to the canonical WebOS settings ID
    const target = 'com.webos.app.settings';
    int score(Map<String, dynamic> app) {
      final id = (app['id'] as String? ?? '').toLowerCase();
      if (id == target) return 3;
      if (id.endsWith('.settings')) return 2;
      return 1;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    final bestId = candidates.first['id'] as String;
    debugPrint('[LG] launchSettings → $bestId');
    openSettings(bestId);
    return true;
  }

  void insertText(String text) => _svc.command(
        'ssap://com.webos.service.ime/insertText',
        {'text': text, 'replace': false},
      );

  void deleteChar() => _svc.command(
        'ssap://com.webos.service.ime/deleteCharacters',
        {'count': 1},
      );

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _sub.cancel();
    _svc.dispose();
    super.dispose();
  }
}

final remoteProvider =
    StateNotifierProvider.family<RemoteNotifier, RemoteState, String>(
  (ref, ip) {
    final svc = SsapService(ip: ip);
    return RemoteNotifier(svc);
  },
);
