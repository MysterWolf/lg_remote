import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tv_device.dart';
import '../providers/discovery_provider.dart';
import '../providers/remote_provider.dart';
import 'remote_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _selectTv(TvDevice tv) {
    ref.read(selectedTvProvider.notifier).state = tv;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RemoteScreen(tv: tv)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final notifier = ref.read(discoveryProvider.notifier);
    final scanning = state.status == ScanStatus.scanning;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LG Remote'),
        actions: [
          if (scanning)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Scan for TVs',
              onPressed: notifier.scan,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Scan result list ──
          Expanded(
            child: state.devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tv_off,
                            size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          scanning
                              ? 'Scanning network…'
                              : state.status == ScanStatus.done
                                  ? 'No TVs found'
                                  : 'Tap search to find TVs',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.devices.length,
                    itemBuilder: (_, i) {
                      final tv = state.devices[i];
                      return ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(tv.name),
                        subtitle: Text(tv.ip,
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.5),
                                fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectTv(tv),
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // ── Manual IP entry ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Manual IP',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ipController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          hintText: '192.168.1.x',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () {
                        final ip = _ipController.text.trim();
                        if (ip.isEmpty) return;
                        _selectTv(TvDevice(name: 'LG TV', ip: ip));
                      },
                      child: const Text('Connect'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
