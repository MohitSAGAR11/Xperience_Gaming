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
import 'package:dio/dio.dart';

/// Payment Screen - WebView Implementation
/// Uses server-side HTML form that auto-submits to PayU
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
      AppLogger.d('💳 [PAYMENT_WEBVIEW] 📡 FETCHING PAYMENT HTML FROM BACKEND');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Endpoint: ${ApiConstants.createPayment}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Full URL: ${ApiConstants.baseUrl}${ApiConstants.createPayment}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Request Data:');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - bookingId: ${widget.bookingId}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - amount: ${widget.amount}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - firstName: ${widget.firstName ?? currentUser.name ?? 'Guest'}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - email: ${widget.email ?? currentUser.email ?? ''}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - phone: ${widget.phone ?? currentUser.phone ?? '9999999999'}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - productInfo: ${widget.productInfo ?? 'Booking ${widget.bookingId}'}');
      
      // Use Dio directly to make POST request with proper auth headers and accept HTML
      final dio = ref.read(dioProvider);
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Dio instance obtained');
      
      // Override Accept header to get HTML instead of JSON
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Making POST request with Accept: text/html...');
      final response = await dio.post(
        ApiConstants.createPayment,
        data: {
          'bookingId': widget.bookingId,
          'amount': widget.amount,
          'firstName': widget.firstName ?? currentUser.name ?? 'Guest',
          'email': widget.email ?? currentUser.email ?? '',
          'phone': widget.phone ?? currentUser.phone ?? '9999999999',
          'productInfo': widget.productInfo ?? 'Booking ${widget.bookingId}',
        },
        options: Options(
          headers: {
            'Accept': 'text/html',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.plain, // Get response as String
        ),
      );

      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] 📥 RESPONSE RECEIVED');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Status Code: ${response.statusCode}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Response Headers: ${response.headers}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Response Type: ${response.data.runtimeType}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Has Data: ${response.data != null}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Data Length: ${response.data != null ? (response.data as String).length : 0}');

      if (response.statusCode != 200 || response.data == null) {
        AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] ❌ FAILED TO FETCH PAYMENT HTML');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] Status Code: ${response.statusCode}');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] Has Data: ${response.data != null}');
        AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to load payment page (${response.statusCode})');
          context.pop();
        }
        return;
      }

      final htmlContent = response.data as String;
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ HTML Content received');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] HTML Length: ${htmlContent.length}');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] HTML First 100 chars: ${htmlContent.substring(0, htmlContent.length > 100 ? 100 : htmlContent.length)}...');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');

      // Create WebView controller with proper configuration to handle cross-origin
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] Creating WebViewController...');
      
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ⏳ Loading progress: $progress%');
            },
            onPageStarted: (url) {
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] 📄 PAGE STARTED');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] URL: $url');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is PayU URL: ${url.contains('secure.payu.in') || url.contains('test.payu.in')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Backend URL: ${url.contains('cloudfunctions.net')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Success URL: ${url.contains('/payments/success')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Failure URL: ${url.contains('/payments/failure')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Cancel URL: ${url.contains('/payments/cancel')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
              
              _checkPaymentCallback(url);
            },
            onPageFinished: (url) {
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ PAGE FINISHED');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] URL: $url');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is PayU URL: ${url.contains('secure.payu.in') || url.contains('test.payu.in')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Backend URL: ${url.contains('cloudfunctions.net')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Current loading state: $_isLoading');
              
              // If we're on PayU page, log it
              if (url.contains('secure.payu.in') || url.contains('test.payu.in')) {
                AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅ Successfully navigated to PayU payment page');
                AppLogger.d('💳 [PAYMENT_WEBVIEW] PayU page should be visible now');
              } else if (url.contains('cloudfunctions.net')) {
                AppLogger.w('💳 [PAYMENT_WEBVIEW] ⚠️ Navigated back to backend URL - this might indicate a redirect issue');
                AppLogger.w('💳 [PAYMENT_WEBVIEW] This could mean PayU redirected back or form submission failed');
              }
              
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                AppLogger.d('💳 [PAYMENT_WEBVIEW] Loading state updated to: false');
              }
              
              _checkPaymentCallback(url);
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
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
              
              // Ignore ORB errors - they're expected when submitting to PayU
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
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] 🧭 NAVIGATION REQUEST');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Request URL: ${request.url}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Main Frame: ${request.isMainFrame}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is PayU URL: ${request.url.contains('secure.payu.in') || request.url.contains('test.payu.in')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Is Backend URL: ${request.url.contains('cloudfunctions.net')}');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] Decision: ALLOWING navigation');
              AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
              
              _checkPaymentCallback(request.url);
              // Allow all navigation - including to PayU
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
      final hasPayUAction = htmlContent.contains('secure.payu.in');
      final hasAutoSubmit = htmlContent.contains('setTimeout');
      
      AppLogger.d('💳 [PAYMENT_WEBVIEW] HTML Analysis:');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - Contains <form>: $hasForm');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - Contains PayU action: $hasPayUAction');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] - Contains auto-submit script: $hasAutoSubmit');
      
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

  void _checkPaymentCallback(String url) {
    AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] 🔍 CHECKING PAYMENT CALLBACK');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] URL: $url');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] URL Length: ${url.length}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Contains /payments/success: ${url.contains('/payments/success')}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Contains /payments/failure: ${url.contains('/payments/failure')}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Contains /payments/cancel: ${url.contains('/payments/cancel')}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Contains secure.payu.in: ${url.contains('secure.payu.in')}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Contains test.payu.in: ${url.contains('test.payu.in')}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Contains cloudfunctions.net: ${url.contains('cloudfunctions.net')}');
    AppLogger.d('💳 [PAYMENT_WEBVIEW] Is mounted: $mounted');
    
    if (url.contains('/payments/success')) {
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ✅✅✅ PAYMENT SUCCESS DETECTED ✅✅✅');
      AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
      if (mounted) {
        AppLogger.d('💳 [PAYMENT_WEBVIEW] Showing success message and popping...');
        SnackbarUtils.showSuccess(context, 'Payment successful!');
        context.pop(true);
      } else {
        AppLogger.w('💳 [PAYMENT_WEBVIEW] ⚠️ Widget not mounted, cannot show success');
      }
    } else if (url.contains('/payments/failure')) {
      AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.e('💳 [PAYMENT_WEBVIEW] ❌❌❌ PAYMENT FAILED DETECTED ❌❌❌');
      AppLogger.e('💳 [PAYMENT_WEBVIEW] ========================================');
      if (mounted) {
        AppLogger.e('💳 [PAYMENT_WEBVIEW] Showing error message and popping...');
        SnackbarUtils.showError(context, 'Payment failed. Please try again.');
        context.pop(false);
      } else {
        AppLogger.w('💳 [PAYMENT_WEBVIEW] ⚠️ Widget not mounted, cannot show error');
      }
    } else if (url.contains('/payments/cancel')) {
      AppLogger.w('💳 [PAYMENT_WEBVIEW] ========================================');
      AppLogger.w('💳 [PAYMENT_WEBVIEW] 🚫🚫🚫 PAYMENT CANCELLED DETECTED 🚫🚫🚫');
      AppLogger.w('💳 [PAYMENT_WEBVIEW] ========================================');
      if (mounted) {
        AppLogger.w('💳 [PAYMENT_WEBVIEW] Showing cancel message and popping...');
        SnackbarUtils.showInfo(context, 'Payment cancelled');
        context.pop(false);
      } else {
        AppLogger.w('💳 [PAYMENT_WEBVIEW] ⚠️ Widget not mounted, cannot show cancel');
      }
    } else {
      AppLogger.d('💳 [PAYMENT_WEBVIEW] No payment callback detected - continuing...');
    }
    AppLogger.d('💳 [PAYMENT_WEBVIEW] ========================================');
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
                    color: AppColors.trueBlack,
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
              color: AppColors.trueBlack,
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

