# Push Notifications Setup Guide
## For Cafe Booking Notifications

### Overview
When a user books a slot at a cafe, the cafe owner will receive a push notification (like WhatsApp).

---

## Part 1: Backend Setup (Node.js/Express)

### Step 1.1: Install Required Package
```bash
cd backend
npm install firebase-admin
# (You likely already have this installed)
```

### Step 1.2: Update User Model to Store FCM Tokens

Add `fcmToken` field to users collection in Firestore:
```javascript
// User document structure
{
  id: "userId",
  name: "John Doe",
  email: "john@example.com",
  role: "owner" | "client",
  fcmToken: "device-specific-token-here", // NEW FIELD
  // ... other fields
}
```

### Step 1.3: Create Notification Service

Create: `backend/src/services/notificationService.js`

```javascript
const admin = require('firebase-admin');
const { db } = require('../config/firebase');

/**
 * Send push notification to a user
 * @param {string} userId - User ID to send notification to
 * @param {Object} notification - Notification data
 * @param {string} notification.title - Notification title
 * @param {string} notification.body - Notification body
 * @param {Object} notification.data - Additional data payload
 */
const sendNotificationToUser = async (userId, notification) => {
  try {
    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log('User not found:', userId);
      return { success: false, error: 'User not found' };
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log('User has no FCM token:', userId);
      return { success: false, error: 'No FCM token' };
    }

    // Prepare the message
    const message = {
      token: fcmToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: notification.data || {},
      // Android specific options
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'booking_notifications',
          priority: 'high',
        },
      },
      // iOS specific options
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Send the notification
    const response = await admin.messaging().send(message);
    
    console.log('📬 Notification sent successfully:', response);
    return { success: true, messageId: response };
    
  } catch (error) {
    console.error('📬 Error sending notification:', error);
    
    // If token is invalid, remove it from user document
    if (error.code === 'messaging/invalid-registration-token' || 
        error.code === 'messaging/registration-token-not-registered') {
      await db.collection('users').doc(userId).update({
        fcmToken: null
      });
    }
    
    return { success: false, error: error.message };
  }
};

/**
 * Send notification to multiple users
 */
const sendNotificationToMultipleUsers = async (userIds, notification) => {
  const results = await Promise.all(
    userIds.map(userId => sendNotificationToUser(userId, notification))
  );
  return results;
};

/**
 * Create booking notification for cafe owner
 */
const sendBookingNotification = async (booking, cafe, user) => {
  try {
    const ownerId = cafe.ownerId;
    
    const notification = {
      title: `New Booking at ${cafe.name}`,
      body: `${user.name} booked ${booking.stationType === 'pc' ? 'PC' : booking.consoleType} #${booking.stationNumber} for ${booking.bookingDate}`,
      data: {
        type: 'NEW_BOOKING',
        bookingId: booking.id,
        cafeId: cafe.id,
        userId: user.id,
        bookingDate: booking.bookingDate,
        startTime: booking.startTime,
        endTime: booking.endTime,
      },
    };

    return await sendNotificationToUser(ownerId, notification);
  } catch (error) {
    console.error('Error sending booking notification:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Create booking cancellation notification
 */
const sendBookingCancellationNotification = async (booking, cafe, user) => {
  try {
    const ownerId = cafe.ownerId;
    
    const notification = {
      title: `Booking Cancelled at ${cafe.name}`,
      body: `${user.name} cancelled booking for ${booking.bookingDate}`,
      data: {
        type: 'BOOKING_CANCELLED',
        bookingId: booking.id,
        cafeId: cafe.id,
        userId: user.id,
      },
    };

    return await sendNotificationToUser(ownerId, notification);
  } catch (error) {
    console.error('Error sending cancellation notification:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Create review notification for cafe owner
 */
const sendReviewNotification = async (review, cafe, user) => {
  try {
    const ownerId = cafe.ownerId;
    
    const notification = {
      title: `New Review for ${cafe.name}`,
      body: `${user.name} left a ${review.rating}-star review`,
      data: {
        type: 'NEW_REVIEW',
        reviewId: review.id,
        cafeId: cafe.id,
        userId: user.id,
        rating: review.rating.toString(),
      },
    };

    return await sendNotificationToUser(ownerId, notification);
  } catch (error) {
    console.error('Error sending review notification:', error);
    return { success: false, error: error.message };
  }
};

module.exports = {
  sendNotificationToUser,
  sendNotificationToMultipleUsers,
  sendBookingNotification,
  sendBookingCancellationNotification,
  sendReviewNotification,
};
```

### Step 1.4: Create API Endpoint to Register FCM Token

Create/update: `backend/src/controllers/authController.js`

Add this function:

```javascript
/**
 * @desc    Register FCM token for push notifications
 * @route   POST /api/auth/register-fcm-token
 * @access  Private
 */
const registerFcmToken = async (req, res) => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user.id;

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required'
      });
    }

    // Update user document with FCM token
    await db.collection('users').doc(userId).update({
      fcmToken,
      fcmTokenUpdatedAt: new Date()
    });

    console.log('📱 FCM token registered for user:', userId);

    res.json({
      success: true,
      message: 'FCM token registered successfully'
    });

  } catch (error) {
    console.error('Register FCM token error:', error);
    res.status(500).json({
      success: false,
      message: 'Error registering FCM token'
    });
  }
};

// Don't forget to export it
module.exports = {
  // ... existing exports
  registerFcmToken
};
```

### Step 1.5: Add Route for FCM Token Registration

In `backend/src/routes/authRoutes.js`:

```javascript
const { 
  // ... existing imports
  registerFcmToken 
} = require('../controllers/authController');

// Add this route (after protect middleware)
router.post('/register-fcm-token', protect, registerFcmToken);
```

### Step 1.6: Update Booking Controller to Send Notifications

In `backend/src/controllers/bookingController.js`:

Add import at top:
```javascript
const notificationService = require('../services/notificationService');
```

In the `createBooking` function, after successfully creating the booking:

```javascript
// After booking is created successfully (around line 440)

// Send notification to cafe owner
try {
  await notificationService.sendBookingNotification(
    booking,
    cafeData,
    userData
  );
  console.log('📬 Notification sent to cafe owner');
} catch (notificationError) {
  // Don't fail the booking if notification fails
  console.error('📬 Failed to send notification:', notificationError);
}

res.status(201).json({
  success: true,
  message: 'Booking confirmed successfully',
  // ... rest of response
});
```

Similarly, add to `cancelBooking` function:

```javascript
// After booking is cancelled (around line 850)

// Get cafe and user data
const cafe = await getCafeData(booking.cafeId);
const user = await getUserData(booking.userId);

// Send cancellation notification to owner
try {
  await notificationService.sendBookingCancellationNotification(
    booking,
    cafe,
    user
  );
  console.log('📬 Cancellation notification sent to cafe owner');
} catch (notificationError) {
  console.error('📬 Failed to send cancellation notification:', notificationError);
}
```

---

## Part 2: Frontend Setup (Flutter)

### Step 2.1: Add Required Packages

In `frontend/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Add these:
  firebase_messaging: ^14.7.10
  flutter_local_notifications: ^16.3.2
  permission_handler: ^11.3.0
```

Then run:
```bash
cd frontend
flutter pub get
```

### Step 2.2: Configure Android

#### A. Update `frontend/android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        // Add this
        minSdkVersion 21  // Make sure it's at least 21
    }
}
```

#### B. Update `frontend/android/app/src/main/AndroidManifest.xml`:

Add these inside `<application>` tag:

```xml
<application>
    <!-- ... existing code ... -->
    
    <!-- Firebase Messaging -->
    <service
        android:name="io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService"
        android:exported="false">
        <intent-filter>
            <action android:name="com.google.firebase.MESSAGING_EVENT" />
        </intent-filter>
    </service>
    
    <!-- Notification channel (for Android 8.0+) -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="booking_notifications" />
        
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@drawable/ic_notification" />
</application>

<!-- Add permissions outside <application> -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### Step 2.3: Create Notification Service

Create: `frontend/lib/services/notification_service.dart`

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

import '../core/api_client.dart';
import '../config/constants.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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
      print('📬 FCM Token: $token');
      await _registerTokenWithBackend(token);
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
      _handleNotificationTap(initialMessage);
    }

    print('📬 NotificationService initialized successfully');
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
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
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
      final response = await _apiClient.post(
        '/auth/register-fcm-token',
        data: {'fcmToken': token},
      );

      if (response.isSuccess) {
        print('📬 FCM token registered with backend');
      } else {
        print('📬 Failed to register FCM token: ${response.message}');
      }
    } catch (e) {
      print('📬 Error registering FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📬 Foreground message received: ${message.messageId}');
    print('📬 Title: ${message.notification?.title}');
    print('📬 Body: ${message.notification?.body}');
    print('📬 Data: ${message.data}');

    // Show local notification
    _showLocalNotification(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'booking_notifications',
      'Booking Notifications',
      channelDescription: 'Notifications for new bookings and updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
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

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('📬 Notification tapped: ${message.data}');
    
    final data = message.data;
    final type = data['type'];

    // Navigate based on notification type
    switch (type) {
      case 'NEW_BOOKING':
        // Navigate to booking details
        print('📬 Navigate to booking: ${data['bookingId']}');
        // TODO: Implement navigation
        break;
      case 'BOOKING_CANCELLED':
        // Navigate to bookings list
        print('📬 Navigate to bookings list');
        // TODO: Implement navigation
        break;
      case 'NEW_REVIEW':
        // Navigate to cafe reviews
        print('📬 Navigate to cafe: ${data['cafeId']}');
        // TODO: Implement navigation
        break;
      default:
        print('📬 Unknown notification type: $type');
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('📬 Local notification tapped: ${response.payload}');
    // Handle navigation
  }

  /// Unregister FCM token (call on logout)
  Future<void> unregisterToken() async {
    try {
      await _apiClient.post(
        '/auth/register-fcm-token',
        data: {'fcmToken': null},
      );
      await _messaging.deleteToken();
      print('📬 FCM token unregistered');
    } catch (e) {
      print('📬 Error unregistering token: $e');
    }
  }
}

/// Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationService(apiClient);
});
```

### Step 2.4: Initialize Notification Service in main.dart

In `frontend/lib/main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';

// Add this at the top level (outside main)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Initialize notifications after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<void> _initializeNotifications() async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    // ... your existing build method
  }
}
```

### Step 2.5: Handle Notification Permissions on Login

In your login success handler, initialize notifications:

```dart
// After successful login
final notificationService = ref.read(notificationServiceProvider);
await notificationService.initialize();
```

---

## Part 3: Testing

### Test Scenario 1: New Booking Notification

1. **Login as Owner** (on one device/emulator)
2. **Login as Client** (on another device/emulator or web)
3. **Client creates a booking** at owner's cafe
4. **Owner should receive notification** 📬

### Test Scenario 2: Booking Cancellation

1. **Client cancels a booking**
2. **Owner receives cancellation notification**

### Backend Logs to Check:
```
📬 Notification sent successfully: projects/.../messages/...
```

### Frontend Logs to Check:
```
📬 FCM Token: ey...
📬 FCM token registered with backend
📬 Foreground message received: ...
```

---

## Part 4: Troubleshooting

### Issue: No notifications received

**Check:**
1. FCM token registered? Check backend logs
2. Notification permissions granted?
3. Backend sending notification? Check logs
4. Firebase project configured correctly?

### Issue: Notifications work on Android but not iOS

**Solution:** iOS requires additional setup in Apple Developer Console and APNs certificates.

### Issue: Notifications don't show when app is in foreground

**Solution:** That's by design. We show local notification instead. Check `_showLocalNotification` is being called.

---

## Part 5: Production Considerations

1. **Notification Preferences**: Let users enable/disable notification types
2. **Notification History**: Store notifications in database
3. **Badge Count**: Update app badge with unread count
4. **Sound Customization**: Different sounds for different notification types
5. **Rich Notifications**: Add images, actions, etc.
6. **Analytics**: Track notification delivery and engagement

---

## Summary Checklist

### Backend ✓
- [ ] Install firebase-admin
- [ ] Create notificationService.js
- [ ] Add FCM token registration endpoint
- [ ] Update bookingController to send notifications
- [ ] Add fcmToken field to users

### Frontend ✓
- [ ] Add firebase_messaging dependency
- [ ] Create notification_service.dart
- [ ] Initialize in main.dart
- [ ] Configure AndroidManifest.xml
- [ ] Test on real device

### Testing ✓
- [ ] Test new booking notification
- [ ] Test cancellation notification
- [ ] Test notification tap navigation
- [ ] Test foreground/background/terminated states

---

That's it! You now have WhatsApp-style push notifications for bookings! 🎉

