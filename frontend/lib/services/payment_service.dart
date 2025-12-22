import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../core/api_client.dart';
import '../core/logger.dart';

/// Payment Service - Handles Cashfree payment integration
class PaymentService {
  final ApiClient _apiClient;

  PaymentService(this._apiClient);

  /// Initiate Cashfree payment
  /// Returns payment session ID and order details
  Future<PaymentResponse> initiatePayment({
    required String bookingId,
    required double amount,
    required String firstName,
    required String email,
    String? phone,
    String? productInfo,
  }) async {
    AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
    AppLogger.d('💳 [PAYMENT_SERVICE] initiatePayment called');
    AppLogger.d('💳 [PAYMENT_SERVICE] Booking ID: $bookingId');
    AppLogger.d('💳 [PAYMENT_SERVICE] Amount: ₹$amount');
    AppLogger.d('💳 [PAYMENT_SERVICE] First Name: $firstName');
    AppLogger.d('💳 [PAYMENT_SERVICE] Email: $email');
    AppLogger.d('💳 [PAYMENT_SERVICE] Phone: ${phone ?? "not provided"}');
    AppLogger.d('💳 [PAYMENT_SERVICE] Product Info: ${productInfo ?? "Booking Payment"}');
    AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');

    try {
      AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
      AppLogger.d('💳 [PAYMENT_SERVICE] 📤 PREPARING API REQUEST');
      AppLogger.d('💳 [PAYMENT_SERVICE] Endpoint: ${ApiConstants.createPayment}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Request Payload:');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - bookingId: $bookingId');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - amount: $amount (type: ${amount.runtimeType})');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - firstName: $firstName');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - email: $email');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - phone: ${phone ?? "null"}');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - productInfo: ${productInfo ?? "null"}');
      AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
      
      final requestStartTime = DateTime.now();
      AppLogger.d('💳 [PAYMENT_SERVICE] ⏱️ API Request started at: ${requestStartTime.toIso8601String()}');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.createPayment,
        data: {
          'bookingId': bookingId,
          'amount': amount,
          'firstName': firstName,
          'email': email,
          'phone': phone,
          'productInfo': productInfo ?? 'Booking Payment',
        },
      );

      final requestDuration = DateTime.now().difference(requestStartTime);
      AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
      AppLogger.d('💳 [PAYMENT_SERVICE] 📥 API RESPONSE RECEIVED');
      AppLogger.d('💳 [PAYMENT_SERVICE] ⏱️ Request duration: ${requestDuration.inMilliseconds}ms');
      AppLogger.d('💳 [PAYMENT_SERVICE] Response success: ${response.isSuccess}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Response message: ${response.message ?? "null"}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Has data: ${response.data != null}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Data type: ${response.data?.runtimeType}');
      if (response.data != null) {
        AppLogger.d('💳 [PAYMENT_SERVICE] Data keys: ${response.data!.keys.toList()}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Data preview: ${response.data!.toString().substring(0, response.data!.toString().length > 500 ? 500 : response.data!.toString().length)}');
      }

      if (!response.isSuccess || response.data == null) {
        AppLogger.e('💳 [PAYMENT_SERVICE] Payment initiation failed', null);
        AppLogger.e('💳 [PAYMENT_SERVICE] Error message: ${response.message ?? ErrorMessages.unknownError}');
        return PaymentResponse(
          success: false,
          message: response.message ?? ErrorMessages.unknownError,
        );
      }

      AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
      AppLogger.d('💳 [PAYMENT_SERVICE] 🔄 PARSING RESPONSE DATA');
      AppLogger.d('💳 [PAYMENT_SERVICE] Backend response format: SDK-compatible');
      AppLogger.d('💳 [PAYMENT_SERVICE] Expected fields: payment_session_id, order_id');
      AppLogger.d('💳 [PAYMENT_SERVICE] Attempting to parse JSON...');
      
      PaymentResponse paymentResponse;
      try {
        paymentResponse = PaymentResponse.fromJson(response.data!);
        AppLogger.d('💳 [PAYMENT_SERVICE] ✅ JSON parsing successful');
      } catch (parseError, stackTrace) {
        AppLogger.e('💳 [PAYMENT_SERVICE] ❌ JSON PARSING FAILED', parseError, stackTrace);
        AppLogger.e('💳 [PAYMENT_SERVICE] Raw data: ${response.data}');
        AppLogger.e('💳 [PAYMENT_SERVICE] Data type: ${response.data?.runtimeType}');
        rethrow;
      }
      
      AppLogger.d('💳 [PAYMENT_SERVICE] Parsed PaymentResponse:');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - success: ${paymentResponse.success}');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - message: ${paymentResponse.message}');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - paymentSessionId (direct): ${paymentResponse.paymentSessionId != null ? "${paymentResponse.paymentSessionId!.substring(0, 20)}..." : "null"}');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - orderId (direct): ${paymentResponse.orderId ?? "null"}');
      AppLogger.d('💳 [PAYMENT_SERVICE]   - data is null: ${paymentResponse.data == null}');
      
      if (paymentResponse.success) {
        final sessionId = paymentResponse.paymentSessionId ?? paymentResponse.data?.paymentSessionId;
        final orderId = paymentResponse.orderId ?? paymentResponse.data?.orderId;
        
        if (sessionId == null || sessionId.isEmpty) {
          AppLogger.e('💳 [PAYMENT_SERVICE] ❌ Payment session ID is missing!');
          return PaymentResponse(
            success: false,
            message: 'Payment session ID not received from backend',
          );
        }
        
        if (orderId == null || orderId.isEmpty) {
          AppLogger.e('💳 [PAYMENT_SERVICE] ❌ Order ID is missing!');
          return PaymentResponse(
            success: false,
            message: 'Order ID not received from backend',
          );
        }
        
        AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
        AppLogger.d('💳 [PAYMENT_SERVICE] ✅ PAYMENT DATA PARSED SUCCESSFULLY');
        AppLogger.d('💳 [PAYMENT_SERVICE] Payment details:');
        AppLogger.d('💳 [PAYMENT_SERVICE]   - orderId: $orderId');
        AppLogger.d('💳 [PAYMENT_SERVICE]   - paymentSessionId: ${sessionId.substring(0, sessionId.length > 20 ? 20 : sessionId.length)}...');
        AppLogger.d('💳 [PAYMENT_SERVICE]   - paymentSessionId length: ${sessionId.length}');
        AppLogger.d('💳 [PAYMENT_SERVICE]   - Ready for Cashfree SDK');
        AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
      } else {
        AppLogger.w('💳 [PAYMENT_SERVICE] ========================================');
        AppLogger.w('💳 [PAYMENT_SERVICE] ⚠️ PAYMENT RESPONSE INDICATES FAILURE');
        AppLogger.w('💳 [PAYMENT_SERVICE] success: ${paymentResponse.success}');
        AppLogger.w('💳 [PAYMENT_SERVICE] message: ${paymentResponse.message}');
        AppLogger.w('💳 [PAYMENT_SERVICE] ========================================');
      }

      return paymentResponse;
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SERVICE] ========================================');
      AppLogger.e('💳 [PAYMENT_SERVICE] ❌ PAYMENT INITIALIZATION EXCEPTION');
      AppLogger.e('💳 [PAYMENT_SERVICE] Exception type: ${e.runtimeType}');
      AppLogger.e('💳 [PAYMENT_SERVICE] Exception message: $e');
      AppLogger.e('💳 [PAYMENT_SERVICE] Stack trace:');
      AppLogger.e('💳 [PAYMENT_SERVICE] $stackTrace');
      AppLogger.e('💳 [PAYMENT_SERVICE] Request details:');
      AppLogger.e('💳 [PAYMENT_SERVICE]   - bookingId: $bookingId');
      AppLogger.e('💳 [PAYMENT_SERVICE]   - amount: $amount');
      AppLogger.e('💳 [PAYMENT_SERVICE]   - endpoint: ${ApiConstants.createPayment}');
      AppLogger.e('💳 [PAYMENT_SERVICE] ========================================');
      return PaymentResponse(
        success: false,
        message: 'Payment initialization failed: $e',
      );
    }
  }

  /// Verify payment status after callback
  Future<PaymentVerifyResponse> verifyPayment({
    required String orderId,
  }) async {
    AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
    AppLogger.d('💳 [PAYMENT_SERVICE] 🔍 VERIFYING PAYMENT');
    AppLogger.d('💳 [PAYMENT_SERVICE] Order ID: $orderId');
    AppLogger.d('💳 [PAYMENT_SERVICE] Endpoint: ${ApiConstants.verifyPayment}');
    AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
    
    try {
      final verifyStartTime = DateTime.now();
      AppLogger.d('💳 [PAYMENT_SERVICE] ⏱️ Verification request started at: ${verifyStartTime.toIso8601String()}');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.verifyPayment,
        data: {
          'order_id': orderId,
        },
      );
      
      final verifyDuration = DateTime.now().difference(verifyStartTime);
      AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
      AppLogger.d('💳 [PAYMENT_SERVICE] 📥 VERIFICATION RESPONSE RECEIVED');
      AppLogger.d('💳 [PAYMENT_SERVICE] ⏱️ Verification duration: ${verifyDuration.inMilliseconds}ms');
      AppLogger.d('💳 [PAYMENT_SERVICE] Response success: ${response.isSuccess}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Response message: ${response.message ?? "null"}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Has data: ${response.data != null}');
      if (response.data != null) {
        AppLogger.d('💳 [PAYMENT_SERVICE] Verification data: ${response.data}');
      }

      if (!response.isSuccess || response.data == null) {
        return PaymentVerifyResponse(
          success: false,
          message: response.message ?? 'Payment verification failed',
        );
      }

      return PaymentVerifyResponse.fromJson(response.data!);
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SERVICE] Payment verification exception', e, stackTrace);
      return PaymentVerifyResponse(
        success: false,
        message: 'Payment verification failed: $e',
      );
    }
  }

  /// Initiate refund for a booking
  Future<RefundResponse> initiateRefund({
    required String bookingId,
    String? reason,
    double? amount,
  }) async {
    AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
    AppLogger.d('💳 [PAYMENT_SERVICE] initiateRefund called');
    AppLogger.d('💳 [PAYMENT_SERVICE] Booking ID: $bookingId');
    AppLogger.d('💳 [PAYMENT_SERVICE] Reason: ${reason ?? "not provided"}');
    AppLogger.d('💳 [PAYMENT_SERVICE] Amount: ${amount != null ? "₹$amount" : "not specified (will calculate)"}');
    AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');

    try {
      AppLogger.d('💳 [PAYMENT_SERVICE] Calling refund API');
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${ApiConstants.refund}/$bookingId/refund',
        data: {
          if (reason != null) 'reason': reason,
          if (amount != null) 'amount': amount,
        },
      );

      AppLogger.d('💳 [PAYMENT_SERVICE] Refund response received');
      AppLogger.d('💳 [PAYMENT_SERVICE] Response success: ${response.isSuccess}');

      if (!response.isSuccess || response.data == null) {
        AppLogger.e('💳 [PAYMENT_SERVICE] Refund failed', null);
        AppLogger.e('💳 [PAYMENT_SERVICE] Error: ${response.message ?? ErrorMessages.unknownError}');
        return RefundResponse(
          success: false,
          message: response.message ?? ErrorMessages.unknownError,
        );
      }

      AppLogger.d('💳 [PAYMENT_SERVICE] Refund successful');
      final refundResponse = RefundResponse.fromJson(response.data!);
      if (refundResponse.data != null) {
        AppLogger.d('💳 [PAYMENT_SERVICE] Refund ID: ${refundResponse.data!.refundId}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Refund Amount: ₹${refundResponse.data!.refundAmount}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Refund Status: ${refundResponse.data!.refundStatus}');
      }
      return refundResponse;
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SERVICE] Refund exception', e, stackTrace);
      return RefundResponse(
        success: false,
        message: 'Refund failed: $e',
      );
    }
  }

  /// Get refund status for a booking
  Future<RefundStatusResponse> getRefundStatus(String bookingId) async {
    AppLogger.d('💳 [PAYMENT_SERVICE] getRefundStatus called for booking: $bookingId');
    
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.refundStatus}/$bookingId/refund-status',
      );

      AppLogger.d('💳 [PAYMENT_SERVICE] Refund status response: ${response.isSuccess}');

      if (!response.isSuccess || response.data == null) {
        AppLogger.w('💳 [PAYMENT_SERVICE] Failed to get refund status');
        return RefundStatusResponse(
          success: false,
          refundStatus: null,
          refundAmount: 0,
        );
      }

      final refundStatus = RefundStatusResponse.fromJson(response.data!);
      AppLogger.d('💳 [PAYMENT_SERVICE] Refund status retrieved - Status: ${refundStatus.refundStatus}, Amount: ₹${refundStatus.refundAmount}, Refund ID: ${refundStatus.refundId}');
      return refundStatus;
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SERVICE] Get refund status exception', e, stackTrace);
      return RefundStatusResponse(
        success: false,
        refundStatus: null,
        refundAmount: 0,
      );
    }
  }
}

/// Payment Response (Updated for SDK compatibility)
class PaymentResponse {
  final bool success;
  final String message;
  final PaymentData? data;
  
  // SDK-compatible fields (direct from backend)
  final String? paymentSessionId;
  final String? orderId;

  PaymentResponse({
    required this.success,
    required this.message,
    this.data,
    this.paymentSessionId,
    this.orderId,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    // Backend now returns: { success: true, payment_session_id: "...", order_id: "..." }
    // Support both old format (data object) and new format (direct fields)
    final hasDataObject = json['data'] != null;
    final hasDirectFields = json['payment_session_id'] != null || json['order_id'] != null;
    
    PaymentData? paymentData;
    if (hasDataObject) {
      paymentData = PaymentData.fromJson(json['data']);
    } else if (hasDirectFields) {
      // Create PaymentData from direct fields
      paymentData = PaymentData(
        orderId: json['order_id'] ?? '',
        paymentSessionId: json['payment_session_id'] ?? '',
        orderAmount: (json['order_amount'] ?? '0').toString(),
        orderCurrency: json['order_currency'] ?? 'INR',
        customerName: json['customerName'] ?? '',
        customerEmail: json['customerEmail'] ?? '',
        customerPhone: json['customerPhone'] ?? '',
        returnUrl: json['returnUrl'] ?? '',
      );
    }
    
    return PaymentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: paymentData,
      paymentSessionId: json['payment_session_id'] ?? json['data']?['paymentSessionId'],
      orderId: json['order_id'] ?? json['data']?['orderId'],
    );
  }
}

/// Payment Verify Response
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

/// Payment Data (Cashfree)
class PaymentData {
  final String orderId;
  final String paymentSessionId;
  final String orderAmount;
  final String orderCurrency;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String returnUrl;

  PaymentData({
    required this.orderId,
    required this.paymentSessionId,
    required this.orderAmount,
    required this.orderCurrency,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.returnUrl,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      orderId: json['orderId'] ?? '',
      paymentSessionId: json['paymentSessionId'] ?? '',
      orderAmount: json['orderAmount'] ?? '0',
      orderCurrency: json['orderCurrency'] ?? 'INR',
      customerName: json['customerName'] ?? '',
      customerEmail: json['customerEmail'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      returnUrl: json['returnUrl'] ?? '',
    );
  }


  /// Build Cashfree payment page HTML (redirects to Cashfree checkout)
  String buildPaymentPageHtml() {
    AppLogger.d('💳 [PAYMENT_FORM] ========================================');
    AppLogger.d('💳 [PAYMENT_FORM] === BUILDING CASHFREE PAYMENT PAGE ===');
    AppLogger.d('💳 [PAYMENT_FORM] Order ID: $orderId');
    AppLogger.d('💳 [PAYMENT_FORM] Payment Session ID: $paymentSessionId');
    AppLogger.d('💳 [PAYMENT_FORM] Amount: ₹$orderAmount');

    // Use Cashfree JavaScript SDK for checkout (recommended approach)
    // This avoids 404 errors and uses Cashfree's official integration method
    // Production environment only
    
    AppLogger.d('💳 [PAYMENT_FORM] ========================================');
    AppLogger.d('💳 [PAYMENT_FORM] 🔨 GENERATING HTML CONTENT');
    AppLogger.d('💳 [PAYMENT_FORM] Environment: Production');
    AppLogger.d('💳 [PAYMENT_FORM] SDK Mode: production');
    AppLogger.d('💳 [PAYMENT_FORM] Checkout URL: https://payments.cashfree.com');
    
    final htmlStartTime = DateTime.now();
    final htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta charset="UTF-8">
        <title>Processing Payment</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
          }
          .container {
            background: white;
            padding: 40px;
            border-radius: 16px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 400px;
          }
          .spinner {
            width: 50px;
            height: 50px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
          h2 { color: #333; margin-bottom: 16px; font-size: 24px; }
          p { color: #666; line-height: 1.6; }
          .amount { 
            font-size: 32px; 
            font-weight: bold; 
            color: #667eea; 
            margin: 20px 0;
          }
        </style>
        <!-- Removed Cashfree SDK - using direct URL redirect instead for WebView compatibility -->
      </head>
      <body>
        <div class="container">
          <div class="spinner"></div>
          <h2>Loading Payment Gateway</h2>
          <div class="amount">₹$orderAmount</div>
          <p>Please wait while we load Cashfree secure payment page...</p>
          <p style="font-size: 12px; margin-top: 20px; color: #999;">
            Do not close this window or press back button
          </p>
        </div>
        <script>
          console.log('💳 [WEBVIEW] ========================================');
          console.log('💳 [WEBVIEW] Cashfree Payment Initialization Starting...');
          console.log('💳 [WEBVIEW] Order ID: $orderId');
          console.log('💳 [WEBVIEW] Payment Session ID: $paymentSessionId');
          console.log('💳 [WEBVIEW] Payment Session ID Length: ${paymentSessionId.length}');
          console.log('💳 [WEBVIEW] Environment: Production');
          
          // Use direct URL redirect instead of SDK (more reliable in WebView)
          // Cashfree SDK checkout() requires PaymentJSInterface which doesn't exist in Flutter WebView
          function redirectToCashfree() {
            try {
              // Cashfree checkout URL format: https://payments.cashfree.com/checkout/payment_session_id/{session_id}
              // Note: Do NOT use /pg/checkout - that's for API endpoints, not user-facing checkout
              // URL encode the payment session ID to handle special characters
              const encodedSessionId = encodeURIComponent('$paymentSessionId');
              const checkoutUrl = 'https://payments.cashfree.com/checkout/payment_session_id/' + encodedSessionId;
              
              console.log('💳 [WEBVIEW] Redirecting to Cashfree checkout...');
              console.log('💳 [WEBVIEW] Payment Session ID (raw): $paymentSessionId');
              console.log('💳 [WEBVIEW] Payment Session ID (encoded): ' + encodedSessionId);
              console.log('💳 [WEBVIEW] Checkout URL: ' + checkoutUrl);
              console.log('💳 [WEBVIEW] URL length: ' + checkoutUrl.length);
              console.log('💳 [WEBVIEW] ========================================');
              
              // Direct redirect - most reliable method for WebView
              // Use replace instead of href to prevent back button issues
              window.location.replace(checkoutUrl);
            } catch (error) {
              console.error('💳 [WEBVIEW] ❌ ERROR redirecting to Cashfree:', error);
              console.error('💳 [WEBVIEW] Error type: ' + error.name);
              console.error('💳 [WEBVIEW] Error message: ' + error.message);
              console.error('💳 [WEBVIEW] Error stack: ' + error.stack);
              console.error('💳 [WEBVIEW] ========================================');
            }
          }
          
          // Redirect immediately when page loads
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', redirectToCashfree);
          } else {
            // Page already loaded, redirect immediately
            setTimeout(redirectToCashfree, 100);
          }
        </script>
      </body>
      </html>
    ''';
    
    final htmlDuration = DateTime.now().difference(htmlStartTime);
    AppLogger.d('💳 [PAYMENT_FORM] ========================================');
    AppLogger.d('💳 [PAYMENT_FORM] ✅ HTML GENERATION COMPLETE');
    AppLogger.d('💳 [PAYMENT_FORM] ⏱️ Generation time: ${htmlDuration.inMicroseconds}μs');
    AppLogger.d('💳 [PAYMENT_FORM] HTML Statistics:');
    AppLogger.d('💳 [PAYMENT_FORM]   - Total length: ${htmlContent.length} characters');
    AppLogger.d('💳 [PAYMENT_FORM]   - Contains paymentSessionId: ${htmlContent.contains(paymentSessionId)}');
    AppLogger.d('💳 [PAYMENT_FORM]   - Contains Cashfree SDK: ${htmlContent.contains('sdk.cashfree.com')}');
    AppLogger.d('💳 [PAYMENT_FORM]   - Contains checkout call: ${htmlContent.contains('cashfree.checkout')}');
    AppLogger.d('💳 [PAYMENT_FORM]   - Contains production mode: ${htmlContent.contains('mode: "production"')}');
    AppLogger.d('💳 [PAYMENT_FORM]   - Contains fallback URL: ${htmlContent.contains('payments.cashfree.com')}');
    AppLogger.d('💳 [PAYMENT_FORM] HTML Preview (first 300 chars):');
    AppLogger.d('💳 [PAYMENT_FORM] ${htmlContent.substring(0, htmlContent.length > 300 ? 300 : htmlContent.length)}...');
    AppLogger.d('💳 [PAYMENT_FORM] ========================================');
    
    return htmlContent;
  }

}

/// Refund Response
class RefundResponse {
  final bool success;
  final String message;
  final RefundData? data;

  RefundResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory RefundResponse.fromJson(Map<String, dynamic> json) {
    return RefundResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? RefundData.fromJson(json['data']) : null,
    );
  }
}

/// Refund Data
class RefundData {
  final String? refundId;
  final double refundAmount;
  final String refundStatus;

  RefundData({
    this.refundId,
    required this.refundAmount,
    required this.refundStatus,
  });

  factory RefundData.fromJson(Map<String, dynamic> json) {
    return RefundData(
      refundId: json['refundId'],
      refundAmount: (json['refundAmount'] ?? 0).toDouble(),
      refundStatus: json['refundStatus'] ?? '',
    );
  }
}

/// Refund Status Response
class RefundStatusResponse {
  final bool success;
  final String? refundStatus;
  final String? refundId;
  final double refundAmount;
  final String? refundReason;
  final DateTime? refundedAt;

  RefundStatusResponse({
    required this.success,
    this.refundStatus,
    this.refundId,
    required this.refundAmount,
    this.refundReason,
    this.refundedAt,
  });

  factory RefundStatusResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return RefundStatusResponse(
      success: json['success'] ?? false,
      refundStatus: data?['refundStatus'],
      refundId: data?['refundId'],
      refundAmount: (data?['refundAmount'] ?? 0).toDouble(),
      refundReason: data?['refundReason'],
      refundedAt: data?['refundedAt'] != null
          ? DateTime.tryParse(data['refundedAt'])
          : null,
    );
  }
}

/// Payment Service Provider
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PaymentService(apiClient);
});

