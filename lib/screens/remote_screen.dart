import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tv_device.dart';
import '../providers/remote_provider.dart';
import '../services/ssap_service.dart';
import '../widgets/remote_button.dart';
import 'about_screen.dart';

class RemoteScreen extends ConsumerStatefulWidget {
  final TvDevice tv;

  /// Non-null when launched via the single-TV fast path. Replaces the
  /// default back button with a labelled "Switch TV" action.
  final VoidCallback? onSwitchTv;

  const RemoteScreen({super.key, required this.tv, this.onSwitchTv});

  @override
  ConsumerState<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends ConsumerState<RemoteScreen> {
  bool _showKeyboard = false;

  Future<void> _handleSettings(
      BuildContext context, RemoteNotifier remote) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool found;
    try {
      found = await remote.launchSettings();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not query app list: $e')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings app not found on this TV')),
      );
    }
  }

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
    final state  = ref.watch(remoteProvider(widget.tv.ip));
    final remote = ref.read(remoteProvider(widget.tv.ip).notifier);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onSwitchTv == null,
        title: Text(widget.tv.name),
        actions: [
          if (widget.onSwitchTv != null)
            TextButton(
              onPressed: widget.onSwitchTv,
              child: const Text('Switch TV'),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          _StatusChip(status: state.status),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _AppLauncherBar(
        remote: remote,
        enabled: state.isActive,
      ),
      body: Column(
        children: [
          _PersistentTopBar(
            remote: remote,
            enabled: state.isActive,
            connectionState: state.connectionState,
            showKeyboard: _showKeyboard,
            onToggleKeyboard: () =>
                setState(() => _showKeyboard = !_showKeyboard),
            onSettings: () => _handleSettings(context, remote),
            onReconnect: remote.reconnect,
          ),
          if (state.isPairing) _PairingBanner(),
          if (state.isError) _ErrorBanner(onRetry: remote.connect),
          Expanded(
            child: _showKeyboard
                ? _QwertyKeyboard(remote: remote, enabled: state.isActive)
                : _RemoteSections(remote: remote, enabled: state.isActive),
          ),
        ],
      ),
    );
  }
}

// ── Persistent top bar ────────────────────────────────

class _PersistentTopBar extends StatelessWidget {
  final RemoteNotifier remote;
  final bool enabled;
  final TvConnectionState connectionState;
  final bool showKeyboard;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onSettings;
  final VoidCallback onReconnect;

  const _PersistentTopBar({
    required this.remote,
    required this.enabled,
    required this.connectionState,
    required this.showKeyboard,
    required this.onToggleKeyboard,
    required this.onSettings,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatusDot(connectionState: connectionState, onReconnect: onReconnect),
          RemoteButton(
            color: const Color(0xFF8B0000),
            size: 54,
            onPressed: enabled ? remote.powerOff : null,
            child: const Icon(Icons.power_settings_new,
                color: Colors.white, size: 26),
          ),
          RemoteButton(
            color: const Color(0xFF2A2A4A),
            size: 54,
            onPressed: enabled ? onSettings : null,
            child: const Icon(Icons.settings, color: Colors.white70, size: 22),
          ),
          RemoteButton(
            color: const Color(0xFF2A2A4A),
            size: 54,
            onPressed: onToggleKeyboard,
            child: Icon(
              showKeyboard ? Icons.tv_rounded : Icons.keyboard_alt_outlined,
              color: showKeyboard ? Colors.lightBlueAccent : Colors.white70,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status dot / reconnect button ─────────────────────

class _StatusDot extends StatelessWidget {
  final TvConnectionState connectionState;
  final VoidCallback onReconnect;

  const _StatusDot({required this.connectionState, required this.onReconnect});

  @override
  Widget build(BuildContext context) {
    final color = switch (connectionState) {
      TvConnectionState.connected   => Colors.greenAccent,
      TvConnectionState.connecting  => Colors.amber,
      TvConnectionState.disconnected => Colors.redAccent,
    };

    final dot = Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6),
        ],
      ),
    );

    // When connected: just the dot (no action needed).
    if (connectionState == TvConnectionState.connected) {
      return SizedBox(width: 54, height: 54, child: Center(child: dot));
    }

    // When connecting or disconnected: refresh button with a dot badge.
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RemoteButton(
            size: 54,
            color: const Color(0xFF2A2A4A),
            onPressed: onReconnect,
            child: const Icon(Icons.refresh, color: Colors.white70, size: 22),
          ),
          Positioned(
            right: 1,
            top: 1,
            child: dot,
          ),
        ],
      ),
    );
  }
}

// ── Collapsible remote sections ───────────────────────

class _RemoteSections extends StatelessWidget {
  final RemoteNotifier remote;
  final bool enabled;

  const _RemoteSections({required this.remote, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _CollapsibleSection(
            title: 'Volume & Channel',
            initiallyExpanded: false,
            child: _VolumeChannelGrid(remote: remote, enabled: enabled),
          ),
          _CollapsibleSection(
            title: 'Navigation',
            initiallyExpanded: true,
            child: Column(
              children: [
                _DPad(remote: remote, enabled: enabled),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RemoteButton(
                      width: 80,
                      size: 44,
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF2A2A4A),
                      onPressed:
                          enabled ? () => remote.key('BACK') : null,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back,
                              size: 16, color: Colors.white70),
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
                      onPressed:
                          enabled ? () => remote.key('HOME') : null,
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
              ],
            ),
          ),
          _CollapsibleSection(
            title: 'Playback',
            initiallyExpanded: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  onPressed:
                      enabled ? () => remote.key('REWIND') : null,
                  child: const Icon(Icons.fast_rewind,
                      color: Colors.white70, size: 22),
                ),
                const SizedBox(width: 12),
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  size: 58,
                  onPressed: enabled ? () => remote.key('PLAY') : null,
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  onPressed:
                      enabled ? () => remote.key('PAUSE') : null,
                  child: const Icon(Icons.pause,
                      color: Colors.white70, size: 22),
                ),
                const SizedBox(width: 12),
                RemoteButton(
                  color: const Color(0xFF1A2A1A),
                  onPressed:
                      enabled ? () => remote.key('FASTFORWARD') : null,
                  child: const Icon(Icons.fast_forward,
                      color: Colors.white70, size: 22),
                ),
              ],
            ),
          ),
          _CollapsibleSection(
            title: 'Keypad',
            initiallyExpanded: false,
            child: _NumberPad(remote: remote, enabled: enabled),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Collapsible section widget ────────────────────────

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _chevron;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: _expanded ? 1.0 : 0.0,
    );
    _chevron = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                const Spacer(),
                RotationTransition(
                  turns: _chevron,
                  child: Icon(Icons.expand_more, size: 18, color: labelColor),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: widget.child,
                )
              : const SizedBox.shrink(),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

// ── QWERTY keyboard ───────────────────────────────────

class _QwertyKeyboard extends StatelessWidget {
  final RemoteNotifier remote;
  final bool enabled;

  const _QwertyKeyboard({required this.remote, required this.enabled});

  static const _rows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Column(
        children: [
          ..._rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row
                    .map(
                      (k) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _KeyCap(
                          label: k,
                          onTap: enabled
                              ? () => remote.insertText(k)
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          // Space + backspace
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WideKey(
                  width: 190,
                  label: 'SPACE',
                  onTap: enabled ? () => remote.insertText(' ') : null,
                ),
                const SizedBox(width: 8),
                _WideKey(
                  width: 64,
                  icon: Icons.backspace_outlined,
                  color: const Color(0xFF2A1A1A),
                  onTap: enabled ? remote.deleteChar : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _KeyCap({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E3A),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        splashColor: Colors.white24,
        child: Container(
          width: 32,
          height: 44,
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _WideKey extends StatelessWidget {
  final double width;
  final String? label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  const _WideKey({
    required this.width,
    this.label,
    this.icon,
    this.color = const Color(0xFF1E1E3A),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white24,
        child: Container(
          width: width,
          height: 44,
          alignment: Alignment.center,
          child: label != null
              ? Text(label!,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                      letterSpacing: 1))
              : Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

// ── Unchanged sub-widgets ─────────────────────────────

class _StatusChip extends StatelessWidget {
  final SsapStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SsapStatus.ready        => ('Ready',        Colors.blue),
      SsapStatus.connected    => ('Connected',    Colors.green),
      SsapStatus.pairing      => ('Pairing…',     Colors.orange),
      SsapStatus.connecting   => ('Connecting…',  Colors.amber),
      SsapStatus.error        => ('Error',         Colors.red),
      SsapStatus.disconnected => ('Offline',       Colors.grey),
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
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
          color: c, onPressed: enabled ? fn : null, child: child);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(children: [
          btn(const Text('VOL+'), remote.volumeUp,   const Color(0xFF0D2A5C)),
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
          btn(const Text('CH+'), remote.channelUp,   const Color(0xFF0D3D1A)),
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
          child: child);

    const gap   = SizedBox(width: 8, height: 8);
    const blank = SizedBox(width: 52, height: 52);

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        blank, gap,
        btn(const Icon(Icons.keyboard_arrow_up, size: 28), 'UP'),
        gap, blank,
      ]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        btn(const Icon(Icons.keyboard_arrow_left,  size: 28), 'LEFT'),
        gap,
        btn(
          const Text('OK',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          'ENTER',
          const Color(0xFF4A148C),
        ),
        gap,
        btn(const Icon(Icons.keyboard_arrow_right, size: 28), 'RIGHT'),
      ]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        blank, gap,
        btn(const Icon(Icons.keyboard_arrow_down, size: 28), 'DOWN'),
        gap, blank,
      ]),
    ]);
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
                  color: Colors.white70)));

    const gap = SizedBox(width: 10, height: 10);

    return Column(children: [
      for (final row in [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ]) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [btn(row[0]), gap, btn(row[1]), gap, btn(row[2])],
        ),
        gap,
      ],
      btn('0'),
    ]);
  }
}

// ── App launcher bar ──────────────────────────────────

class _AppLauncherBar extends StatelessWidget {
  final RemoteNotifier remote;
  final bool enabled;

  const _AppLauncherBar({required this.remote, required this.enabled});

  Future<void> _launch(
    BuildContext context,
    List<String> terms,
    String appName,
  ) async {
    bool found;
    try {
      found = await remote.launchStreamingApp(terms);
    } catch (_) {
      found = false;
    }
    if (!found && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$appName not found on this TV')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF252538),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _AppButton(
                  label: 'Disney+',
                  enabled: enabled,
                  onTap: () => _launch(context, ['disney'], 'Disney+'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AppButton(
                  label: 'YouTube',
                  enabled: enabled,
                  onTap: () => _launch(context, ['youtube'], 'YouTube'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AppButton(
                  label: 'Amazon Prime',
                  enabled: enabled,
                  onTap: () => _launch(context, ['amazon', 'prime'], 'Amazon Prime'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _AppButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFF2A2A4A),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? cs.onSurface
                  : cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
