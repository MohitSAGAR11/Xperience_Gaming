import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme.dart';
import '../../../core/utils.dart';
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

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.trueBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(
              cafeBookingsProvider(CafeBookingsParams(cafeId: cafeId)),
            ),
            color: AppColors.cyberCyan,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: response.bookings.length,
              itemBuilder: (context, index) {
                final booking = response.bookings[index];
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
                          const Icon(Icons.calendar_today,
                              color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            DateTimeUtils.formatDateShort(
                              DateTime.parse(booking.bookingDate),
                            ),
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 16),
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
                );
              },
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
    );
  }
}

