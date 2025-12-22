import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'core/storage.dart';
import 'core/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/background_refresh_service.dart';
import 'providers/auth_provider.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Set background message handler (defined in notification_service.dart)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
      child: const AppLifecycleManager(
        child: XperienceGamingApp(),
      ),
    ),
  );
}

/// App Lifecycle Manager - Pauses/resumes background refresh based on app state
class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;
  
  const AppLifecycleManager({super.key, required this.child});
  
  @override
  ConsumerState<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager> 
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final refreshService = ref.read(backgroundRefreshServiceProvider);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - resume refresh
        if (ref.read(isAuthenticatedProvider)) {
          refreshService.start();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App went to background - pause refresh to save battery
        refreshService.stop();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Main App Widget
class XperienceGamingApp extends ConsumerWidget {
  const XperienceGamingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    // Initialize background refresh service (starts automatically when authenticated)
    ref.watch(backgroundRefreshServiceProvider);

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

