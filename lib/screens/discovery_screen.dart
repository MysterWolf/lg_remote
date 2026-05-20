import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/saved_tv.dart';
import '../models/tv_device.dart';
import '../providers/discovery_provider.dart';
import '../providers/remote_provider.dart';
import '../providers/saved_tvs_provider.dart';
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

  void _selectSavedTv(SavedTv saved) {
    ref.read(savedTvsProvider.notifier).updateLastSeen(saved.ip);
    _selectTv(TvDevice(name: saved.name, ip: saved.ip));
  }

  // Returns the suggested pre-fill name for the save bottom sheet.
  // Falls back to the IP when the name is a generated placeholder.
  String _suggestedName(TvDevice tv) {
    if (tv.name == 'LG TV' || tv.name == 'LG TV (${tv.ip})') return tv.ip;
    return tv.name;
  }

  // ── Save bottom sheet ────────────────────────────────

  void _showSaveSheet(
      BuildContext context, {
      required String ip,
      required String suggestedName,
    }) {
    final ctrl = TextEditingController(text: suggestedName);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Save TV',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _commitSave(ctx, ctrl, ip),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _commitSave(ctx, ctrl, ip),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _commitSave(
      BuildContext sheetCtx, TextEditingController ctrl, String ip) {
    final name = ctrl.text.trim();
    ref.read(savedTvsProvider.notifier).add(SavedTv(
          ip: ip,
          name: name.isEmpty ? ip : name,
          lastSeen: DateTime.now(),
        ));
    Navigator.pop(sheetCtx);
  }

  // ── Rename dialog ────────────────────────────────────

  void _showRenameDialog(BuildContext context, SavedTv tv) {
    final ctrl = TextEditingController(text: tv.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename TV'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(savedTvsProvider.notifier).rename(tv.ip, name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Delete confirmation ──────────────────────────────

  void _confirmDelete(BuildContext context, SavedTv tv) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove saved TV?'),
        content: Text('Remove "${tv.name}" from your saved TVs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(savedTvsProvider.notifier).remove(tv.ip);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryProvider);
    final notifier = ref.read(discoveryProvider.notifier);
    final savedTvs = ref.watch(savedTvsProvider);
    final scanning = state.status == ScanStatus.scanning;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DPad Pilot'),
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
          // ── Saved TVs section ──
          if (savedTvs.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'SAVED',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
            for (final tv in savedTvs)
              ListTile(
                leading: const Icon(Icons.tv),
                title: Text(tv.name),
                subtitle: Text(
                  tv.ip,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Rename',
                      onPressed: () => _showRenameDialog(context, tv),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.redAccent),
                      tooltip: 'Remove',
                      onPressed: () => _confirmDelete(context, tv),
                    ),
                  ],
                ),
                onTap: () => _selectSavedTv(tv),
              ),
            const Divider(height: 1),
          ],

          // ── SSDP scan results ──
          Expanded(
            child: state.devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tv_off,
                            size: 64,
                            color: cs.onSurface.withValues(alpha: 0.2)),
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
                : Builder(builder: (context) {
                    final unsaved = state.devices
                        .where((d) => !savedTvs.any((s) => s.ip == d.ip))
                        .toList();
                    if (unsaved.isEmpty) {
                      return Center(
                        child: Text(
                          'No new TVs found',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                      );
                    }
                    return ListView.builder(
                    itemCount: unsaved.length,
                    itemBuilder: (_, i) {
                      final tv = unsaved[i];
                      return ListTile(
                        leading: const Icon(Icons.tv),
                        title: Text(tv.name),
                        subtitle: Text(
                          tv.ip,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.bookmark_border, size: 20),
                              tooltip: 'Save TV',
                              onPressed: () => _showSaveSheet(
                                context,
                                ip: tv.ip,
                                suggestedName: _suggestedName(tv),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _selectTv(tv),
                      );
                    },
                  );
                }),
          ),

          const Divider(height: 1),

          // ── Manual IP entry ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Manual IP',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      tooltip: 'Save TV',
                      onPressed: () {
                        final ip = _ipController.text.trim();
                        if (ip.isEmpty) return;
                        _showSaveSheet(context, ip: ip, suggestedName: ip);
                      },
                    ),
                    const SizedBox(width: 4),
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
