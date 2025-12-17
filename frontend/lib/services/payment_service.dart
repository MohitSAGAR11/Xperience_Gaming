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
      AppLogger.d('💳 [PAYMENT_SERVICE] Calling backend API: ${ApiConstants.createPayment}');
      
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

      AppLogger.d('💳 [PAYMENT_SERVICE] Backend response received');
      AppLogger.d('💳 [PAYMENT_SERVICE] Response success: ${response.isSuccess}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Response message: ${response.message}');
      AppLogger.d('💳 [PAYMENT_SERVICE] Has data: ${response.data != null}');

      if (!response.isSuccess || response.data == null) {
        AppLogger.e('💳 [PAYMENT_SERVICE] Payment initiation failed', null);
        AppLogger.e('💳 [PAYMENT_SERVICE] Error message: ${response.message ?? ErrorMessages.unknownError}');
        return PaymentResponse(
          success: false,
          message: response.message ?? ErrorMessages.unknownError,
        );
      }

      AppLogger.d('💳 [PAYMENT_SERVICE] Parsing payment response data');
      final paymentResponse = PaymentResponse.fromJson(response.data!);
      
      if (paymentResponse.success && paymentResponse.data != null) {
        AppLogger.d('💳 [PAYMENT_SERVICE] Payment data parsed successfully');
        AppLogger.d('💳 [PAYMENT_SERVICE] Order ID: ${paymentResponse.data!.orderId}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Payment Session ID: ${paymentResponse.data!.paymentSessionId}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Amount: ${paymentResponse.data!.orderAmount}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Currency: ${paymentResponse.data!.orderCurrency}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Customer Name: ${paymentResponse.data!.customerName}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Customer Email: ${paymentResponse.data!.customerEmail}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Customer Phone: ${paymentResponse.data!.customerPhone}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Return URL: ${paymentResponse.data!.returnUrl}');
        AppLogger.d('💳 [PAYMENT_SERVICE] ========================================');
      } else {
        AppLogger.w('💳 [PAYMENT_SERVICE] Payment response indicates failure');
      }

      return paymentResponse;
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SERVICE] Payment initialization exception', e, stackTrace);
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
    AppLogger.d('💳 [PAYMENT_SERVICE] Verifying payment for order: $orderId');
    
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.verifyPayment,
        data: {
          'order_id': orderId,
        },
      );

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

/// Payment Response
class PaymentResponse {
  final bool success;
  final String message;
  final PaymentData? data;

  PaymentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? PaymentData.fromJson(json['data']) : null,
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
    final isSandbox = true; // Set to false for production
    
    AppLogger.d('💳 [PAYMENT_FORM] Generating Cashfree checkout page with SDK...');
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
        <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
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
          console.log('💳 [WEBVIEW] Sandbox Mode: $isSandbox');
          
          // Initialize Cashfree SDK
          function initializeCashfree() {
            try {
              if (typeof Cashfree === 'undefined') {
                console.error('💳 [WEBVIEW] Cashfree SDK not loaded, retrying...');
                setTimeout(initializeCashfree, 500);
                return;
              }
              
              console.log('💳 [WEBVIEW] Initializing Cashfree SDK...');
              const cashfree = Cashfree({
                mode: "${isSandbox ? 'sandbox' : 'production'}"
              });
              
              console.log('💳 [WEBVIEW] Opening Cashfree checkout...');
              cashfree.checkout({
                paymentSessionId: "$paymentSessionId",
                redirectTarget: "_self"
              });
              
              console.log('💳 [WEBVIEW] ✅ Checkout initiated');
              console.log('💳 [WEBVIEW] ========================================');
            } catch (error) {
              console.error('💳 [WEBVIEW] Error initializing Cashfree:', error);
              // Fallback to direct URL redirect if SDK fails
              console.log('💳 [WEBVIEW] Falling back to direct URL redirect...');
              const checkoutUrl = 'https://sandbox.cashfree.com/pg/checkout/payment_session_id/$paymentSessionId';
              window.location.href = checkoutUrl;
            }
          }
          
          // Wait for SDK to load, then initialize
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', initializeCashfree);
          } else {
            setTimeout(initializeCashfree, 500);
          }
        </script>
      </body>
      </html>
    ''';
    
    AppLogger.d('💳 [PAYMENT_FORM] HTML document generated');
    AppLogger.d('💳 [PAYMENT_FORM] Total HTML length: ${htmlContent.length} characters');
    AppLogger.d('💳 [PAYMENT_FORM] ✅ CASHFREE PAYMENT PAGE READY');
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

