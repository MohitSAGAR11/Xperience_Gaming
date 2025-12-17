import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/payment_service.dart';
import '../../../services/payu/payu_service.dart';
import '../../../models/booking_model.dart';
import '../../../core/utils.dart';
import '../../../core/logger.dart';
import '../../../widgets/loading_widget.dart' show NeonLoader;

/// Payment Screen - PayU CheckoutPro SDK Integration
/// This replaces the WebView-based implementation to avoid CORS/ORB errors
class PaymentScreenSDK extends ConsumerStatefulWidget {
  final Booking booking;
  final double amount;

  const PaymentScreenSDK({
    super.key,
    required this.booking,
    required this.amount,
  });

  @override
  ConsumerState<PaymentScreenSDK> createState() => _PaymentScreenSDKState();
}

class _PaymentScreenSDKState extends ConsumerState<PaymentScreenSDK> {
  bool _isLoading = false;
  bool _isProcessing = false;
  final PayUService _payuService = PayUService();

  @override
  void initState() {
    super.initState();
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] ========================================');
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] === PAYMENT SCREEN INITIALIZED ===');
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Booking ID: ${widget.booking.id}');
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Amount: ₹${widget.amount}');
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Booking Status: ${widget.booking.status}');
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Payment Status: ${widget.booking.paymentStatus}');
    
    // Automatically initiate payment when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiatePayment();
    });
  }

  Future<void> _initiatePayment() async {
    if (_isProcessing) return;
    
    try {
      setState(() {
        _isLoading = true;
        _isProcessing = true;
      });
      
      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] ========================================');
      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] === INITIATE PAYMENT STARTED ===');
      
      final paymentService = ref.read(paymentServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Current user: ${currentUser != null ? currentUser.email : 'null'}');

      if (currentUser == null) {
        AppLogger.e('💳 [PAYMENT_SCREEN_SDK] ERROR: User not logged in');
        if (mounted) {
          SnackbarUtils.showError(context, 'User not logged in');
          context.pop();
        }
        return;
      }

      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Calling backend to get payment parameters...');
      
      // Get payment parameters from backend
      final paymentResponse = await paymentService.initiatePayment(
        bookingId: widget.booking.id,
        amount: widget.amount,
        firstName: currentUser.name,
        email: currentUser.email,
        phone: currentUser.phone,
        productInfo: 'Booking ${widget.booking.id}',
      );

      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Backend response received');
      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Payment success: ${paymentResponse.success}');
      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Has payment data: ${paymentResponse.data != null}');

      if (!paymentResponse.success || paymentResponse.data == null) {
        AppLogger.e('💳 [PAYMENT_SCREEN_SDK] ERROR: Payment initiation failed');
        AppLogger.e('💳 [PAYMENT_SCREEN_SDK] Error message: ${paymentResponse.message}');
        if (mounted) {
          SnackbarUtils.showError(context, paymentResponse.message ?? 'Payment initialization failed');
          context.pop();
        }
        return;
      }

      // Convert PaymentData to Map for SDK
      final paymentData = paymentResponse.data!;
      final paymentParams = {
        'key': paymentData.key,
        'txnid': paymentData.txnid,
        'amount': paymentData.amount,
        'productinfo': paymentData.productinfo,
        'firstname': paymentData.firstname,
        'email': paymentData.email,
        'phone': paymentData.phone,
        'hash': paymentData.hash,
        'surl': paymentData.surl,
        'furl': paymentData.furl,
        'curl': paymentData.curl,
        'service_provider': 'payu_paisa',
        // TODO: Set to '0' for production, '1' for test
        'environment': '1', // Test mode - change to '0' for production
      };

      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Payment parameters prepared for SDK');
      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Opening PayU CheckoutPro screen...');

      // Open PayU payment screen using SDK
      final result = await _payuService.openPayment(
        context: context,
        paymentParams: paymentParams,
      );

      // Handle payment result
      await _handlePaymentResult(result);
      
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SCREEN_SDK] ❌ Payment exception', e, stackTrace);
      if (mounted) {
        SnackbarUtils.showError(context, 'Payment failed: ${e.toString()}');
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handlePaymentResult(PayUPaymentResult result) async {
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] ========================================');
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] === HANDLING PAYMENT RESULT ===');
    AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Payment Status: ${result.status}');
    
    switch (result.status) {
      case PayUPaymentStatus.success:
        AppLogger.d('💳 [PAYMENT_SCREEN_SDK] ✅ Payment successful!');
        AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Transaction ID: ${result.transactionId}');
        
        // Verify payment with backend before confirming
        await _verifyPaymentWithBackend(result);
        break;
        
      case PayUPaymentStatus.failure:
        AppLogger.e('💳 [PAYMENT_SCREEN_SDK] ❌ Payment failed: ${result.message}');
        if (mounted) {
          SnackbarUtils.showError(
            context,
            result.message ?? 'Payment failed. Please try again.',
          );
          // Don't pop - let user retry
        }
        break;
        
      case PayUPaymentStatus.cancelled:
        AppLogger.w('💳 [PAYMENT_SCREEN_SDK] ⚠️ Payment cancelled by user');
        if (mounted) {
          SnackbarUtils.showInfo(context, 'Payment cancelled');
          context.pop(false); // Return false to indicate cancellation
        }
        break;
        
      case PayUPaymentStatus.error:
        AppLogger.e('💳 [PAYMENT_SCREEN_SDK] ❌ Payment error: ${result.message}');
        if (mounted) {
          SnackbarUtils.showError(
            context,
            result.message ?? 'An error occurred during payment',
          );
          // Don't pop - let user retry
        }
        break;
    }
  }

  Future<void> _verifyPaymentWithBackend(PayUPaymentResult result) async {
    try {
      AppLogger.d('💳 [PAYMENT_SCREEN_SDK] Verifying payment with backend...');
      
      // TODO: Implement backend verification
      // The backend should verify the payment with PayU and update booking status
      // For now, we'll just show success and pop with true
      
      // In production, you should:
      // 1. Call backend API to verify payment
      // 2. Backend verifies with PayU using transaction ID
      // 3. Backend updates booking status to 'confirmed'
      // 4. Only then show success to user
      
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Payment successful!');
        // Pop with true to indicate successful payment
        context.pop(true);
      }
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SCREEN_SDK] ❌ Verification error', e, stackTrace);
      if (mounted) {
        SnackbarUtils.showError(context, 'Payment verification failed. Please check your booking status.');
        context.pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppColors.trueBlack,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            AppLogger.d('💳 [PAYMENT_SCREEN_SDK] User closed payment screen');
            context.pop(false);
          },
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const NeonLoader(),
                  const SizedBox(height: 24),
                  const Text(
                    'Preparing payment...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.payment,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment screen will open shortly...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  if (!_isProcessing) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initiatePayment,
                      child: const Text('Retry Payment'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

