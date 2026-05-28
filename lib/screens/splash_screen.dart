import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/saved_tv.dart';
import '../models/tv_device.dart';
import '../providers/saved_tvs_provider.dart';
import '../services/saved_tvs_service.dart';
import 'discovery_screen.dart';
import 'remote_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    List<SavedTv> savedTvs = [];
    await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      () async { savedTvs = await SavedTvsService().load(); }(),
    ]);
    if (!mounted) return;
    ref.read(savedTvsProvider.notifier).init(savedTvs);
    _navigate(savedTvs);
  }

  void _navigate(List<SavedTv> savedTvs) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) {
          if (savedTvs.length == 1) {
            final saved = savedTvs.first;
            final tv = TvDevice(name: saved.name, ip: saved.ip);
            return RemoteScreen(
              tv: tv,
              onSwitchTv: () => Navigator.of(ctx).pushReplacement(
                MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
              ),
            );
          }
          return const DiscoveryScreen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/mws_mark_dark.png',
              width: 120,
              height: 120,
            ),
            SizedBox(height: 20),
            Text(
              'mysterwolf',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: Color(0xFFCDD6F4),
                letterSpacing: 2.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'studios',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6C7086),
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 36),
            Text(
              'A simple LG TV remote.\nNo ads, no subscriptions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF585B70),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
