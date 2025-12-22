import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../core/logger.dart';
import '../../../core/utils.dart';
import '../../../core/api_client.dart' show apiClientProvider;
import '../../../widgets/loading_widget.dart' show NeonLoader;
import '../../../services/cashfree_payment_service.dart';
import '../../../services/payment_service.dart';
import '../../../providers/auth_provider.dart';

/// Payment Screen using Official Cashfree Flutter SDK
/// The SDK manages WebView lifecycle internally - no manual WebView needed
class PaymentScreenSDK extends ConsumerStatefulWidget {
  final String bookingId;
  final double amount;
  final String? firstName;
  final String? email;
  final String? phone;
  final String? productInfo;

  const PaymentScreenSDK({
    super.key,
    required this.bookingId,
    required this.amount,
    this.firstName,
    this.email,
    this.phone,
    this.productInfo,
  });

  @override
  ConsumerState<PaymentScreenSDK> createState() => _PaymentScreenSDKState();
}

class _PaymentScreenSDKState extends ConsumerState<PaymentScreenSDK> {
  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _errorMessage;

  late final CashfreePaymentService _cashfreeService;
  late final PaymentService _paymentService;

  @override
  void initState() {
    super.initState();
    AppLogger.d('💳 [PAYMENT_SDK] ========================================');
    AppLogger.d('💳 [PAYMENT_SDK] === PAYMENT SCREEN INITIALIZED ===');
    AppLogger.d('💳 [PAYMENT_SDK] Booking ID: ${widget.bookingId}');
    AppLogger.d('💳 [PAYMENT_SDK] Amount: ₹${widget.amount}');
    AppLogger.d('💳 [PAYMENT_SDK] ========================================');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePayment();
    });
  }

  Future<void> _initializePayment() async {
    final currentUser = ref.read(currentUserProvider);
    
    if (currentUser == null) {
      AppLogger.e('💳 [PAYMENT_SDK] ERROR: No current user');
      if (mounted) {
        SnackbarUtils.showError(context, 'Authentication required');
        context.pop();
      }
      return;
    }

    try {
      AppLogger.d('💳 [PAYMENT_SDK] ========================================');
      AppLogger.d('💳 [PAYMENT_SDK] 📡 INITIALIZING PAYMENT');
      
      // Get services
      _paymentService = ref.read(paymentServiceProvider);
      final apiClient = ref.read(apiClientProvider);
      _cashfreeService = CashfreePaymentService(apiClient);

      // Initialize Cashfree SDK with callbacks
      _cashfreeService.initialize(
        onPaymentSuccess: _handlePaymentSuccess,
        onPaymentError: _handlePaymentError,
      );

      AppLogger.d('💳 [PAYMENT_SDK] SDK initialized, creating payment order...');

      // Step 1: Create payment order with backend
      final paymentResponse = await _paymentService.initiatePayment(
        bookingId: widget.bookingId,
        amount: widget.amount,
        firstName: widget.firstName ?? currentUser.name ?? 'Guest',
        email: widget.email ?? currentUser.email ?? '',
        phone: widget.phone ?? currentUser.phone ?? '9999999999',
        productInfo: widget.productInfo ?? 'Booking ${widget.bookingId}',
      );

      if (!paymentResponse.success) {
        throw Exception(paymentResponse.message);
      }

      // Extract payment session ID and order ID
      final paymentSessionId = paymentResponse.paymentSessionId ?? 
                               paymentResponse.data?.paymentSessionId;
      final orderId = paymentResponse.orderId ?? 
                     paymentResponse.data?.orderId;

      if (paymentSessionId == null || paymentSessionId.isEmpty) {
        throw Exception('Payment session ID not received from backend');
      }

      if (orderId == null || orderId.isEmpty) {
        throw Exception('Order ID not received from backend');
      }

      AppLogger.d('💳 [PAYMENT_SDK] ========================================');
      AppLogger.d('💳 [PAYMENT_SDK] ✅ PAYMENT ORDER CREATED');
      AppLogger.d('💳 [PAYMENT_SDK] Payment Session ID: ${paymentSessionId.substring(0, 20)}...');
      AppLogger.d('💳 [PAYMENT_SDK] Order ID: $orderId');
      AppLogger.d('💳 [PAYMENT_SDK] Starting payment with SDK...');
      AppLogger.d('💳 [PAYMENT_SDK] ========================================');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isProcessing = true;
        });
      }

      // Step 2: Start payment with SDK
      // SDK will automatically open payment screen
      await _cashfreeService.startPayment(
        paymentSessionId: paymentSessionId,
        orderId: orderId,
      );

      AppLogger.d('💳 [PAYMENT_SDK] Payment screen opened by SDK');
      AppLogger.d('💳 [PAYMENT_SDK] Waiting for user to complete payment...');

    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SDK] ========================================');
      AppLogger.e('💳 [PAYMENT_SDK] ❌ PAYMENT INITIALIZATION ERROR');
      AppLogger.e('💳 [PAYMENT_SDK] Error: $e');
      AppLogger.e('💳 [PAYMENT_SDK] Stack: $stackTrace');
      AppLogger.e('💳 [PAYMENT_SDK] ========================================');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isProcessing = false;
          _errorMessage = e.toString();
        });
        SnackbarUtils.showError(context, 'Failed to initialize payment: $e');
      }
    }
  }

  /// Handle payment success callback from SDK
  /// SDK has already closed the payment screen at this point
  void _handlePaymentSuccess(String orderId) async {
    AppLogger.d('💳 [PAYMENT_SDK] ========================================');
    AppLogger.d('💳 [PAYMENT_SDK] ✅ PAYMENT SUCCESS CALLBACK RECEIVED');
    AppLogger.d('💳 [PAYMENT_SDK] Order ID: $orderId');
    AppLogger.d('💳 [PAYMENT_SDK] Verifying payment with backend...');
    AppLogger.d('💳 [PAYMENT_SDK] ========================================');

    if (!mounted) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Verify payment with backend
      final verifyResponse = await _cashfreeService.verifyPayment(orderId: orderId);

      if (mounted) {
        if (verifyResponse.success && 
            verifyResponse.data?.paymentStatus == 'paid') {
          AppLogger.d('💳 [PAYMENT_SDK] ✅ Payment verified successfully');
          AppLogger.d('💳 [PAYMENT_SDK] Closing payment screen...');
          
          // Return order ID to indicate success
          context.pop(orderId);
        } else {
          AppLogger.w('💳 [PAYMENT_SDK] ⚠️ Payment verification failed');
          SnackbarUtils.showError(
            context, 
            verifyResponse.message ?? 'Payment verification failed'
          );
          context.pop(false);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SDK] Payment verification exception', e, stackTrace);
      if (mounted) {
        SnackbarUtils.showError(context, 'Error verifying payment: $e');
        context.pop(false);
      }
    }
  }

  /// Handle payment error callback from SDK
  /// SDK has already closed the payment screen at this point
  void _handlePaymentError(String error, String? orderId) {
    AppLogger.e('💳 [PAYMENT_SDK] ========================================');
    AppLogger.e('💳 [PAYMENT_SDK] ❌ PAYMENT ERROR CALLBACK RECEIVED');
    AppLogger.e('💳 [PAYMENT_SDK] Error: $error');
    AppLogger.e('💳 [PAYMENT_SDK] Order ID: ${orderId ?? "N/A"}');
    AppLogger.e('💳 [PAYMENT_SDK] Error Details:');
    AppLogger.e('💳 [PAYMENT_SDK]   - Error message: $error');
    AppLogger.e('💳 [PAYMENT_SDK]   - Order ID: ${orderId ?? "Not provided"}');
    
    // Check for common error patterns
    if (error.contains('trusted source') || error.contains('installer_package')) {
      AppLogger.e('💳 [PAYMENT_SDK] ⚠️ This error suggests the app needs to be a release build');
      AppLogger.e('💳 [PAYMENT_SDK] ⚠️ Make sure you built with: flutter build apk --release');
    }
    if (error.contains('session') || error.contains('invalid')) {
      AppLogger.e('💳 [PAYMENT_SDK] ⚠️ This error suggests a payment session issue');
      AppLogger.e('💳 [PAYMENT_SDK] ⚠️ Check if backend is using correct Cashfree environment');
    }
    AppLogger.e('💳 [PAYMENT_SDK] ========================================');

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    // Show detailed error to help debug
    final errorMessage = error.contains('trusted source') 
        ? 'Payment failed: App must be a release build. Please rebuild with: flutter build apk --release'
        : 'Payment failed: $error';
    
    SnackbarUtils.showError(context, errorMessage);
    context.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // If no parent screen, redirect to home
          if (!context.canPop()) {
            context.go(Routes.clientHome);
          } else {
            context.pop(false);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.trueBlack,
        appBar: AppBar(
          title: const Text('Payment'),
          backgroundColor: AppColors.trueBlack,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              AppLogger.d('💳 [PAYMENT_SDK] User closed payment screen');
              // If no parent screen, redirect to home
              if (!context.canPop()) {
                context.go(Routes.clientHome);
              } else {
                context.pop(false);
              }
            },
        ),
      ),
      body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.pop(false),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NeonLoader(),
              SizedBox(height: 24),
              Text(
                'Initializing payment...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isProcessing) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NeonLoader(),
              SizedBox(height: 24),
              Text(
                'Processing payment...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please complete the payment in the screen that opened',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // This should not be reached as SDK manages the screen
    return const Center(
      child: Text(
        'Payment screen will open automatically',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

