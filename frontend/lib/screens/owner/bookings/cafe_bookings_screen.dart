import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../core/utils.dart';
import '../../../models/booking_model.dart';
import '../../../providers/booking_provider.dart';
import '../../../widgets/loading_widget.dart';

/// Cafe Bookings Screen (Owner view)
class CafeBookingsScreen extends ConsumerWidget {
  final String cafeId;

  const CafeBookingsScreen({super.key, required this.cafeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(
      cafeBookingsProvider(CafeBookingsParams(cafeId: cafeId)),
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // If no parent screen, redirect to dashboard
          if (!context.canPop()) {
            context.go(Routes.ownerDashboard);
          } else {
            context.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.trueBlack,
        appBar: AppBar(
          backgroundColor: AppColors.trueBlack,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // If no parent screen, redirect to dashboard
              if (!context.canPop()) {
                context.go(Routes.ownerDashboard);
              } else {
                context.pop();
              }
            },
          ),
          title: const Text('Cafe Bookings'),
        ),
      body: bookingsAsync.when(
        data: (response) {
          if (response.bookings.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_today,
              title: 'No bookings yet',
              subtitle: 'Bookings will appear here when customers book your cafe',
            );
          }

          // Sort bookings: upcoming first, past last
          final sortedBookings = BookingGroupUtils.sortBookings(response.bookings);
          
          // Group bookings by date (already sorted)
          final groupedBookings = BookingGroupUtils.groupByDate<Booking>(
            sortedBookings,
            (booking) => booking.bookingDate,
          );
          
          // Sort bookings within each date group by time
          // For today: upcoming times first, past times last
          // For future dates: ascending time
          // For past dates: descending time
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          groupedBookings.forEach((dateStr, bookings) {
            final date = DateTime.parse(dateStr);
            final dateOnly = DateTime(date.year, date.month, date.day);
            final isToday = dateOnly.isAtSameMomentAs(today);
            final isPast = dateOnly.isBefore(today);
            
            bookings.sort((a, b) {
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
                // Past dates: descending time (most recent first)
                return b.startTime.compareTo(a.startTime);
              } else {
                // Future dates: ascending time (earliest first)
                return a.startTime.compareTo(b.startTime);
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
                Container(
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
                            booking.user?.name ?? 'Customer',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
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
                            booking.isPcBooking
                                ? Icons.computer
                                : Icons.sports_esports,
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
                          const Icon(Icons.access_time,
                              color: AppColors.textMuted, size: 16),
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
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }
          });

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(
              cafeBookingsProvider(CafeBookingsParams(cafeId: cafeId)),
            ),
            color: AppColors.cyberCyan,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: items,
            ),
          );
        },
        loading: () => const Center(child: NeonLoader()),
        error: (e, s) => ErrorDisplay(
          message: e.toString(),
          onRetry: () => ref.invalidate(
            cafeBookingsProvider(CafeBookingsParams(cafeId: cafeId)),
          ),
        ),
      ),
      ),
    );
  }
}

