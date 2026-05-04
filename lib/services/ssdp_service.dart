import 'dart:async';
import 'dart:io';
import '../models/tv_device.dart';

class SsdpService {
  static const _multicast = '239.255.255.250';
  static const _port = 1900;
  static const _mx = 3;
  static const _searchMessage =
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: $_mx\r\n'
      'ST: urn:lge-com:service:webos-second-screen:1\r\n'
      '\r\n';

  Future<List<TvDevice>> discover() async {
    final found = <String, TvDevice>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.multicastHops = 4;

      socket.send(
        _searchMessage.codeUnits,
        InternetAddress(_multicast),
        _port,
      );

      final done = Completer<void>();
      Timer(const Duration(seconds: 5), () {
        if (!done.isCompleted) done.complete();
      });

      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket!.receive();
        if (dg == null) return;
        final ip = dg.address.address;
        if (found.containsKey(ip)) return;
        final text = String.fromCharCodes(dg.data);
        found[ip] = TvDevice(name: _parseName(text, ip), ip: ip);
      });

      await done.future;
    } catch (_) {
      // UDP unavailable (emulator / restricted network) — return empty list
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }

  String _parseName(String response, String fallbackIp) {
    for (final line in response.split('\r\n')) {
      final lower = line.toLowerCase();
      if (lower.startsWith('friendly-name:') ||
          lower.startsWith('x-friendly-name:')) {
        final val = line.substring(line.indexOf(':') + 1).trim();
        if (val.isNotEmpty) return val;
      }
    }
    return 'LG TV ($fallbackIp)';
  }
}
