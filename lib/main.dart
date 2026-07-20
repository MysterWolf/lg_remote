import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'services/overlay_bridge_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  OverlayBridgeService.instance.init();
  runApp(const ProviderScope(child: LgRemoteApp()));
}

class LgRemoteApp extends StatelessWidget {
  const LgRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const SplashScreen(),
    );
  }
}
