import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bridges the native floating-overlay window (a Service-hosted set of
/// plain Android Views — no second Flutter engine) to the main isolate.
///
/// The overlay never talks to the TV directly: button taps come in here as
/// `onCommand`, get dispatched to the same [RemoteNotifier] the full UI
/// uses, and connection-status pushes go back out via [updateStatus] so the
/// overlay's dot stays in sync.
class OverlayBridgeService {
  OverlayBridgeService._();
  static final OverlayBridgeService instance = OverlayBridgeService._();

  static const _channel = MethodChannel('dpadpilot/overlay_bridge');
  static const _autoShowPrefKey = 'overlay_auto_show_enabled';

  void Function(String action)? onCommand;

  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'overlayCommand') {
        onCommand?.call(call.arguments as String);
      }
    });
  }

  /// Arms/disarms showing the overlay when the user leaves the app.
  /// RemoteScreen enables this on mount, disables it on dispose.
  Future<void> setOverlayEnabled(bool enabled) {
    return _channel.invokeMethod('setOverlayEnabled', {'enabled': enabled});
  }

  Future<bool> hasOverlayPermission() async {
    return (await _channel.invokeMethod<bool>('hasOverlayPermission')) ?? false;
  }

  /// Opens Android's "draw over other apps" settings screen. Must be
  /// user-initiated — this permission can't be silently granted.
  Future<void> requestOverlayPermission() {
    return _channel.invokeMethod('requestOverlayPermission');
  }

  /// [status] is a [TvConnectionState] name: 'connected' / 'connecting' / 'disconnected'.
  Future<void> updateStatus(String status) {
    return _channel.invokeMethod('updateStatus', {'status': status});
  }

  /// Whether the overlay should auto-show when leaving the app — lets
  /// widget-only or overlay-only testing/use without the other interfering.
  /// Defaults to true (matches the original always-on behavior).
  Future<bool> loadAutoShowPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoShowPrefKey) ?? true;
  }

  Future<void> setAutoShowPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoShowPrefKey, enabled);
  }
}
