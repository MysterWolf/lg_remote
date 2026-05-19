import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/saved_tv.dart';
import 'models/tv_device.dart';
import 'providers/saved_tvs_provider.dart';
import 'screens/discovery_screen.dart';
import 'screens/remote_screen.dart';
import 'services/saved_tvs_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final svc = SavedTvsService();
  final initial = await svc.load();
  runApp(
    ProviderScope(
      overrides: [
        savedTvsProvider
            .overrideWith((_) => SavedTvsNotifier(svc, initial: initial)),
      ],
      child: LgRemoteApp(initialSavedTvs: initial),
    ),
  );
}

class LgRemoteApp extends StatelessWidget {
  final List<SavedTv> initialSavedTvs;

  const LgRemoteApp({super.key, required this.initialSavedTvs});

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (initialSavedTvs.length == 1) {
      final saved = initialSavedTvs.first;
      final tv = TvDevice(name: saved.name, ip: saved.ip);
      home = Builder(
        builder: (ctx) => RemoteScreen(
          tv: tv,
          onSwitchTv: () => Navigator.of(ctx).pushReplacement(
            MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
          ),
        ),
      );
    } else {
      home = const DiscoveryScreen();
    }

    return MaterialApp(
      title: 'LG Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B82FF),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF1E1E2E),
          onSurface: const Color(0xFFCDD6F4),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F1A),
          foregroundColor: Color(0xFFCDD6F4),
          elevation: 0,
        ),
      ),
      home: home,
    );
  }
}
