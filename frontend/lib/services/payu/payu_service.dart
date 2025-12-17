import 'dart:async';
import 'package:flutter/material.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import '../../core/logger.dart';

/// PayU Service - Handles PayU CheckoutPro SDK integration
/// Implements PayUCheckoutProProtocol to receive payment callbacks
class PayUService implements PayUCheckoutProProtocol {
  static final PayUService _instance = PayUService._internal();
  factory PayUService() => _instance;
  PayUService._internal();

  PayUCheckoutProFlutter? _checkoutPro;
  Completer<PayUPaymentResult>? _paymentCompleter;

  /// Initialize PayU CheckoutPro SDK instance
  void _initializeSDK() {
    if (_checkoutPro == null) {
      // PayUCheckoutProFlutter constructor requires PayUCheckoutProProtocol (this class)
      _checkoutPro = PayUCheckoutProFlutter(this);
      AppLogger.d('💳 [PAYU_SDK] SDK instance initialized');
    }
  }

  // Implement PayUCheckoutProProtocol callbacks
  @override
  dynamic onPaymentSuccess(dynamic response) {
    AppLogger.d('💳 [PAYU_SDK] ✅ Payment Success');
    AppLogger.d('💳 [PAYU_SDK] Response: $response');
    
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      final responseMap = response is Map ? response as Map : {};
      _paymentCompleter!.complete(PayUPaymentResult(
        status: PayUPaymentStatus.success,
        transactionId: responseMap['txnid']?.toString(),
        response: Map<String, dynamic>.from(responseMap.map((k, v) => MapEntry(k.toString(), v))),
      ));
    }
  }

  @override
  dynamic onPaymentFailure(dynamic response) {
    AppLogger.e('💳 [PAYU_SDK] ❌ Payment Failure');
    AppLogger.e('💳 [PAYU_SDK] Response: $response');
    
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      final responseMap = response is Map ? response as Map : {};
      _paymentCompleter!.complete(PayUPaymentResult(
        status: PayUPaymentStatus.failure,
        message: responseMap['error']?.toString() ?? 'Payment failed',
        response: Map<String, dynamic>.from(responseMap.map((k, v) => MapEntry(k.toString(), v))),
      ));
    }
  }

  @override
  dynamic onPaymentCancel(Map<dynamic, dynamic>? response) {
    AppLogger.w('💳 [PAYU_SDK] ⚠️ Payment Cancelled by user');
    if (response != null) {
      AppLogger.w('💳 [PAYU_SDK] Cancel response: $response');
    }
    
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PayUPaymentResult(
        status: PayUPaymentStatus.cancelled,
        message: 'Payment cancelled by user',
      ));
    }
  }

  @override
  dynamic onError(Map<dynamic, dynamic>? error) {
    AppLogger.e('💳 [PAYU_SDK] ❌ Payment Error');
    AppLogger.e('💳 [PAYU_SDK] Error: $error');
    
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete(PayUPaymentResult(
        status: PayUPaymentStatus.error,
        message: error?['error']?.toString() ?? 'Payment error occurred',
        response: error != null ? Map<String, dynamic>.from(error.map((k, v) => MapEntry(k.toString(), v))) : null,
      ));
    }
  }

  @override
  String generateHash(Map<dynamic, dynamic> params) {
    // Hash generation is done on the backend for security
    // This method is required by the protocol but we don't use it
    // The hash is already included in paymentParams from the backend
    AppLogger.d('💳 [PAYU_SDK] generateHash called (not used - hash comes from backend)');
    return params['hash']?.toString() ?? '';
  }

  /// Open PayU payment screen using CheckoutPro SDK
  /// 
  /// [paymentParams] should contain:
  /// - key: Merchant key
  /// - txnid: Transaction ID
  /// - amount: Payment amount
  /// - productinfo: Product information
  /// - firstname: Customer first name
  /// - email: Customer email
  /// - phone: Customer phone
  /// - hash: Server-generated hash
  /// - surl: Success callback URL
  /// - furl: Failure callback URL
  /// - curl: Cancel callback URL
  /// - service_provider: Service provider (default: payu_paisa)
  /// - environment: '0' for production, '1' for test (optional)
  Future<PayUPaymentResult> openPayment({
    required BuildContext context,
    required Map<String, dynamic> paymentParams,
  }) async {
    try {
      AppLogger.d('💳 [PAYU_SDK] ========================================');
      AppLogger.d('💳 [PAYU_SDK] Opening PayU CheckoutPro payment screen...');
      AppLogger.d('💳 [PAYU_SDK] Transaction ID: ${paymentParams['txnid']}');
      AppLogger.d('💳 [PAYU_SDK] Amount: ${paymentParams['amount']}');
      AppLogger.d('💳 [PAYU_SDK] Email: ${paymentParams['email']}');
      
      // Initialize SDK
      _initializeSDK();
      
      // Helper function to safely convert any value to String
      String _toString(dynamic value) {
        if (value == null) return '';
        if (value is String) return value;
        if (value is Map) {
          AppLogger.e('💳 [PAYU_SDK] ⚠️ WARNING: Found Map value where String expected: $value');
          return value.toString();
        }
        return value.toString();
      }
      
      // Prepare payment parameters for SDK using PayU's constant keys
      // Log each parameter to identify any issues
      AppLogger.d('💳 [PAYU_SDK] Preparing payment parameters using PayU constant keys...');
      for (final key in paymentParams.keys) {
        final value = paymentParams[key];
        AppLogger.d('💳 [PAYU_SDK] Parameter $key: ${value.runtimeType} = ${value is Map ? '[Map]' : value}');
      }
      
      // Extract hash for config (must be in config, not payment params)
      final hash = _toString(paymentParams['hash']);
      AppLogger.d('💳 [PAYU_SDK] Hash extracted for config: ${hash.substring(0, 20)}...');
      
      // Payment Parameters - using plain string keys (PayU SDK expects these exact keys)
      // Hash is NOT included here - it goes in config
      final payUPaymentParams = <String, String>{
        'key': _toString(paymentParams['key']),
        'txnid': _toString(paymentParams['txnid']),
        'amount': _toString(paymentParams['amount']),
        'productinfo': _toString(paymentParams['productinfo']),
        'firstname': _toString(paymentParams['firstname']),
        'email': _toString(paymentParams['email']),
        'phone': _toString(paymentParams['phone']),
        'surl': _toString(paymentParams['surl']),
        'furl': _toString(paymentParams['furl']),
        'curl': _toString(paymentParams['curl']),
        'service_provider': _toString(paymentParams['service_provider'] ?? 'payu_paisa'),
        'environment': _toString(paymentParams['environment'] ?? '1'), // '0' for production, '1' for test
        // Note: hash is NOT in payment params - it goes in config
      };

      AppLogger.d('💳 [PAYU_SDK] Payment parameters prepared');
      AppLogger.d('💳 [PAYU_SDK] Environment: ${payUPaymentParams['environment']}');
      
      // Detailed logging of payment parameters structure
      AppLogger.d('💳 [PAYU_SDK] ========== PAYMENT PARAMS DETAILED LOG ==========');
      AppLogger.d('💳 [PAYU_SDK] payUPaymentParams type: ${payUPaymentParams.runtimeType}');
      AppLogger.d('💳 [PAYU_SDK] payUPaymentParams length: ${payUPaymentParams.length}');
      AppLogger.d('💳 [PAYU_SDK] payUPaymentParams keys: ${payUPaymentParams.keys.toList()}');
      
      // Validate all values are actually Strings
      bool hasNonStringValue = false;
      for (final entry in payUPaymentParams.entries) {
        final isString = entry.value is String;
        final valueType = entry.value.runtimeType;
        AppLogger.d('💳 [PAYU_SDK]   - ${entry.key}: type=$valueType, isString=$isString, value="${entry.value}"');
        
        if (!isString) {
          hasNonStringValue = true;
          AppLogger.e('💳 [PAYU_SDK]   ⚠️ WARNING: ${entry.key} is NOT a String! Type: $valueType');
          if (entry.value is Map) {
            AppLogger.e('💳 [PAYU_SDK]   ⚠️ Value is a Map: $entry.value');
          }
        }
      }
      
      if (hasNonStringValue) {
        AppLogger.e('💳 [PAYU_SDK] ❌ ERROR: Found non-String values in payUPaymentParams!');
      } else {
        AppLogger.d('💳 [PAYU_SDK] ✅ All payment parameter values are Strings');
      }
      AppLogger.d('💳 [PAYU_SDK] ==================================================');

      // Create result completer for this payment
      _paymentCompleter = Completer<PayUPaymentResult>();

      // Open payment screen with SDK
      // The callbacks are handled by the protocol methods above
      // Config - CRITICAL: Hash MUST be in config, not in payment params
      // Using string literals for config keys (PayU SDK expects these exact keys)
      final payUCheckoutProConfig = <String, String>{
        'hash': hash, // ⚠️ THIS IS CRITICAL - hash must be here!
        'merchantResponseTimeout': '30000',
      };
      
      AppLogger.d('💳 [PAYU_SDK] Config prepared with hash: ${hash.substring(0, 20)}...');

      // Detailed logging of config structure
      AppLogger.d('💳 [PAYU_SDK] ========== CONFIG DETAILED LOG ==========');
      AppLogger.d('💳 [PAYU_SDK] payUCheckoutProConfig type: ${payUCheckoutProConfig.runtimeType}');
      AppLogger.d('💳 [PAYU_SDK] payUCheckoutProConfig length: ${payUCheckoutProConfig.length}');
      AppLogger.d('💳 [PAYU_SDK] payUCheckoutProConfig keys: ${payUCheckoutProConfig.keys.toList()}');
      
      // Validate all config values are actually Strings
      bool hasNonStringConfigValue = false;
      for (final entry in payUCheckoutProConfig.entries) {
        final isString = entry.value is String;
        final valueType = entry.value.runtimeType;
        AppLogger.d('💳 [PAYU_SDK]   - ${entry.key}: type=$valueType, isString=$isString, value="${entry.value}"');
        
        if (!isString) {
          hasNonStringConfigValue = true;
          AppLogger.e('💳 [PAYU_SDK]   ⚠️ WARNING: ${entry.key} is NOT a String! Type: $valueType');
          if (entry.value is Map) {
            AppLogger.e('💳 [PAYU_SDK]   ⚠️ Value is a Map: $entry.value');
          }
        }
      }
      
      if (hasNonStringConfigValue) {
        AppLogger.e('💳 [PAYU_SDK] ❌ ERROR: Found non-String values in payUCheckoutProConfig!');
      } else {
        AppLogger.d('💳 [PAYU_SDK] ✅ All config values are Strings');
        AppLogger.d('💳 [PAYU_SDK] ✅ Hash is present in config: ${payUCheckoutProConfig.containsKey('hash')}');
      }
      AppLogger.d('💳 [PAYU_SDK] ==========================================');

      // Log SDK instance details
      AppLogger.d('💳 [PAYU_SDK] ========== SDK INSTANCE DETAILS ==========');
      AppLogger.d('💳 [PAYU_SDK] _checkoutPro type: ${_checkoutPro.runtimeType}');
      AppLogger.d('💳 [PAYU_SDK] _checkoutPro is null: ${_checkoutPro == null}');
      if (_checkoutPro != null) {
        AppLogger.d('💳 [PAYU_SDK] _checkoutPro.toString(): ${_checkoutPro.toString()}');
        // Try to get method information using reflection (if available)
        try {
          final method = _checkoutPro.runtimeType.toString();
          AppLogger.d('💳 [PAYU_SDK] SDK class: $method');
        } catch (e) {
          AppLogger.d('💳 [PAYU_SDK] Could not inspect SDK class: $e');
        }
      }
      AppLogger.d('💳 [PAYU_SDK] ===========================================');

      AppLogger.d('💳 [PAYU_SDK] ========== PRE-CALL SUMMARY ==========');
      AppLogger.d('💳 [PAYU_SDK] About to call: _checkoutPro!.openCheckoutScreen()');
      AppLogger.d('💳 [PAYU_SDK] Arguments summary:');
      AppLogger.d('💳 [PAYU_SDK]   - payUPaymentParams: ${payUPaymentParams.runtimeType} with ${payUPaymentParams.length} entries');
      AppLogger.d('💳 [PAYU_SDK]   - payUCheckoutProConfig: ${payUCheckoutProConfig.runtimeType} with ${payUCheckoutProConfig.length} entries');
      AppLogger.d('💳 [PAYU_SDK]   - Hash in config: ${payUCheckoutProConfig.containsKey('hash')}');
      if (payUCheckoutProConfig.containsKey('hash')) {
        final configHash = payUCheckoutProConfig['hash'] ?? '';
        AppLogger.d('💳 [PAYU_SDK]   - Config hash preview: ${configHash.length > 20 ? configHash.substring(0, 20) + "..." : configHash}');
      }
      AppLogger.d('💳 [PAYU_SDK] SDK instance: ${_checkoutPro.runtimeType}');
      AppLogger.d('💳 [PAYU_SDK] ======================================');
      
      AppLogger.d('💳 [PAYU_SDK] Opening checkout screen with config (hash included)...');
      
      try {
        AppLogger.d('💳 [PAYU_SDK] ⏳ Calling openCheckoutScreen NOW...');
        await _checkoutPro!.openCheckoutScreen(
          payUPaymentParams: payUPaymentParams,
          payUCheckoutProConfig: payUCheckoutProConfig,
        );
        AppLogger.d('💳 [PAYU_SDK] ✅ openCheckoutScreen call completed successfully');
      } catch (e, stackTrace) {
        AppLogger.e('💳 [PAYU_SDK] ========== EXCEPTION CAUGHT ==========');
        AppLogger.e('💳 [PAYU_SDK] Exception type: ${e.runtimeType}');
        AppLogger.e('💳 [PAYU_SDK] Exception message: ${e.toString()}');
        AppLogger.e('💳 [PAYU_SDK] Exception hash code: ${e.hashCode}');
        
        if (e is TypeError) {
          AppLogger.e('💳 [PAYU_SDK] This is a TypeError!');
          AppLogger.e('💳 [PAYU_SDK] TypeError toString(): ${e.toString()}');
        } else if (e is ArgumentError) {
          AppLogger.e('💳 [PAYU_SDK] This is an ArgumentError!');
          AppLogger.e('💳 [PAYU_SDK] ArgumentError message: ${e.message}');
          AppLogger.e('💳 [PAYU_SDK] ArgumentError invalidValue: ${e.invalidValue}');
          AppLogger.e('💳 [PAYU_SDK] ArgumentError name: ${e.name}');
        } else if (e is NoSuchMethodError) {
          AppLogger.e('💳 [PAYU_SDK] This is a NoSuchMethodError!');
          AppLogger.e('💳 [PAYU_SDK] Method: ${e.toString()}');
        }
        
        AppLogger.e('💳 [PAYU_SDK] Full stack trace:');
        AppLogger.e('💳 [PAYU_SDK] $stackTrace');
        AppLogger.e('💳 [PAYU_SDK] ======================================');
        
        // Log the state of parameters at the time of error
        AppLogger.e('💳 [PAYU_SDK] Parameter state at error time:');
        AppLogger.e('💳 [PAYU_SDK]   payUPaymentParams: $payUPaymentParams');
        AppLogger.e('💳 [PAYU_SDK]   payUCheckoutProConfig: $payUCheckoutProConfig');
        
        rethrow;
      }

      // Wait for payment result (will be completed by protocol callbacks)
      final result = await _paymentCompleter!.future;
      AppLogger.d('💳 [PAYU_SDK] Payment flow completed');
      AppLogger.d('💳 [PAYU_SDK] ========================================');
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYU_SDK] ❌ Exception in payment flow', e, stackTrace);
      return PayUPaymentResult(
        status: PayUPaymentStatus.error,
        message: 'Payment initialization failed: $e',
      );
    }
  }
}

/// Payment result model
enum PayUPaymentStatus {
  success,
  failure,
  cancelled,
  error,
}

class PayUPaymentResult {
  final PayUPaymentStatus status;
  final String? transactionId;
  final Map<String, dynamic>? response;
  final String? message;

  PayUPaymentResult({
    required this.status,
    this.transactionId,
    this.response,
    this.message,
  });

  bool get isSuccess => status == PayUPaymentStatus.success;
  bool get isFailure => status == PayUPaymentStatus.failure;
  bool get isCancelled => status == PayUPaymentStatus.cancelled;
  bool get isError => status == PayUPaymentStatus.error;
}

