import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../config/theme.dart';
import '../../../config/constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/firebase_service.dart';
import '../../../core/api_client.dart';
import '../../../core/utils.dart';
import '../../../core/logger.dart';
import '../../../widgets/loading_widget.dart' show NeonLoader;
import '../../../services/payment_service.dart';

/// Payment Screen - WebView Implementation
/// Uses server-side HTML that redirects to Cashfree checkout
class PaymentScreenWebView extends ConsumerStatefulWidget {
  final String bookingId;
  final double amount;
  final String? firstName;
  final String? email;
  final String? phone;
  final String? productInfo;

  const PaymentScreenWebView({
    super.key,
    required this.bookingId,
    required this.amount,
    this.firstName,
    this.email,
    this.phone,
    this.productInfo,
  });

  @override
  ConsumerState<PaymentScreenWebView> createState() => _PaymentScreenWebViewState();
}

class _PaymentScreenWebViewState extends ConsumerState<PaymentScreenWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] === PAYMENT SCREEN INITIALIZED ===');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Booking ID: ${widget.bookingId}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Amount: ₹${widget.amount}');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebView();
    });
  }

  void _initializeWebView() async {
    final currentUser = ref.read(currentUserProvider);
    
    if (currentUser == null) {
      AppLogger.e('💳 [PAYMENT_WEBVIEW] ERROR: No current user');
      if (mounted) {
        SnackbarUtils.showError(context, 'Authentication required');
        context.pop();
      }
      return;
    }

    try {
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] 📡 INITIATING CASHFREE PAYMENT');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Endpoint: ${ApiConstants.createPayment}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Request Data:');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - bookingId: ${widget.bookingId}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - amount: ${widget.amount}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - firstName: ${widget.firstName ?? currentUser.name ?? 'Guest'}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - email: ${widget.email ?? currentUser.email ?? ''}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - phone: ${widget.phone ?? currentUser.phone ?? '9999999999'}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - productInfo: ${widget.productInfo ?? 'Booking ${widget.bookingId}'}');
      
      // Use PaymentService to initiate payment (returns JSON with payment session data)
      final paymentService = ref.read(paymentServiceProvider);
      final paymentResponse = await paymentService.initiatePayment(
        bookingId: widget.bookingId,
        amount: widget.amount,
        firstName: widget.firstName ?? currentUser.name ?? 'Guest',
        email: widget.email ?? currentUser.email ?? '',
        phone: widget.phone ?? currentUser.phone ?? '9999999999',
        productInfo: widget.productInfo ?? 'Booking ${widget.bookingId}',
      );

      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] 📥 PAYMENT RESPONSE RECEIVED');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Success: ${paymentResponse.success}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Message: ${paymentResponse.message}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Has Data: ${paymentResponse.data != null}');

      if (!paymentResponse.success || paymentResponse.data == null) {
        AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] ❌ FAILED TO INITIATE PAYMENT');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] Error: ${paymentResponse.message}');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
        if (mounted) {
          SnackbarUtils.showError(context, paymentResponse.message ?? 'Failed to initiate payment');
          context.pop();
        }
        return;
      }

      // Generate HTML page using PaymentData
      final htmlContent = paymentResponse.data!.buildPaymentPageHtml();
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ HTML Content generated');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] HTML Length: ${htmlContent.length}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Payment Session ID: ${paymentResponse.data!.paymentSessionId}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');

      // Create WebView controller with proper configuration to handle cross-origin
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Creating WebViewController...');
      
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..enableZoom(true)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ⏳ Loading progress: $progress%');
            },
            onPageStarted: (url) {
              // Note: Callback URL should be intercepted in onNavigationRequest
              // This is just for logging other page navigations
              if (!url.contains('/api/payments/callback')) {
                AppLogger.d('💳 [PAYMENT_WEBVIEW] Page started: $url');
              }
            },
            onPageFinished: (url) {
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ PAGE FINISHED');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] URL: $url');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Cashfree URL: ${url.contains('payments.cashfree.com') || url.contains('cashfree.com')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Backend URL: ${url.contains('cloudfunctions.net')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Current loading state: $_isLoading');
              
              // If we're on Cashfree page, log it
              if (url.contains('payments.cashfree.com') || url.contains('cashfree.com')) {
                AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ Successfully navigated to Cashfree payment page');
                AppLogger.d('💳 [PAYMENT_WEBVIEW] Cashfree page should be visible now');
              } else if (url.contains('cloudfunctions.net')) {
                AppLogger.d('💳 [PAYMENT_WEBVIEW] Navigated to backend URL (callback or redirect)');
              }
              
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
              AppLogger.e('💳 [PAYMENT_WEBVIEW] ❌ WEB RESOURCE ERROR');
              AppLogger.e('💳 [PAYMENT_WEBVIEW] Error Code: ${error.errorCode}');
              AppLogger.e('💳 [PAYMENT_WEBVIEW] Error Type: ${error.errorType}');
              AppLogger.e('💳 [PAYMENT_WEBVIEW] Description: ${error.description}');
              AppLogger.e('💳 [PAYMENT_WEBVIEW] Failed URL: ${error.url}');
              AppLogger.e('💳 [PAYMENT_WEBVIEW] Is ORB Error: ${error.description.contains('ERR_BLOCKED_BY_ORB')}');
              AppLogger.e('💳 [PAYMENT_WEBVIEW] Is Abort Error: ${error.description.contains('ERR_ABORTED')}');
              
              // Ignore ORB errors - they're expected when redirecting to Cashfree
              if (error.description.contains('ERR_BLOCKED_BY_ORB') || 
                  error.description.contains('ERR_ABORTED')) {
                AppLogger.w('💳 [PAYMENT_WEBVIEW] ⚠️ ORB/Abort error (expected during form submission)');
                AppLogger.w('💳 [PAYMENT_WEBVIEW] This is normal when submitting forms to external domains');
                // Don't show error to user - this is normal during form submission
              } else {
                AppLogger.e('💳 [PAYMENT_WEBVIEW] ❌ Unexpected WebView error occurred');
                if (mounted && !error.description.contains('ERR_BLOCKED_BY_ORB')) {
                  SnackbarUtils.showError(context, 'Payment page error: ${error.description}');
                }
              }
              AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
            },
            onNavigationRequest: (request) {
              // Intercept callback URL navigation to prevent loading backend response
              if (request.url.contains('/api/payments/callback')) {
                AppLogger.d('💳 [PAYMENT_WEBVIEW] Callback URL detected in navigation request: ${request.url}');
                
                // Parse order_id from URL
                String? orderId;
                try {
                  final uri = Uri.parse(request.url);
                  orderId = uri.queryParameters['order_id'];
                  AppLogger.d('💳 [PAYMENT_WEBVIEW] Order ID from callback: $orderId');
                } catch (e) {
                  AppLogger.w('💳 [PAYMENT_WEBVIEW] Could not parse callback URL: $e');
                }
                
                // Prevent navigation and close WebView
                if (mounted) {
                  AppLogger.d('💳 [PAYMENT_WEBVIEW] Preventing navigation and closing WebView');
                  // Close WebView and return orderId (or true if orderId not found) to indicate payment completion
                  Navigator.of(context).pop(orderId ?? true);
                }
                
                // Prevent the WebView from loading the callback URL
                return NavigationDecision.prevent;
              }
              
              // Allow all other navigation (Cashfree pages, banking pages, etc.)
              return NavigationDecision.navigate;
            },
            onUrlChange: (UrlChange change) {
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] 🔗 URL CHANGED');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Old URL: ${change.url}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
            },
          ),
        );
      
      AppLogger.d('💳 [PAYMENT_WEBVIEW] WebViewController created successfully');

      // Load HTML content into WebView
      // Use loadHtmlString with our backend as baseUrl to allow form submission
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Loading HTML into WebView...');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] HTML Content Length: ${htmlContent.length}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Base URL: ${ApiConstants.baseUrl}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] HTML Preview (first 200 chars): ${htmlContent.substring(0, htmlContent.length > 200 ? 200 : htmlContent.length)}...');
      
      // Check if form is present in HTML
      final hasForm = htmlContent.contains('<form');
      final hasCashfreeAction = htmlContent.contains('payments.cashfree.com') || htmlContent.contains('cashfree.com');
      final hasAutoSubmit = htmlContent.contains('setTimeout');
      
      AppLogger.d('💳 [PAYMENT_WEBVIEW] HTML Analysis:');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - Contains <form>: $hasForm');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - Contains Cashfree action: $hasCashfreeAction');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - Contains redirect script: $hasAutoSubmit');
      
      try {
        await controller.loadHtmlString(
          htmlContent,
          baseUrl: ApiConstants.baseUrl, // Use our backend URL as base
        );
        AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ HTML loaded into WebView successfully');
      } catch (loadError, stackTrace) {
        AppLogger.e('💳 [PAYMENT_WEBVIEW] ❌ ERROR loading HTML into WebView', loadError, stackTrace);
        AppLogger.e('💳 [PAYMENT_WEBVIEW] Error type: ${loadError.runtimeType}');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] Error message: $loadError');
        rethrow;
      }

      // Set controller and mark as initialized
      if (mounted) {
        AppLogger.d('💳 [PAYMENT_WEBVIEW] Setting controller and marking as initialized...');
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
        AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ Controller set, isInitialized: $_isInitialized');
        AppLogger.d('💳 [PAYMENT_WEBVIEW] Controller is null: ${_controller == null}');
      } else {
        AppLogger.w('💳 [PAYMENT_WEBVIEW] ⚠️ Widget not mounted, cannot set controller');
      }
      
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
    } catch (e, stackTrace) {
      AppLogger.e('💳 [PAYMENT_WEBVIEW] Error initializing WebView', e, stackTrace);
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
        title: const Text('Payment'),
        backgroundColor: AppColors.trueBlack,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            AppLogger.d('💳 [PAYMENT_WEBVIEW] User closed payment screen');
            context.pop(false);
          },
        ),
      ),
      body: _isInitialized && _controller != null
          ? Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_isLoading)
                  Container(
                    color: Colors.white,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          NeonLoader(),
                          SizedBox(height: 24),
                          Text(
                            'Loading payment page...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Container(
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
            ),
    );
  }
}

