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
}

class RemoteNotifier extends StateNotifier<RemoteState> {
  final SsapService _svc;
  late final StreamSubscription<SsapStatus> _sub;

  RemoteNotifier(this._svc) : super(const RemoteState()) {
    _sub = _svc.statusStream.listen((s) => state = RemoteState(status: s));
  }

  Future<void> connect() => _svc.connect();
  void disconnect() => _svc.disconnect();

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

  void powerOff() => _svc.command('ssap://system/turnOff');

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
