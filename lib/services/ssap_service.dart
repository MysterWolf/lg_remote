import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SsapStatus { disconnected, connecting, pairing, connected, ready, error }

/// Simplified 3-state connection view used by the UI dot and reconnect button.
enum TvConnectionState { disconnected, connecting, connected }

class SsapService {
  final String ip;

  WebSocketChannel? _main;
  WebSocketChannel? _pointer;
  StreamSubscription<dynamic>? _mainSub;
  StreamSubscription<dynamic>? _pointerSub;

  int _cmdId = 0;
  final _pending = <String, Completer<Map<String, dynamic>>>{};

  final _statusCtrl = StreamController<SsapStatus>.broadcast();
  Stream<SsapStatus> get statusStream => _statusCtrl.stream;

  SsapStatus _status = SsapStatus.disconnected;
  SsapStatus get status => _status;

  static TvConnectionState toConnectionState(SsapStatus s) => switch (s) {
        SsapStatus.connected || SsapStatus.ready => TvConnectionState.connected,
        SsapStatus.connecting ||
        SsapStatus.pairing =>
          TvConnectionState.connecting,
        _ => TvConnectionState.disconnected,
      };

  TvConnectionState get connectionState => toConnectionState(_status);

  Stream<TvConnectionState> get connectionStateStream =>
      statusStream.map(toConnectionState);

  String? _clientKey;

  static const _keyPrefix = 'lg_ck_';

  static const _manifest = <String, Object>{
    'manifestVersion': 1,
    'appVersion': '1.4.0',
    'appId': 'com.lge.lgremote',
    'appName': 'LG Remote',
    'localizedAppNames': <String, String>{'': 'LG Remote', 'ko-KR': 'LG Remote'},
    'permissions': <String>[
      'LAUNCH', 'LAUNCH_WEBAPP', 'APP_TO_APP', 'CLOSE',
      'TEST_OPEN', 'TEST_PROTECTED',
      'CONTROL_AUDIO', 'CONTROL_DISPLAY',
      'CONTROL_INPUT_JOYSTICK', 'CONTROL_INPUT_MEDIA_RECORDING',
      'CONTROL_INPUT_MEDIA_PLAYBACK', 'CONTROL_INPUT_TV',
      'CONTROL_INPUT_TEXT', 'CONTROL_MOUSE_AND_KEYBOARD',
      'CONTROL_POWER', 'CONTROL_RECORDING', 'CONTROL_BLUETOOTH',
      'CONTROL_TV_SCREEN',
      'READ_APP_STATUS', 'READ_CURRENT_CHANNEL', 'READ_INPUT_DEVICE_LIST',
      'READ_INSTALLED_APPS', 'READ_LGE_SDX', 'READ_NETWORK_STATE',
      'READ_NOTIFICATIONS', 'READ_RUNNING_APPS', 'READ_UPDATE_INFO',
      'READ_TV_CURRENT_TIME', 'READ_RECORDING_STATE', 'READ_SETTINGS',
      'READ_LGE_TV_INPUT_EVENTS', 'SEARCH', 'SCAN_TV_CHANNELS',
      'UPDATE_FROM_REMOTE_APP', 'WRITE_NOTIFICATION_ALERT',
      'WRITE_SETTINGS', 'TEST_SECURE',
    ],
    'signed': <String, Object>{
      'permissions': <String>[
        'TEST_SECURE', 'CONTROL_INPUT_TEXT', 'CONTROL_MOUSE_AND_KEYBOARD',
        'READ_INSTALLED_APPS', 'READ_LGE_SDX', 'READ_NOTIFICATIONS',
        'SEARCH', 'WRITE_SETTINGS', 'WRITE_NOTIFICATION_ALERT',
        'CONTROL_POWER', 'READ_CURRENT_CHANNEL', 'READ_RUNNING_APPS',
        'READ_UPDATE_INFO', 'UPDATE_FROM_REMOTE_APP',
        'READ_LGE_TV_INPUT_EVENTS', 'READ_TV_CURRENT_TIME',
      ],
    },
  };

  SsapService({required this.ip});

  Future<void> connect() async {
    if (_status != SsapStatus.disconnected && _status != SsapStatus.error) return;
    _emit(SsapStatus.connecting);
    final prefs = await SharedPreferences.getInstance();
    _clientKey = prefs.getString('$_keyPrefix$ip');

    try {
      _main = WebSocketChannel.connect(Uri.parse('ws://$ip:3000'));
      await _main!.ready;
    } catch (e) {
      _emit(SsapStatus.error);
      return;
    }

    _mainSub = _main!.stream.listen(
      _onMessage,
      onError: (_) => _emit(SsapStatus.error),
      onDone: () {
        _pointer = null;
        _emit(SsapStatus.disconnected);
      },
    );

    _sendRaw({
      'type': 'register',
      'id': 'register_0',
      'payload': <String, dynamic>{
        'forcePairing': false,
        'pairingType': 'PROMPT',
        'manifest': _manifest,
        if (_clientKey != null) 'client-key': _clientKey!,
      },
    });
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = msg['type'] as String?;
    final id = msg['id'] as String?;
    final payload = (msg['payload'] as Map<String, dynamic>?) ?? {};

    switch (type) {
      case 'registered':
        final key = payload['client-key'] as String?;
        if (key != null) {
          _clientKey = key;
          SharedPreferences.getInstance()
              .then((p) => p.setString('$_keyPrefix$ip', key));
        }
        _emit(SsapStatus.connected);
        _openPointerSocket();

      case 'pairing':
        _emit(SsapStatus.pairing);

      case 'response':
        if (id == 'register_0' && payload['pairingType'] == 'PROMPT') {
          _emit(SsapStatus.pairing);
          return;
        }
        _resolve(id, payload, isError: false);

      case 'error':
        _resolve(id, payload, isError: true);
    }
  }

  void _resolve(String? id, Map<String, dynamic> payload,
      {required bool isError}) {
    if (id == null) return;
    final c = _pending.remove(id);
    if (c == null) return;
    if (isError) {
      c.completeError(payload['message'] ?? 'SSAP error');
    } else {
      c.complete(payload);
    }
  }

  Future<void> _openPointerSocket() async {
    try {
      final result = await request(
          'ssap://com.webos.service.networkinput/getPointerInputSocket');
      final path = result['socketPath'] as String?;
      if (path != null) {
        await _connectPointer(path);
        return;
      }
    } catch (_) {}
    _emit(SsapStatus.connected); // usable without pointer socket
  }

  Future<void> _connectPointer(String url) async {
    final urls = url.startsWith('wss://')
        ? [url, url.replaceFirst('wss://', 'ws://')]
        : [url];

    for (final u in urls) {
      try {
        final ch = IOWebSocketChannel.connect(
          u,
          customClient: HttpClient()..badCertificateCallback = (_, __, ___) => true,
        );
        await ch.ready;
        _pointer = ch;
        // The pointer protocol is one-way (fire-and-forget), so this stream
        // never emits real messages — but listening is what lets onDone/
        // onError actually surface a dead socket instead of it silently
        // eating every keypress forever.
        _pointerSub = ch.stream.listen(
          (_) {},
          onError: (_) => _onPointerDead(),
          onDone: _onPointerDead,
        );
        _emit(SsapStatus.ready);
        return;
      } catch (_) {}
    }
    _emit(SsapStatus.connected); // no pointer socket, limited nav
  }

  void _onPointerDead() {
    _pointerSub?.cancel();
    _pointerSub = null;
    _pointer = null;
    // Main socket may still be fine — only demote, don't tear down the
    // whole connection over a pointer-socket-only failure.
    if (_status == SsapStatus.ready) _emit(SsapStatus.connected);
  }

  /// Best-effort reopen of just the pointer socket, e.g. after a send found
  /// it unexpectedly gone. Never throws — same fallback behavior as the
  /// original open path if it can't be reestablished.
  Future<void> ensurePointerSocket() => _openPointerSocket();

  Future<Map<String, dynamic>> request(String uri,
      [Map<String, dynamic>? payload]) {
    final id = 'r${_cmdId++}';
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;
    _sendRaw({
      'type': 'request',
      'id': id,
      'uri': uri,
      if (payload != null) 'payload': payload,
    });
    return c.future.timeout(const Duration(seconds: 6));
  }

  void command(String uri, [Map<String, dynamic>? payload]) {
    final id = 'c${_cmdId++}';
    _sendRaw({
      'type': 'request',
      'id': id,
      'uri': uri,
      if (payload != null) 'payload': payload,
    });
  }

  /// Returns false when there was no live pointer socket to write to —
  /// callers use that to trigger a reopen-and-resend instead of the
  /// keypress silently vanishing.
  bool pressKey(String name) {
    if (_pointer == null) return false;
    _pointer!.sink.add('type:button\nname:$name\n\n');
    return true;
  }

  void _sendRaw(Map<String, dynamic> msg) =>
      _main?.sink.add(jsonEncode(msg));

  void _emit(SsapStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  void disconnect() {
    _mainSub?.cancel();
    _mainSub = null;
    _pointerSub?.cancel();
    _pointerSub = null;
    _main?.sink.close();
    _pointer?.sink.close();
    _main = null;
    _pointer = null;
    for (final c in _pending.values) {
      c.completeError('disconnected');
    }
    _pending.clear();
    _emit(SsapStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusCtrl.close();
  }
}
