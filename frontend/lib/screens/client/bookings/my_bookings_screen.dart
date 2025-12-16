import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../core/utils.dart';
import '../../../providers/booking_provider.dart';
import '../../../services/booking_service.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/loading_widget.dart';

/// My Bookings Screen
class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  void _showCancelDialog(BuildContext context, WidgetRef ref, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Cancel Booking',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to cancel your booking at ${booking.cafe?.name ?? 'this cafe'}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _cancelBooking(context, ref, booking.id);
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref, String bookingId) async {
    final bookingService = ref.read(bookingServiceProvider);
    final response = await bookingService.cancelBooking(bookingId);

    if (response.success) {
      SnackbarUtils.showSuccess(context, 'Booking cancelled successfully');
      ref.invalidate(myBookingsProvider);
    } else {
      SnackbarUtils.showError(context, response.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Navigate to home instead of exiting app
          context.go(Routes.clientHome);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.trueBlack,
        appBar: AppBar(
          backgroundColor: AppColors.trueBlack,
          title: const Text('My Bookings'),
          automaticallyImplyLeading: false,
        ),
        body: bookingsAsync.when(
        data: (response) {
          if (response.bookings.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_today,
              title: 'No bookings yet',
              subtitle: 'Book your first gaming session!',
            );
          }

          final upcoming = response.categorized?.upcoming ?? [];
          final past = response.categorized?.past ?? [];

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myBookingsProvider),
            color: AppColors.neonPurple,
            child: ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 80, // Account for bottom nav
              ),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const _SectionHeader(title: 'Upcoming'),
                  ...upcoming.map((b) => _BookingCard(
                    booking: b,
                    onCancel: () => _showCancelDialog(context, ref, b),
                  )),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Past'),
                  ...past.map((b) => _BookingCard(
                    booking: b,
                    onCancel: () => _showCancelDialog(context, ref, b),
                  )),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: NeonLoader()),
        error: (error, stack) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(myBookingsProvider),
        ),
      ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onCancel;

  const _BookingCard({required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking.cafe?.name ?? 'Gaming Cafe',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(booking.statusColorHex).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  BookingStatusUtils.getDisplayText(booking.status),
                  style: TextStyle(
                    color: Color(booking.statusColorHex),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                booking.isPcBooking ? Icons.computer : Icons.sports_esports,
                color: AppColors.textMuted,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                booking.stationDisplay,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                DateTimeUtils.getRelativeDate(DateTime.parse(booking.bookingDate)),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                '${DateTimeUtils.formatTimeString(booking.startTime)} - ${DateTimeUtils.formatTimeString(booking.endTime)}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyUtils.formatINR(booking.totalAmount),
                style: const TextStyle(
                  color: AppColors.cyberCyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (booking.canCancel && onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

