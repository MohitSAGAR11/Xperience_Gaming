import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'core/storage.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.trueBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();

  // Run the app
  runApp(
    ProviderScope(
      overrides: [
        // Override shared preferences provider with actual instance
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const XperienceGamingApp(),
    ),
  );
}

/// Main App Widget
class XperienceGamingApp extends ConsumerWidget {
  const XperienceGamingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'XPerience Gaming',
      debugShowCheckedModeBanner: false,
      
      // Theme
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      
      // Router
      routerConfig: router,
    );
  }
}

