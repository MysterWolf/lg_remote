import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tv_device.dart';
import '../services/ssdp_service.dart';

enum ScanStatus { idle, scanning, done, error }

class DiscoveryState {
  final ScanStatus status;
  final List<TvDevice> devices;
  final String? error;

  const DiscoveryState({
    this.status = ScanStatus.idle,
    this.devices = const [],
    this.error,
  });

  DiscoveryState copyWith({
    ScanStatus? status,
    List<TvDevice>? devices,
    String? error,
  }) =>
      DiscoveryState(
        status: status ?? this.status,
        devices: devices ?? this.devices,
        error: error,
      );
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier() : super(const DiscoveryState());

  final _ssdp = SsdpService();

  Future<void> scan() async {
    state = state.copyWith(status: ScanStatus.scanning, devices: []);
    try {
      final devices = await _ssdp.discover();
      state = state.copyWith(status: ScanStatus.done, devices: devices);
    } catch (e) {
      state = state.copyWith(status: ScanStatus.error, error: e.toString());
    }
  }
}

final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>(
  (_) => DiscoveryNotifier(),
);
