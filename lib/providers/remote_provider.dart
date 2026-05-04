import 'dart:async';
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
