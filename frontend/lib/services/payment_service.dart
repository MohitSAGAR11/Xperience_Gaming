import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../core/api_client.dart';
import '../core/logger.dart';

/// Payment Service - Handles PayU payment integration
class PaymentService {
  final ApiClient _apiClient;

  PaymentService(this._apiClient);

  /// Initiate PayU payment
  /// Returns payment URL and parameters to load in WebView
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
        AppLogger.d('💳 [PAYMENT_SERVICE] Transaction ID: ${paymentResponse.data!.txnid}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Payment URL: ${paymentResponse.data!.paymentUrl}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Hash length: ${paymentResponse.data!.hash.length}');
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
      AppLogger.d('💳 [PAYMENT_SERVICE] Refund status retrieved', {
        'status': refundStatus.refundStatus,
        'amount': refundStatus.refundAmount,
        'refundId': refundStatus.refundId
      });
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

/// Payment Data
class PaymentData {
  final String key;
  final String txnid;
  final String amount;
  final String productinfo;
  final String firstname;
  final String email;
  final String phone;
  final String surl;
  final String furl;
  final String curl;
  final String hash;
  final String paymentUrl;
  final String bookingId;

  PaymentData({
    required this.key,
    required this.txnid,
    required this.amount,
    required this.productinfo,
    required this.firstname,
    required this.email,
    required this.phone,
    required this.surl,
    required this.furl,
    required this.curl,
    required this.hash,
    required this.paymentUrl,
    required this.bookingId,
  });

  factory PaymentData.fromJson(Map<String, dynamic> json) {
    return PaymentData(
      key: json['key'] ?? '',
      txnid: json['txnid'] ?? '',
      amount: json['amount'] ?? '0',
      productinfo: json['productinfo'] ?? '',
      firstname: json['firstname'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      surl: json['surl'] ?? '',
      furl: json['furl'] ?? '',
      curl: json['curl'] ?? '',
      hash: json['hash'] ?? '',
      paymentUrl: json['paymentUrl'] ?? '',
      bookingId: json['bookingId'] ?? '',
    );
  }

  /// Build PayU payment form HTML
  String buildPaymentFormHtml() {
    final formFields = [
      '<input type="hidden" name="key" value="$key">',
      '<input type="hidden" name="txnid" value="$txnid">',
      '<input type="hidden" name="amount" value="$amount">',
      '<input type="hidden" name="productinfo" value="$productinfo">',
      '<input type="hidden" name="firstname" value="$firstname">',
      '<input type="hidden" name="email" value="$email">',
      '<input type="hidden" name="phone" value="$phone">',
      '<input type="hidden" name="surl" value="$surl">',
      '<input type="hidden" name="furl" value="$furl">',
      '<input type="hidden" name="curl" value="$curl">',
      '<input type="hidden" name="hash" value="$hash">',
      '<input type="hidden" name="service_provider" value="payu_paisa">',
    ].join('\n');

    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>PayU Payment</title>
        <style>
          body {
            margin: 0;
            padding: 20px;
            font-family: Arial, sans-serif;
            background: #000;
            color: #fff;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
          }
          .loading {
            text-align: center;
          }
          .spinner {
            border: 4px solid #333;
            border-top: 4px solid #00ffff;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
      </head>
      <body>
        <div class="loading">
          <div class="spinner"></div>
          <p>Redirecting to payment gateway...</p>
        </div>
        <form id="payuForm" action="$paymentUrl" method="post" style="display: none;">
          $formFields
        </form>
        <script>
          document.getElementById('payuForm').submit();
        </script>
      </body>
      </html>
    ''';
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

