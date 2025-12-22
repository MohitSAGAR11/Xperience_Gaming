import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../core/utils.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/custom_button.dart';

/// Booking Confirmation Screen
class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmationScreen({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    final booking = bookingData['booking'] != null
        ? Booking.fromJson(bookingData['booking'])
        : null;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // If no parent screen, redirect to home
          if (!context.canPop()) {
            context.go(Routes.clientHome);
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
              // If no parent screen, redirect to home
              if (!context.canPop()) {
                context.go(Routes.clientHome);
              } else {
                context.pop();
              }
            },
          ),
          title: const Text('Booking Confirmed'),
        ),
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Success Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your gaming session has been booked',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Booking Details Card
              if (booking != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardDark),
                  ),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.store,
                        label: 'Cafe',
                        value: booking.cafe?.name ?? 'Gaming Cafe',
                      ),
                      const Divider(color: AppColors.cardDark, height: 24),
                      _DetailRow(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: DateTimeUtils.formatDateShort(
                          DateTime.parse(booking.bookingDate),
                        ),
                      ),
                      const Divider(color: AppColors.cardDark, height: 24),
                      _DetailRow(
                        icon: Icons.access_time,
                        label: 'Time',
                        value:
                            '${DateTimeUtils.formatTimeString(booking.startTime)} - ${DateTimeUtils.formatTimeString(booking.endTime)}',
                      ),
                      const Divider(color: AppColors.cardDark, height: 24),
                      _DetailRow(
                        icon: Icons.timer,
                        label: 'Duration',
                        value: DateTimeUtils.formatDuration(booking.durationHours),
                      ),
                      const Divider(color: AppColors.cardDark, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            CurrencyUtils.formatINR(booking.totalAmount),
                            style: const TextStyle(
                              color: AppColors.cyberCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

             

              const Spacer(),

              // Buttons
              GlowButton(
                text: 'VIEW MY BOOKINGS',
                onPressed: () => context.go(Routes.myBookings),
              ),
              const SizedBox(height: 12),
              CyberOutlineButton(
                text: 'Back to Home',
                onPressed: () => context.go(Routes.clientHome),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

