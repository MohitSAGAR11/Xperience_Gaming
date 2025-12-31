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

          // Sort bookings: upcoming first, past last
          // Within each group, maintain status priority for display
          final sortedBookings = BookingGroupUtils.sortBookings(response.bookings);
          
          // Group bookings by date (already sorted)
          final groupedBookings = BookingGroupUtils.groupByDate<Booking>(
            sortedBookings,
            (booking) => booking.bookingDate,
          );
          
          // Sort bookings within each date group: by status priority, then by time
          groupedBookings.forEach((dateStr, bookings) {
            bookings.sort((a, b) {
              // Define status priority: pending = 0, confirmed = 1, cancelled = 2, others = 3
              int getStatusPriority(String status) {
                switch (status.toLowerCase()) {
                  case 'pending':
                    return 0;
                  case 'confirmed':
                    return 1;
                  case 'cancelled':
                    return 2;
                  default:
                    return 3;
                }
              }
              
              final priorityA = getStatusPriority(a.status);
              final priorityB = getStatusPriority(b.status);
              
              // First sort by status priority
              if (priorityA != priorityB) {
                return priorityA.compareTo(priorityB);
              }
              
              // If same status, sort by time
              // For today: upcoming times first, past times last
              // For future dates: ascending time
              // For past dates: descending time
              final date = DateTime.parse(dateStr);
              final dateOnly = DateTime(date.year, date.month, date.day);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final isToday = dateOnly.isAtSameMomentAs(today);
              final isPast = dateOnly.isBefore(today);
              
              if (isToday) {
                // For today: check if booking time has passed
                final aDateTime = BookingGroupUtils.getBookingDateTime(a.bookingDate, a.startTime);
                final bDateTime = BookingGroupUtils.getBookingDateTime(b.bookingDate, b.startTime);
                final aIsPast = aDateTime.isBefore(now);
                final bIsPast = bDateTime.isBefore(now);
                
                // Upcoming first, then past
                if (aIsPast && !bIsPast) return 1;
                if (!aIsPast && bIsPast) return -1;
                
                // Both same category, sort by time ascending
                return a.startTime.compareTo(b.startTime);
              } else if (isPast) {
                return b.startTime.compareTo(a.startTime); // Descending for past
              } else {
                return a.startTime.compareTo(b.startTime); // Ascending for upcoming
              }
            });
          });

          // Build list of items (headers + bookings)
          final List<Widget> items = [];
          groupedBookings.forEach((dateStr, bookings) {
            final date = DateTime.parse(dateStr);
            
            // Add date header
            items.add(
              Container(
                margin: EdgeInsets.only(
                  top: items.isNotEmpty ? 24 : 0,
                  bottom: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.neonPurple.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppColors.neonPurple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            BookingGroupUtils.getDateHeaderWithCount(date, bookings.length),
                            style: TextStyle(
                              color: AppColors.neonPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
            
            // Add booking cards for this date
            for (final booking in bookings) {
              items.add(
                _BookingCard(
                  booking: booking,
                  onCancel: () => _showCancelDialog(context, ref, booking),
                ),
              );
            }
          });

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
              children: items,
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

