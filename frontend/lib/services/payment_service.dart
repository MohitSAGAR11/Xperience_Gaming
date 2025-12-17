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
        AppLogger.d('💳 [PAYMENT_SERVICE] Amount: ${paymentResponse.data!.amount}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Email: ${paymentResponse.data!.email}');
        AppLogger.d('💳 [PAYMENT_SERVICE] First Name: ${paymentResponse.data!.firstname}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Product Info: ${paymentResponse.data!.productinfo}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Success URL: ${paymentResponse.data!.surl}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Failure URL: ${paymentResponse.data!.furl}');
        AppLogger.d('💳 [PAYMENT_SERVICE] Cancel URL: ${paymentResponse.data!.curl}');
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

/// Payment Data
class PaymentData {
  final String key;
  final String txnid;
  final String amount;
  final String productinfo;
  final String firstname;
  final String lastname;
  final String email;
  final String phone;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String country;
  final String zipcode;
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
    required this.lastname,
    required this.email,
    required this.phone,
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.country,
    required this.zipcode,
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
      lastname: json['lastname'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address1: json['address1'] ?? '',
      address2: json['address2'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      country: json['country'] ?? 'IN',
      zipcode: json['zipcode'] ?? '',
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
    AppLogger.d('💳 [PAYMENT_FORM] ========================================');
    AppLogger.d('💳 [PAYMENT_FORM] === BUILDING PAYMENT FORM HTML ===');
    AppLogger.d('💳 [PAYMENT_FORM] Transaction ID: $txnid');
    AppLogger.d('💳 [PAYMENT_FORM] Amount: $amount');
    AppLogger.d('💳 [PAYMENT_FORM] Payment URL: $paymentUrl');
    
    // HTML encode values to prevent XSS and ensure proper form submission
    String htmlEncode(String value) {
      return value
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;')
          .replaceAll("'", '&#x27;');
    }
    
    AppLogger.d('💳 [PAYMENT_FORM] Creating form fields...');
    final formFields = [
      '<input type="hidden" name="key" value="${htmlEncode(key)}">',
      '<input type="hidden" name="txnid" value="${htmlEncode(txnid)}">',
      '<input type="hidden" name="amount" value="${htmlEncode(amount)}">',
      '<input type="hidden" name="productinfo" value="${htmlEncode(productinfo)}">',
      '<input type="hidden" name="firstname" value="${htmlEncode(firstname)}">',
      '<input type="hidden" name="lastname" value="${htmlEncode(lastname)}">',
      '<input type="hidden" name="email" value="${htmlEncode(email)}">',
      '<input type="hidden" name="phone" value="${htmlEncode(phone)}">',
      '<input type="hidden" name="address1" value="${htmlEncode(address1)}">',
      '<input type="hidden" name="address2" value="${htmlEncode(address2)}">',
      '<input type="hidden" name="city" value="${htmlEncode(city)}">',
      '<input type="hidden" name="state" value="${htmlEncode(state)}">',
      '<input type="hidden" name="country" value="${htmlEncode(country)}">',
      '<input type="hidden" name="zipcode" value="${htmlEncode(zipcode)}">',
      '<input type="hidden" name="surl" value="${htmlEncode(surl)}">',
      '<input type="hidden" name="furl" value="${htmlEncode(furl)}">',
      '<input type="hidden" name="curl" value="${htmlEncode(curl)}">',
      '<input type="hidden" name="hash" value="${htmlEncode(hash)}">',
      '<input type="hidden" name="service_provider" value="payu_paisa">',
    ].join('\n');
    
    AppLogger.d('💳 [PAYMENT_FORM] Form fields created');
    AppLogger.d('💳 [PAYMENT_FORM] Form fields count: ${formFields.split('\n').length}');
    AppLogger.d('💳 [PAYMENT_FORM] Success URL: $surl');
    AppLogger.d('💳 [PAYMENT_FORM] Failure URL: $furl');
    AppLogger.d('💳 [PAYMENT_FORM] Cancel URL: $curl');
    AppLogger.d('💳 [PAYMENT_FORM] Hash length: ${hash.length}');

    AppLogger.d('💳 [PAYMENT_FORM] Generating HTML document...');
    final htmlContent = '''
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
        <form id="payuForm" action="$paymentUrl" method="post" enctype="application/x-www-form-urlencoded" style="display: none;">
          $formFields
        </form>
        <script>
          console.log('💳 [WEBVIEW] ========================================');
          console.log('💳 [WEBVIEW] PayU Form Submission Starting...');
          console.log('💳 [WEBVIEW] Form Action:', document.getElementById('payuForm').action);
          console.log('💳 [WEBVIEW] Form Method:', document.getElementById('payuForm').method);
          console.log('💳 [WEBVIEW] Form Fields Count:', document.getElementById('payuForm').elements.length);
          
          // Log all form values for debugging
          const form = document.getElementById('payuForm');
          const formData = new FormData(form);
          console.log('💳 [WEBVIEW] Form Data:');
          for (let [key, value] of formData.entries()) {
            // Mask sensitive data
            if (key === 'hash') {
              console.log(key + ':', value.substring(0, 20) + '...' + value.substring(value.length - 10));
            } else {
              console.log(key + ':', value);
            }
          }
          
          // Submit form
          try {
            console.log('💳 [WEBVIEW] Submitting form to PayU...');
            document.getElementById('payuForm').submit();
            console.log('💳 [WEBVIEW] ✅ Form submitted successfully');
            console.log('💳 [WEBVIEW] ========================================');
          } catch (error) {
            console.error('💳 [WEBVIEW] ❌ Form submission error:', error);
            console.error('💳 [WEBVIEW] ========================================');
          }
        </script>
      </body>
      </html>
    ''';
    
    AppLogger.d('💳 [PAYMENT_FORM] HTML document generated');
    AppLogger.d('💳 [PAYMENT_FORM] Total HTML length: ${htmlContent.length} characters');
    AppLogger.d('💳 [PAYMENT_FORM] ✅ PAYMENT FORM HTML READY');
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

