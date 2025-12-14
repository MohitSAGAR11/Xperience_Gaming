import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;

import '../core/api_client.dart';
import '../config/constants.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Background message received: ${message.messageId}');
  print('📬 Title: ${message.notification?.title}');
  print('📬 Body: ${message.notification?.body}');
}

/// Notification Service for push notifications
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  /// Initialize notification service
  Future<void> initialize() async {
    print('📬 Initializing NotificationService...');

    try {
      // Request permissions
      final settings = await _requestPermissions();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('📬 Notification permission denied');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token and register with backend
      final token = await _messaging.getToken();
      if (token != null) {
        print('📬 FCM Token obtained: ${token.substring(0, 20)}...');
        await _registerTokenWithBackend(token);
      } else {
        print('📬 Failed to get FCM token');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen(_registerTokenWithBackend);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('📬 App opened from notification');
        _handleNotificationTap(initialMessage);
      }

      print('📬 NotificationService initialized successfully ✓');
    } catch (e) {
      print('📬 Error initializing NotificationService: $e');
    }
  }

  /// Request notification permissions
  Future<NotificationSettings> _requestPermissions() async {
    return await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    final androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      final channel = AndroidNotificationChannel(
        'booking_notifications',
        'Booking Notifications',
        description: 'Notifications for new bookings and updates',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Register FCM token with backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      print('📬 Registering FCM token with backend...');
      
      final response = await _apiClient.post(
        '/auth/register-fcm-token',
        data: {'fcmToken': token},
      );

      if (response.isSuccess) {
        print('📬 FCM token registered with backend ✓');
      } else {
        print('📬 Failed to register FCM token: ${response.message}');
      }
    } catch (e) {
      print('📬 Error registering FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 ========================================');
    print('📬 Foreground message received!');
    print('📬 Message ID: ${message.messageId}');
    print('📬 Title: ${message.notification?.title}');
    print('📬 Body: ${message.notification?.body}');
    print('📬 Data: ${message.data}');
    print('📬 ========================================');

    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) {
      print('📬 No notification payload, skipping local notification');
      return;
    }

    print('📬 Showing local notification: ${notification.title}');

    final androidDetails = AndroidNotificationDetails(
      'booking_notifications',
      'Booking Notifications',
      channelDescription: 'Notifications for new bookings and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap (from FCM)
  void _handleNotificationTap(RemoteMessage message) {
    print('📬 ========================================');
    print('📬 Notification tapped!');
    print('📬 Data: ${message.data}');
    print('📬 ========================================');
    
    final data = message.data;
    final type = data['type'];

    // Navigate based on notification type
    _navigateBasedOnType(type, data);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('📬 Local notification tapped');
    print('📬 Payload: ${response.payload}');
    
    // TODO: Parse payload and navigate
  }

  /// Navigate based on notification type
  void _navigateBasedOnType(String? type, Map<String, dynamic> data) {
    switch (type) {
      case 'NEW_BOOKING':
        print('📬 Navigate to booking details: ${data['bookingId']}');
        // TODO: Implement navigation
        // context.push('/owner/bookings/${data['bookingId']}');
        break;
        
      case 'BOOKING_CANCELLED':
        print('📬 Navigate to bookings list');
        // TODO: Implement navigation
        // context.push('/owner/bookings');
        break;
        
      case 'BOOKING_STATUS_UPDATE':
        print('📬 Navigate to my bookings: ${data['bookingId']}');
        // TODO: Implement navigation
        // context.push('/client/my-bookings/${data['bookingId']}');
        break;
        
      case 'NEW_REVIEW':
        print('📬 Navigate to cafe reviews: ${data['cafeId']}');
        // TODO: Implement navigation
        // context.push('/cafes/${data['cafeId']}?tab=reviews');
        break;
        
      default:
        print('📬 Unknown notification type: $type');
    }
  }

  /// Unregister FCM token (call on logout)
  Future<void> unregisterToken() async {
    try {
      print('📬 Unregistering FCM token...');
      
      await _apiClient.post(
        '/auth/register-fcm-token',
        data: {'fcmToken': null},
      );
      
      await _messaging.deleteToken();
      
      print('📬 FCM token unregistered ✓');
    } catch (e) {
      print('📬 Error unregistering token: $e');
    }
  }

  /// Test notification (for debugging)
  Future<void> showTestNotification() async {
    print('📬 Showing test notification');
    
    final androidDetails = AndroidNotificationDetails(
      'booking_notifications',
      'Booking Notifications',
      channelDescription: 'Notifications for new bookings and updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      0,
      'Test Notification',
      'This is a test notification from XPerience Gaming!',
      details,
    );
  }
}

/// Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationService(apiClient);
});

