import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../config/theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/payment_service.dart';
import '../../../models/booking_model.dart';
import '../../../core/utils.dart';
import '../../../core/logger.dart';
import '../../../widgets/loading_widget.dart';

/// Payment Screen - PayU Payment Gateway
class PaymentScreen extends ConsumerStatefulWidget {
  final Booking booking;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.booking,
    required this.amount,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    AppLogger.d('💳 [PAYMENT_SCREEN] Initializing WebView');
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            AppLogger.d('💳 [PAYMENT_SCREEN] Page started loading: $url');
            
            // Check if this is a success/failure callback
            if (url.contains('/success') || url.contains('/failure') || url.contains('/cancel')) {
              AppLogger.d('💳 [PAYMENT_SCREEN] Payment callback detected: $url');
              setState(() {
                _paymentCompleted = true;
                _isLoading = false;
              });
            } else if (url.contains('payu.in')) {
              AppLogger.d('💳 [PAYMENT_SCREEN] PayU payment page loaded');
            }
          },
          onPageFinished: (String url) {
            AppLogger.d('💳 [PAYMENT_SCREEN] Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            AppLogger.e('💳 [PAYMENT_SCREEN] WebView error', error);
            AppLogger.e('💳 [PAYMENT_SCREEN] Error code: ${error.errorCode}');
            AppLogger.e('💳 [PAYMENT_SCREEN] Error description: ${error.description}');
            AppLogger.e('💳 [PAYMENT_SCREEN] Failed URL: ${error.url}');
            
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              SnackbarUtils.showError(context, 'Payment page failed to load');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            AppLogger.d('💳 [PAYMENT_SCREEN] Navigation request: ${request.url}');
            return NavigationDecision.navigate;
          },
        ),
      );
    
    AppLogger.d('💳 [PAYMENT_SCREEN] WebView initialized successfully');
  }

  Future<void> _loadPaymentPage() async {
    AppLogger.d('💳 [PAYMENT_SCREEN] ========================================');
    AppLogger.d('💳 [PAYMENT_SCREEN] _loadPaymentPage called');
    AppLogger.d('💳 [PAYMENT_SCREEN] Booking ID: ${widget.booking.id}');
    AppLogger.d('💳 [PAYMENT_SCREEN] Amount: ₹${widget.amount}');
    AppLogger.d('💳 [PAYMENT_SCREEN] ========================================');

    try {
      setState(() => _isLoading = true);
      AppLogger.d('💳 [PAYMENT_SCREEN] Loading state set to true');

      final paymentService = ref.read(paymentServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      if (currentUser == null) {
        AppLogger.e('💳 [PAYMENT_SCREEN] User not logged in');
        if (mounted) {
          SnackbarUtils.showError(context, 'User not logged in');
          context.pop();
        }
        return;
      }

      AppLogger.d('💳 [PAYMENT_SCREEN] User authenticated: ${currentUser.email}');
      AppLogger.d('💳 [PAYMENT_SCREEN] Initiating payment with service...');

      // Initiate payment
      final paymentResponse = await paymentService.initiatePayment(
        bookingId: widget.booking.id,
        amount: widget.amount,
        firstName: currentUser.name,
        email: currentUser.email,
        phone: currentUser.phone,
        productInfo: 'Booking ${widget.booking.id}',
      );

      AppLogger.d('💳 [PAYMENT_SCREEN] Payment service response received');
      AppLogger.d('💳 [PAYMENT_SCREEN] Response success: ${paymentResponse.success}');
      AppLogger.d('💳 [PAYMENT_SCREEN] Response message: ${paymentResponse.message}');
      AppLogger.d('💳 [PAYMENT_SCREEN] Has data: ${paymentResponse.data != null}');

      if (!paymentResponse.success || paymentResponse.data == null) {
        AppLogger.e('💳 [PAYMENT_SCREEN] Payment initiation failed');
        AppLogger.e('💳 [PAYMENT_SCREEN] Error: ${paymentResponse.message}');
        if (mounted) {
          SnackbarUtils.showError(context, paymentResponse.message);
          context.pop();
        }
        return;
      }

      AppLogger.d('💳 [PAYMENT_SCREEN] Payment data received successfully');
      AppLogger.d('💳 [PAYMENT_SCREEN] Transaction ID: ${paymentResponse.data!.txnid}');
      AppLogger.d('💳 [PAYMENT_SCREEN] Payment URL: ${paymentResponse.data!.paymentUrl}');
      AppLogger.d('💳 [PAYMENT_SCREEN] Building payment form HTML...');

      // Load payment form HTML
      final htmlContent = paymentResponse.data!.buildPaymentFormHtml();
      AppLogger.d('💳 [PAYMENT_SCREEN] HTML form built, length: ${htmlContent.length} characters');
      AppLogger.d('💳 [PAYMENT_SCREEN] Loading HTML into WebView...');
      
      await _webViewController.loadHtmlString(htmlContent);
      
      AppLogger.d('💳 [PAYMENT_SCREEN] HTML loaded into WebView successfully');
      AppLogger.d('💳 [PAYMENT_SCREEN] Form will auto-submit to PayU');
      AppLogger.d('💳 [PAYMENT_SCREEN] ========================================');
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SCREEN] Exception in _loadPaymentPage', e, stackTrace);
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to initialize payment: $e');
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Payment'),
        leading: _paymentCompleted
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _showCancelDialog(),
              ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            Container(
              color: AppColors.trueBlack,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NeonLoader(),
                    SizedBox(height: 24),
                    Text(
                      'Loading payment gateway...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Cancel Payment?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to cancel the payment? Your booking will remain pending.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load payment page when screen is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPaymentPage();
    });
  }
}

