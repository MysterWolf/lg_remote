import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tv_device.dart';
import '../providers/remote_provider.dart';
import '../services/ssap_service.dart';
import '../widgets/remote_button.dart';

class RemoteScreen extends ConsumerStatefulWidget {
  final TvDevice tv;

  const RemoteScreen({super.key, required this.tv});

  @override
  ConsumerState<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends ConsumerState<RemoteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remoteProvider(widget.tv.ip).notifier).connect();
    });
  }

  @override
  void dispose() {
    ref.read(remoteProvider(widget.tv.ip).notifier).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteProvider(widget.tv.ip));
    final remote = ref.read(remoteProvider(widget.tv.ip).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tv.name),
        actions: [
          _StatusChip(status: state.status),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            if (state.isPairing)
              _PairingBanner(),
            if (state.isError)
              _ErrorBanner(onRetry: remote.connect),

            // ── Power ──
            Center(
              child: RemoteButton(
                color: const Color(0xFF8B0000),
                size: 60,
                onPressed: state.isActive ? remote.powerOff : null,
                child: const Icon(Icons.power_settings_new,
                    color: Colors.white, size: 28),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // ── Volume / Mute / Channel ──
            const _SectionLabel('Volume & Channel'),
            _VolumeChannelGrid(remote: remote, enabled: state.isActive),

            const Divider(),

            // ── D-Pad ──
            const _SectionLabel('Navigation'),
            _DPad(remote: remote, enabled: state.isActive),
            const SizedBox(height: 10),

            // ── Back / Home ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RemoteButton(
                  width: 80,
                  size: 44,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF2A2A4A),
                  onPressed: state.isActive ? () => remote.key('BACK') : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('BACK'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                RemoteButton(
                  width: 80,
                  size: 44,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF2A2A4A),
                  onPressed: state.isActive ? () => remote.key('HOME') : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('HOME'),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(),

            // ── Playback ──
            const _SectionLabel('Playback'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  onPressed: state.isActive ? () => remote.key('REWIND') : null,
                  child: const Icon(Icons.fast_rewind,
                      color: Colors.white70, size: 22),
                ),
                const SizedBox(width: 12),
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  size: 58,
                  onPressed: state.isActive ? () => remote.key('PLAY') : null,
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  onPressed: state.isActive ? () => remote.key('PAUSE') : null,
                  child: const Icon(Icons.pause,
                      color: Colors.white70, size: 22),
                ),
                const SizedBox(width: 12),
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  onPressed:
                      state.isActive ? () => remote.key('FASTFORWARD') : null,
                  child: const Icon(Icons.fast_forward,
                      color: Colors.white70, size: 22),
                ),
              ],
            ),

            const Divider(),

            // ── Number Pad ──
            const _SectionLabel('Keypad'),
            _NumberPad(remote: remote, enabled: state.isActive),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final SsapStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SsapStatus.ready => ('Ready', Colors.blue),
      SsapStatus.connected => ('Connected', Colors.green),
      SsapStatus.pairing => ('Pairing…', Colors.orange),
      SsapStatus.connecting => ('Connecting…', Colors.amber),
      SsapStatus.error => ('Error', Colors.red),
      SsapStatus.disconnected => ('Offline', Colors.grey),
    };
    return Chip(
      label: Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _PairingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.tv, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Accept the pairing prompt on your TV screen',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Connection failed',
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _VolumeChannelGrid extends StatelessWidget {
  final RemoteNotifier remote;
  final bool enabled;
  const _VolumeChannelGrid({required this.remote, required this.enabled});

  @override
  Widget build(BuildContext context) {
    btn(Widget child, VoidCallback? fn, Color c) => RemoteButton(
          color: c,
          onPressed: enabled ? fn : null,
          child: child,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(children: [
          btn(const Text('VOL+'), remote.volumeUp, const Color(0xFF0D2A5C)),
          const SizedBox(height: 8),
          btn(const Text('VOL-'), remote.volumeDown, const Color(0xFF0D2A5C)),
        ]),
        const SizedBox(width: 16),
        btn(
          const Icon(Icons.volume_off, color: Colors.white70, size: 20),
          enabled ? () => remote.key('MUTE') : null,
          const Color(0xFF2A0D4E),
        ),
        const SizedBox(width: 16),
        Column(children: [
          btn(const Text('CH+'), remote.channelUp, const Color(0xFF0D3D1A)),
          const SizedBox(height: 8),
          btn(const Text('CH-'), remote.channelDown, const Color(0xFF0D3D1A)),
        ]),
      ],
    );
  }
}

class _DPad extends StatelessWidget {
  final RemoteNotifier remote;
  final bool enabled;
  const _DPad({required this.remote, required this.enabled});

  @override
  Widget build(BuildContext context) {
    btn(Widget child, String key, [Color? color]) => RemoteButton(
          color: color ?? const Color(0xFF1E1E3A),
          onPressed: enabled ? () => remote.key(key) : null,
          child: child,
        );

    const gap = SizedBox(width: 8, height: 8);
    const blank = SizedBox(width: 52, height: 52);

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          blank,
          gap,
          btn(const Icon(Icons.keyboard_arrow_up, size: 28), 'UP'),
          gap,
          blank,
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          btn(const Icon(Icons.keyboard_arrow_left, size: 28), 'LEFT'),
          gap,
          btn(const Text('OK',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              'ENTER',
              const Color(0xFF4A148C)),
          gap,
          btn(const Icon(Icons.keyboard_arrow_right, size: 28), 'RIGHT'),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          blank,
          gap,
          btn(const Icon(Icons.keyboard_arrow_down, size: 28), 'DOWN'),
          gap,
          blank,
        ]),
      ],
    );
  }
}

class _NumberPad extends StatelessWidget {
  final RemoteNotifier remote;
  final bool enabled;
  const _NumberPad({required this.remote, required this.enabled});

  @override
  Widget build(BuildContext context) {
    btn(String n) => RemoteButton(
          color: const Color(0xFF16162A),
          onPressed: enabled ? () => remote.key(n) : null,
          child: Text(n,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70)),
        );

    const gap = SizedBox(width: 10, height: 10);

    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              btn(row[0]),
              gap,
              btn(row[1]),
              gap,
              btn(row[2]),
            ],
          ),
          gap,
        ],
        btn('0'),
      ],
    );
  }
}
