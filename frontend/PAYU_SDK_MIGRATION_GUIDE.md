# PayU SDK Migration Guide - WebView to PayU CheckoutPro Flutter SDK

## Executive Summary

This guide documents the complete migration from WebView-based PayU payment integration to the official PayU CheckoutPro Flutter SDK. This eliminates CORS/ORB errors and provides a native payment experience.

## Current Implementation Analysis

### Files Using WebView:
1. **`lib/screens/client/payment/payment_screen.dart`** - Main payment screen with WebView (498 lines)
2. **`lib/services/payment_service.dart`** - Payment service with HTML form generation
3. **`pubspec.yaml`** - Contains `webview_flutter: ^4.4.2` dependency

### Current Payment Flow:
1. User creates booking → Backend generates transaction ID and hash
2. Frontend receives payment URL and parameters
3. Frontend generates HTML form with payment data
4. WebView loads HTML form and auto-submits to PayU
5. PayU processes payment and redirects to callback URLs
6. **ISSUE**: ERR_BLOCKED_BY_ORB error blocks redirects in WebView

## Step 1: SDK Compatibility Check

### Current Flutter/Dart Version:
- **Flutter SDK**: `>=3.2.0 <4.0.0` ✅
- **Dart Version**: Compatible with Flutter 3.2.0+ ✅

### PayU CheckoutPro Flutter SDK Requirements:
- **Package**: `payu_checkoutpro_flutter`
- **Minimum Flutter**: 2.0.0+ ✅ (Compatible)
- **Minimum Android**: API 19+ (Android 4.4)
- **Minimum iOS**: 11.0+

**✅ Your project is compatible with PayU CheckoutPro Flutter SDK**

## Step 2: Add PayU SDK Dependency

### Update `pubspec.yaml`:

```yaml
dependencies:
  # ... existing dependencies ...
  
  # Payment - PayU Integration (REPLACE webview_flutter)
  payu_checkoutpro_flutter: ^1.0.0  # Check latest version on pub.dev
  
  # Remove this line:
  # webview_flutter: ^4.4.2
```

### Install Dependencies:
```bash
cd frontend
flutter pub get
```

## Step 3: Android Native Configuration

### Update `android/app/build.gradle.kts`:

Ensure minimum SDK version:
```kotlin
defaultConfig {
    minSdk = 19  // PayU requires at least API 19
    // ... other config
}
```

### AndroidManifest.xml:
Already has internet permission ✅ (line 4)

## Step 4: iOS Native Configuration

### Update `ios/Podfile`:
```ruby
platform :ios, '11.0'
```

### Install Pods:
```bash
cd ios
pod install
cd ..
```

## Step 5: Backend API Modification

The backend response structure is already compatible! We just need to ensure it doesn't require `paymentUrl` for SDK usage.

**Current Backend Response** (Already compatible):
```json
{
  "success": true,
  "data": {
    "key": "pAHJAw",
    "txnid": "TXN1765944554303",
    "amount": "2.00",
    "productinfo": "Booking DbIe5Z85C8uQKlhorrlQ",
    "firstname": "Mohit",
    "email": "mohitsagar378@gmail.com",
    "phone": "9555424388",
    "surl": "https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/success",
    "furl": "https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/failure",
    "curl": "https://asia-south1-xperience-gaming.cloudfunctions.net/api/payments/cancel",
    "hash": "generated_hash",
    "service_provider": "payu_paisa",
    "bookingId": "DbIe5Z85C8uQKlhorrlQ"
  }
}
```

**Note**: The `paymentUrl` field can be removed from backend response (optional for SDK).

## Step 6: Implementation Steps

See the code files created in the next steps for complete implementation.

## Important Notes

1. **Security**: Never expose PayU merchant salt to client - hash generation stays on backend ✅
2. **Verification**: Always verify payment on backend before confirming booking
3. **Testing**: Test thoroughly in PayU test mode before going live
4. **Backup**: Keep old WebView code in a git branch before deletion

## Expected Benefits

✅ No more CORS/ORB errors  
✅ Native payment UI - better UX  
✅ Supports all payment methods (Cards, UPI, Wallets, NetBanking)  
✅ More reliable payment flow  
✅ Better error handling  
✅ Consistent experience across platforms  
