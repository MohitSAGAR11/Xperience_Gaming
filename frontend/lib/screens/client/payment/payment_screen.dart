import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Check imports based on your folder structure
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
      ..setBackgroundColor(AppColors.trueBlack) // Avoid white flash
      ..addJavaScriptChannel(
        'PayUConsole',
        onMessageReceived: (JavaScriptMessage message) {
          AppLogger.d('💳 [PAYMENT_SCREEN] Console: ${message.message}');
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            AppLogger.d('💳 [PAYMENT_SCREEN] Page started loading: $url');
          },
          onPageFinished: (String url) {
            AppLogger.d('💳 [PAYMENT_SCREEN] Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            AppLogger.e('💳 [PAYMENT_SCREEN] WebView error: ${error.description}');
            // Don't show error UI immediately as some assets (like favicons) failing is normal
          },
          onNavigationRequest: (NavigationRequest request) {
            AppLogger.d('💳 [PAYMENT_SCREEN] Navigation request: ${request.url}');
            
            // --- SIGNAL INTERCEPTION LOGIC ---
            // Intercept backend redirects to success/failure pages
            if (request.url.contains('/success') || 
                request.url.contains('/failure') || 
                request.url.contains('/cancel') ||
                request.url.contains('/payment-result')) {
                  
              AppLogger.d("💳 [PAYMENT_SCREEN] Signal Received! Closing WebView.");
              
              bool isSuccess = request.url.contains('success');
              
              if (mounted) {
                if (isSuccess) {
                  Navigator.pop(context, true); // Return TRUE for success
                } else {
                  Navigator.pop(context, false); // Return FALSE for failure
                }
              }
              
              return NavigationDecision.prevent; // STOP loading the page
            }
            
            return NavigationDecision.navigate;
          },
        ),
      );
    
    AppLogger.d('💳 [PAYMENT_SCREEN] WebView initialized successfully');
  }

  Future<void> _loadPaymentPage() async {
    try {
      setState(() => _isLoading = true);
      
      final paymentService = ref.read(paymentServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      if (currentUser == null) {
        if (mounted) {
          SnackbarUtils.showError(context, 'User not logged in');
          context.pop();
        }
        return;
      }

      // Initiate payment
      final paymentResponse = await paymentService.initiatePayment(
        bookingId: widget.booking.id,
        amount: widget.amount,
        firstName: currentUser.name,
        email: currentUser.email,
        phone: currentUser.phone,
        productInfo: 'Booking ${widget.booking.id}',
      );

      if (!paymentResponse.success || paymentResponse.data == null) {
        if (mounted) {
          SnackbarUtils.showError(context, paymentResponse.message);
          context.pop();
        }
        return;
      }

      // Load payment form HTML
      final htmlContent = paymentResponse.data!.buildPaymentFormHtml();
      
      await _webViewController.loadHtmlString(htmlContent);
      
      AppLogger.d('💳 [PAYMENT_SCREEN] HTML Form Loaded. Redirecting to PayU...');
      
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_SCREEN] Exception', e, stackTrace);
      if (mounted) {
        SnackbarUtils.showError(context, 'Payment initialization failed');
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
        leading: IconButton(
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
                      'Redirecting to secure gateway...',
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
        title: const Text('Cancel Payment?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Your booking will remain pending until payment is completed.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context, false); // Close Screen with Failure result
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Payment'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load payment page once the screen is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(_isLoading && !_paymentCompleted) { 
        _loadPaymentPage();
      }
    });
  }
}