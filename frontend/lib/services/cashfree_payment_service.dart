import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';
import '../core/logger.dart';
import '../core/api_client.dart';
import '../config/constants.dart';

/// Cashfree Payment Service using Official Flutter SDK
/// The SDK manages WebView lifecycle internally
class CashfreePaymentService {
  final ApiClient _apiClient;
  final CFPaymentGatewayService _cfPaymentGatewayService = CFPaymentGatewayService();
  
  // Callbacks
  Function(String orderId)? _onPaymentSuccess;
  Function(String error, String? orderId)? _onPaymentError;
  
  bool _isInitialized = false;

  CashfreePaymentService(this._apiClient);

  /// Initialize the SDK with callbacks
  /// Must be called before starting any payment
  void initialize({
    required Function(String orderId) onPaymentSuccess,
    required Function(String error, String? orderId) onPaymentError,
  }) {
    AppLogger.d('💳 [CASHFREE_SDK] ========================================');
    AppLogger.d('💳 [CASHFREE_SDK] Initializing Cashfree Payment Gateway SDK');
    
    _onPaymentSuccess = onPaymentSuccess;
    _onPaymentError = onPaymentError;

    // Set SDK callbacks
    _cfPaymentGatewayService.setCallback(
      (String orderId) {
        AppLogger.d('💳 [CASHFREE_SDK] ========================================');
        AppLogger.d('💳 [CASHFREE_SDK] ✅ PAYMENT COMPLETED BY USER');
        AppLogger.d('💳 [CASHFREE_SDK] Order ID: $orderId');
        AppLogger.d('💳 [CASHFREE_SDK] SDK automatically closed payment screen');
        AppLogger.d('💳 [CASHFREE_SDK] Calling success callback...');
        AppLogger.d('💳 [CASHFREE_SDK] ========================================');
        
        // SDK has already closed the payment screen
        // Now verify payment with backend
        onPaymentSuccess(orderId);
      },
      (CFErrorResponse errorResponse, String orderId) {
        AppLogger.e('💳 [CASHFREE_SDK] ========================================');
        AppLogger.e('💳 [CASHFREE_SDK] ❌ PAYMENT FAILED');
        AppLogger.e('💳 [CASHFREE_SDK] Order ID: $orderId');
        final errorMessage = errorResponse.getMessage() ?? 'Payment failed';
        AppLogger.e('💳 [CASHFREE_SDK] Error Message: $errorMessage');
        AppLogger.e('💳 [CASHFREE_SDK] Error Status: ${errorResponse.getStatus()}');
        AppLogger.e('💳 [CASHFREE_SDK] SDK automatically closed payment screen');
        AppLogger.e('💳 [CASHFREE_SDK] ========================================');
        
        // SDK has already closed the payment screen
        onPaymentError(errorMessage, orderId);
      },
    );

    _isInitialized = true;
    AppLogger.d('💳 [CASHFREE_SDK] ✅ SDK Initialized successfully');
    AppLogger.d('💳 [CASHFREE_SDK] ========================================');
  }

  /// Start payment using Cashfree SDK
  /// The SDK will automatically open and manage the payment screen
  /// 
  /// Production Configuration:
  /// - Release builds (flutter build apk --release) automatically use PRODUCTION environment
  /// - Debug builds use SANDBOX for development/testing
  /// - Ensure backend CASHFREE_BASE_URL is set to https://api.cashfree.com for production
  /// - Use production Cashfree credentials from your Cashfree dashboard
  Future<void> startPayment({
    required String paymentSessionId,
    required String orderId,
  }) async {
    if (!_isInitialized) {
      throw Exception('Cashfree SDK not initialized. Call initialize() first.');
    }

    // Production-ready environment detection
    // Release builds (kDebugMode = false) → PRODUCTION
    // Debug builds (kDebugMode = true) → SANDBOX
    // This ensures production payments work in release APKs without Play Store
    final CFEnvironment environment = kDebugMode 
        ? CFEnvironment.SANDBOX 
        : CFEnvironment.PRODUCTION;

    final bool isProduction = environment == CFEnvironment.PRODUCTION;
    final String envName = isProduction ? "PRODUCTION" : "SANDBOX";
    
    AppLogger.d('💳 [CASHFREE_SDK] ========================================');
    AppLogger.d('💳 [CASHFREE_SDK] 🚀 STARTING PAYMENT');
    AppLogger.d('💳 [CASHFREE_SDK] Payment Session ID: $paymentSessionId');
    AppLogger.d('💳 [CASHFREE_SDK] Order ID: $orderId');
    AppLogger.d('💳 [CASHFREE_SDK] Environment: $envName');
    AppLogger.d('💳 [CASHFREE_SDK] Build Mode: ${kDebugMode ? "DEBUG" : "RELEASE"}');
    if (isProduction) {
      AppLogger.d('💳 [CASHFREE_SDK] ⚠️ PRODUCTION MODE - Real payments will be processed');
    } else {
      AppLogger.d('💳 [CASHFREE_SDK] 🧪 SANDBOX MODE - Test payments only');
      AppLogger.d('💳 [CASHFREE_SDK] 💡 Using test credentials - no real money will be charged');
    }
    AppLogger.d('💳 [CASHFREE_SDK] ========================================');

    try {
      // Create Session
      var session = CFSessionBuilder()
          .setEnvironment(environment)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      AppLogger.d('💳 [CASHFREE_SDK] Session created');

      // Create Web Checkout Payment Object from Session
      // This opens a web checkout flow with all payment methods (UPI, Card, Wallet, Netbanking)
      var payment = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .build();

      AppLogger.d('💳 [CASHFREE_SDK] Web checkout payment object created');
      AppLogger.d('💳 [CASHFREE_SDK] Opening payment screen...');
      AppLogger.d('💳 [CASHFREE_SDK] SDK will manage WebView lifecycle automatically');
      AppLogger.d('💳 [CASHFREE_SDK] All payment methods will be available (UPI, Card, Wallet, Netbanking)');
      AppLogger.d('💳 [CASHFREE_SDK] ========================================');

      // 🚀 SDK OPENS THE PAYMENT SCREEN AUTOMATICALLY
      // The SDK will:
      // 1. Open a native payment screen (overlay)
      // 2. Handle all user interactions
      // 3. Automatically close when payment completes/fails
      // 4. Call the appropriate callback (success or error)
      
      AppLogger.d('💳 [CASHFREE_SDK] Calling doPayment()...');
      AppLogger.d('💳 [CASHFREE_SDK] Payment object type: ${payment.runtimeType}');
      AppLogger.d('💳 [CASHFREE_SDK] Session orderId: ${session.getOrderId()}');
      AppLogger.d('💳 [CASHFREE_SDK] Session paymentSessionId: ${session.getPaymentSessionId()?.substring(0, 30)}...');
      
      try {
        _cfPaymentGatewayService.doPayment(payment);
        AppLogger.d('💳 [CASHFREE_SDK] ✅ doPayment() called successfully');
        AppLogger.d('💳 [CASHFREE_SDK] Payment screen should open automatically');
        AppLogger.d('💳 [CASHFREE_SDK] Waiting for user to complete payment...');
      } catch (e, stackTrace) {
        AppLogger.e('💳 [CASHFREE_SDK] ========================================');
        AppLogger.e('💳 [CASHFREE_SDK] ❌ ERROR CALLING doPayment()');
        AppLogger.e('💳 [CASHFREE_SDK] Error: $e');
        AppLogger.e('💳 [CASHFREE_SDK] Stack: $stackTrace');
        AppLogger.e('💳 [CASHFREE_SDK] ========================================');
        rethrow;
      }

    } on CFException catch (e) {
      AppLogger.e('💳 [CASHFREE_SDK] ========================================');
      AppLogger.e('💳 [CASHFREE_SDK] ❌ CASHFREE EXCEPTION');
      AppLogger.e('💳 [CASHFREE_SDK] Error: ${e.message}');
      AppLogger.e('💳 [CASHFREE_SDK] Type: ${e.runtimeType}');
      AppLogger.e('💳 [CASHFREE_SDK] ========================================');
      
      _onPaymentError?.call(e.message ?? 'Payment initialization failed', orderId);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.e('💳 [CASHFREE_SDK] ========================================');
      AppLogger.e('💳 [CASHFREE_SDK] ❌ UNEXPECTED ERROR');
      AppLogger.e('💳 [CASHFREE_SDK] Error: $e');
      AppLogger.e('💳 [CASHFREE_SDK] Stack: $stackTrace');
      AppLogger.e('💳 [CASHFREE_SDK] ========================================');
      
      _onPaymentError?.call(e.toString(), orderId);
      rethrow;
    }
  }

  /// Verify payment status with backend after SDK callback
  Future<PaymentVerifyResponse> verifyPayment({
    required String orderId,
  }) async {
    AppLogger.d('💳 [CASHFREE_SDK] ========================================');
    AppLogger.d('💳 [CASHFREE_SDK] 🔍 VERIFYING PAYMENT WITH BACKEND');
    AppLogger.d('💳 [CASHFREE_SDK] Order ID: $orderId');
    AppLogger.d('💳 [CASHFREE_SDK] ========================================');
    
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.verifyPayment,
        data: {
          'order_id': orderId,
        },
      );

      AppLogger.d('💳 [CASHFREE_SDK] Backend verification response received');
      AppLogger.d('💳 [CASHFREE_SDK] Success: ${response.isSuccess}');
      AppLogger.d('💳 [CASHFREE_SDK] Message: ${response.message}');

      if (!response.isSuccess || response.data == null) {
        return PaymentVerifyResponse(
          success: false,
          message: response.message ?? 'Payment verification failed',
        );
      }

      final verifyResponse = PaymentVerifyResponse.fromJson(response.data!);
      AppLogger.d('💳 [CASHFREE_SDK] ✅ Payment verification complete');
      AppLogger.d('💳 [CASHFREE_SDK] Status: ${verifyResponse.data?.paymentStatus}');
      AppLogger.d('💳 [CASHFREE_SDK] ========================================');

      return verifyResponse;
    } catch (e, stackTrace) {
      AppLogger.e('💳 [CASHFREE_SDK] Payment verification exception', e, stackTrace);
      return PaymentVerifyResponse(
        success: false,
        message: 'Payment verification failed: $e',
      );
    }
  }
}

/// Payment Verification Response
class PaymentVerifyResponse {
  final bool success;
  final String message;
  final PaymentVerifyData? data;

  PaymentVerifyResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PaymentVerifyResponse.fromJson(Map<String, dynamic> json) {
    return PaymentVerifyResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? PaymentVerifyData.fromJson(json['data']) : null,
    );
  }
}

/// Payment Verify Data
class PaymentVerifyData {
  final String bookingId;
  final String paymentStatus;
  final String orderId;
  final String? paymentId;

  PaymentVerifyData({
    required this.bookingId,
    required this.paymentStatus,
    required this.orderId,
    this.paymentId,
  });

  factory PaymentVerifyData.fromJson(Map<String, dynamic> json) {
    return PaymentVerifyData(
      bookingId: json['bookingId'] ?? '',
      paymentStatus: json['paymentStatus'] ?? '',
      orderId: json['orderId'] ?? '',
      paymentId: json['paymentId'],
    );
  }
}

