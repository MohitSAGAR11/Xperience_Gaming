import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/constants.dart';
import '../../../core/utils.dart';
import '../../../core/logger.dart';
import '../../../providers/cafe_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/cafe_service.dart';
import '../../../services/booking_service.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_widget.dart';
import '../payment/payment_screen.dart';

/// Slot Selection Screen with Real-Time Availability
class SlotSelectionScreen extends ConsumerStatefulWidget {
  final String cafeId;

  const SlotSelectionScreen({super.key, required this.cafeId});

  @override
  ConsumerState<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends ConsumerState<SlotSelectionScreen> {
  String _stationType = AppConstants.stationTypePc;
  DateTime _selectedDate = DateTime.now();
  String? _startTime;
  String? _endTime;
  bool _isLoading = false;
  bool _isLoadingAvailability = false;
  
  // Availability data from backend
  CafeAvailability? _availability;
  int _availableCount = 0;
  int? _selectedStation;
  
  // Dynamic time slots based on cafe hours
  List<String> _timeSlots = [];

  @override
  void initState() {
    super.initState();
    
    // Dismiss keyboard immediately when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Unfocus any text fields that might have focus
      FocusScope.of(context).unfocus();
      
      final cafe = ref.read(cafeProvider(widget.cafeId)).valueOrNull;
      if (cafe != null) {
        ref.read(bookingDraftProvider.notifier).setCafe(cafe.id, cafe.name);
        // Generate initial time slots from cafe data
        _generateTimeSlots(cafe.openingTime, cafe.closingTime);
      }
      _loadAvailability();
    });
  }

  /// Generate time slots based on opening and closing time
  void _generateTimeSlots(String openingTime, String closingTime) {
    final slots = <String>[];
    
    // Parse opening time (format: "09:00:00" or "09:00")
    final openParts = openingTime.split(':');
    final closeParts = closingTime.split(':');
    
    int openHour = int.tryParse(openParts[0]) ?? 9;
    int openMinute = openParts.length > 1 ? (int.tryParse(openParts[1]) ?? 0) : 0;
    int closeHour = int.tryParse(closeParts[0]) ?? 22;
    int closeMinute = closeParts.length > 1 ? (int.tryParse(closeParts[1]) ?? 0) : 0;
    
    AppLogger.d('📅 [GENERATE_SLOTS] Original - Open: $openHour:$openMinute, Close: $closeHour:$closeMinute');
    
    // Store original values for validation
    final originalOpenHour = openHour;
    final originalCloseHour = closeHour;
    final crossesMidnight = closeHour < openHour;
    
    // If closing hour is less than opening hour, it means the cafe closes after midnight
    // Add 24 hours to closing hour for calculation
    if (crossesMidnight) {
      closeHour += 24;
      AppLogger.d('📅 [GENERATE_SLOTS] Closing time is next day, adjusted close hour to: $closeHour');
    }
    
    // Round opening minute to nearest 30
    if (openMinute > 0 && openMinute < 30) {
      openMinute = 30;
    } else if (openMinute > 30) {
      openMinute = 0;
      openHour++;
    }
    
    AppLogger.d('📅 [GENERATE_SLOTS] After rounding - Open: $openHour:$openMinute, Close: $closeHour:$closeMinute');
    
    // Generate 30-minute slots from opening to closing
    int currentHour = openHour;
    int currentMinute = openMinute;
    
    while (currentHour < closeHour || (currentHour == closeHour && currentMinute <= closeMinute)) {
      // For display, show hour in 24-hour format (wrap around after 23)
      final displayHour = currentHour % 24;
      final timeStr = '${displayHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
      slots.add(timeStr);
      
      // Increment by 30 minutes
      currentMinute += 30;
      if (currentMinute >= 60) {
        currentMinute = 0;
        currentHour++;
      }
      
      // Safety check to prevent infinite loop (max 48 slots = 24 hours)
      if (slots.length > 48) {
        AppLogger.d('📅 [GENERATE_SLOTS] WARNING: Reached max slot limit (48)');
        break;
      }
    }
    
    AppLogger.d('📅 [GENERATE_SLOTS] Generated ${slots.length} slots');
    if (slots.isNotEmpty) {
      AppLogger.d('📅 [GENERATE_SLOTS] First slot: ${slots.first}, Last slot: ${slots.last}');
      AppLogger.d('📅 [GENERATE_SLOTS] Crosses midnight: $crossesMidnight');
    }
    
    setState(() {
      _timeSlots = slots;
    });
  }

  /// Load cafe hours for generating time slots
  Future<void> _loadAvailability() async {
    try {
      AppLogger.d('📅 [SLOT_SELECTION] Loading availability...');
      final dateStr = DateTimeUtils.formatDateForApi(_selectedDate);
      AppLogger.d('📅 [SLOT_SELECTION] Date formatted: $dateStr');
      
      // Fetch cafe info to get opening/closing times
      final cafeService = ref.read(cafeServiceProvider);
      AppLogger.d('📅 [SLOT_SELECTION] Calling getCafeAvailability...');
      final availability = await cafeService.getCafeAvailability(
        widget.cafeId,
        dateStr,
      );
      
      AppLogger.d('📅 [SLOT_SELECTION] Availability response: ${availability != null ? "received" : "null"}');
      
      if (mounted && availability != null) {
        AppLogger.d('📅 [SLOT_SELECTION] Opening time: ${availability.openingTime}');
        AppLogger.d('📅 [SLOT_SELECTION] Closing time: ${availability.closingTime}');
        AppLogger.d('📅 [SLOT_SELECTION] Total stations: ${availability.pc?.totalStations}');
        
        setState(() {
          _availability = availability;
          
          // Update time slots based on cafe operating hours
          if (availability.openingTime.isNotEmpty && 
              availability.closingTime.isNotEmpty) {
            AppLogger.d('📅 [SLOT_SELECTION] Generating time slots...');
            _generateTimeSlots(availability.openingTime, availability.closingTime);
            AppLogger.d('📅 [SLOT_SELECTION] Generated ${_timeSlots.length} time slots');
          } else {
            AppLogger.d('📅 [SLOT_SELECTION] ERROR: Empty opening/closing times!');
          }
        });
      } else {
        AppLogger.d('📅 [SLOT_SELECTION] ERROR: Availability is null or widget unmounted!');
      }
    } catch (e, stackTrace) {
      AppLogger.d('📅 [SLOT_SELECTION] ERROR loading cafe hours: $e');
      AppLogger.d('📅 [SLOT_SELECTION] Stack trace: $stackTrace');
      debugPrint('Error loading cafe hours: $e');
    }
  }

  /// Normalize time to "HH:mm" format for consistent comparison
  String _normalizeTime(String time) {
    if (time.isEmpty) return time;
    final parts = time.split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    }
    return time;
  }

  /// Convert time string to minutes since midnight for easier comparison
  int _timeToMinutes(String time) {
    final normalized = _normalizeTime(time);
    final parts = normalized.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return hour * 60 + minute;
    }
    return 0;
  }

  /// Check if a time slot is in the past (only for today's date)
  bool _isTimeSlotInPast(String time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    // If selected date is not today, all slots are available
    if (selectedDay.isAfter(today)) {
      return false;
    }
    
    // If selected date is before today, all slots are in the past
    if (selectedDay.isBefore(today)) {
      return true;
    }
    
    // For today's date, check if the time slot is before current time
    final timeParts = time.split(':');
    if (timeParts.length < 2) return false;
    
    final slotHour = int.tryParse(timeParts[0]) ?? 0;
    final slotMinute = int.tryParse(timeParts[1]) ?? 0;
    final slotTime = DateTime(now.year, now.month, now.day, slotHour, slotMinute);
    
    // Slot is in the past if it's before current time (with 1 minute buffer for rounding)
    return slotTime.isBefore(now.subtract(const Duration(minutes: 1)));
  }

  /// Check if a time is in the closed period (between closing and opening)
  /// This prevents selecting times during closed hours as START time
  bool _isInClosedPeriod(String time) {
    if (_availability == null) return false;

    final timeMins = _timeToMinutes(time);
    final openMins = _timeToMinutes(_availability!.openingTime);
    final closeMins = _timeToMinutes(_availability!.closingTime);

    // If closing time is after opening time (same day), no wraparound
    if (closeMins > openMins) {
      // Normal operation (e.g., 09:00 to 22:00)
      // No closed period during the day
      return false;
    }

    // Closing time is before opening time (crosses midnight)
    // Closed period: from closing to opening next day
    // e.g., closes 01:00 (60 mins), opens 09:00 (540 mins)
    // Closed period: 01:00 to 09:00 (exclusive of closing, inclusive of opening-1)
    // So times in range (60, 540) are closed
    return timeMins > closeMins && timeMins < openMins;
  }

  /// Check if a time is valid as an end time given the current start time
  bool _isValidEndTime(String endTime) {
    if (_startTime == null || _availability == null) return false;

    final startMins = _timeToMinutes(_startTime!);
    final endMins = _timeToMinutes(endTime);
    final openMins = _timeToMinutes(_availability!.openingTime);
    final closeMins = _timeToMinutes(_availability!.closingTime);

    // Determine if cafe crosses midnight
    final crossesMidnight = closeMins < openMins;

    int adjustedStartMins = startMins;
    int adjustedEndMins = endMins;
    int adjustedCloseMins = closeMins;

    if (crossesMidnight) {
      // Cafe crosses midnight (e.g., 09:00 to 01:00 next day)
      adjustedCloseMins = closeMins + 24 * 60; // 01:00 becomes 1500 mins (25:00)

      // If end time is after midnight (less than opening), adjust it
      if (endMins <= closeMins && endMins < openMins) {
        adjustedEndMins = endMins + 24 * 60;
      }

      // If start time is after midnight, adjust it too
      if (startMins <= closeMins && startMins < openMins) {
        adjustedStartMins = startMins + 24 * 60;
      }
    }

    // End time must be strictly after start time
    if (adjustedEndMins <= adjustedStartMins) {
      return false;
    }

    // End time must not exceed closing time
    if (adjustedEndMins > adjustedCloseMins) {
      return false;
    }

    return true;
  }

  /// Check if two time ranges overlap
  /// Range 1: [start1, end1), Range 2: [start2, end2)
  bool _timesOverlap(String start1, String end1, String start2, String end2) {
    final s1 = _timeToMinutes(start1);
    final e1 = _timeToMinutes(end1);
    final s2 = _timeToMinutes(start2);
    final e2 = _timeToMinutes(end2);
    
    // Overlap exists if: start1 < end2 AND end1 > start2
    return s1 < e2 && e1 > s2;
  }

  /// Check if a station is available for the selected time slot
  bool _isStationAvailable(List<BookedSlot> bookedSlots) {
    if (_startTime == null || _endTime == null) return true;
    if (bookedSlots.isEmpty) return true;
    
    for (final slot in bookedSlots) {
      if (_timesOverlap(_startTime!, _endTime!, slot.startTime, slot.endTime)) {
        return false; // Conflict found
      }
    }
    return true; // No conflicts
  }

  /// OPTIMIZED: Fetch available stations from backend (server-side calculation)
  /// This is more efficient and prevents race conditions
  Future<void> _updateAvailableCount() async {
    // If no time selected yet, don't show availability
    if (_startTime == null || _endTime == null) {
      if (mounted) {
        setState(() {
          _availableCount = 0;
          _selectedStation = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingAvailability = true);
    }

    try {
      final bookingService = ref.read(bookingServiceProvider);
      
      // Call optimized backend API (server calculates availability)
      final response = await bookingService.getAvailableStations(
        cafeId: widget.cafeId,
        stationType: _stationType,
        consoleType: null,
        bookingDate: DateTimeUtils.formatDateForApi(_selectedDate),
        startTime: _startTime!,
        endTime: _endTime!,
      );

      if (mounted) {
        setState(() {
          _availableCount = response.availableCount;
          _selectedStation = response.firstAvailable;
          _isLoadingAvailability = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching available stations: $e');
      if (mounted) {
        setState(() {
          _availableCount = 0;
          _selectedStation = null;
          _isLoadingAvailability = false;
        });
        // Show error to user
        SnackbarUtils.showError(context, 'Unable to check availability. Please try again.');
      }
    }
  }

  Future<void> _confirmBooking() async {
    AppLogger.d('🎫 ========================================');
    AppLogger.d('🎫 [CONFIRM_BOOKING] METHOD CALLED!');
    AppLogger.d('🎫 Start Time: $_startTime');
    AppLogger.d('🎫 End Time: $_endTime');
    AppLogger.d('🎫 Selected Station: $_selectedStation');
    AppLogger.d('🎫 Available Count: $_availableCount');
    AppLogger.d('🎫 ========================================');
    
    if (_startTime == null || _endTime == null) {
      AppLogger.d('🎫 [CONFIRM_BOOKING] ERROR: Missing time slot');
      SnackbarUtils.showError(context, 'Please select a time slot');
      return;
    }

    if (_selectedStation == null || _availableCount == 0) {
      AppLogger.d('🎫 [CONFIRM_BOOKING] ERROR: No station selected or no availability');
      AppLogger.d('🎫 Selected Station: $_selectedStation');
      AppLogger.d('🎫 Available Count: $_availableCount');
      SnackbarUtils.showError(context, 'No stations available for this time slot');
      return;
    }

    // Dismiss keyboard before API call
    FocusScope.of(context).unfocus();

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final bookingService = ref.read(bookingServiceProvider);

      AppLogger.d('🎫 ========================================');
      AppLogger.d('🎫 [SLOT_SELECTION] Creating booking request...');
      AppLogger.d('🎫 Cafe ID: ${widget.cafeId}');
      AppLogger.d('🎫 Station Type: $_stationType');
      AppLogger.d('🎫 Station Number: $_selectedStation');
      AppLogger.d('🎫 Date: ${DateTimeUtils.formatDateForApi(_selectedDate)}');
      AppLogger.d('🎫 Start Time: $_startTime');
      AppLogger.d('🎫 End Time: $_endTime');
      AppLogger.d('🎫 ========================================');

      // Create booking with auto-assigned station
      final response = await bookingService.createBooking(
        BookingRequest(
          cafeId: widget.cafeId,
          stationType: _stationType,
          consoleType: null,
          stationNumber: _selectedStation!,
          bookingDate: DateTimeUtils.formatDateForApi(_selectedDate),
          startTime: _startTime!,
          endTime: _endTime!,
        ),
      );

      AppLogger.d('🎫 [SLOT_SELECTION] Response received: ${response.success}');
      AppLogger.d('🎫 [SLOT_SELECTION] Message: ${response.message}');

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response.success && response.booking != null) {
        AppLogger.d('🎫 [SLOT_SELECTION] Booking created! Navigating to payment...');
        // Navigate to payment screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                booking: response.booking!,
                amount: response.booking!.totalAmount,
              ),
            ),
          );
        }
      } else {
        // Show error and stay on page
        AppLogger.d('🎫 [SLOT_SELECTION] Booking failed: ${response.message}');
        SnackbarUtils.showError(context, response.message);
        // Refresh availability in case it changed (but don't await)
        _updateAvailableCount();
      }
    } catch (e, stackTrace) {
      AppLogger.d('🎫 ========================================');
      AppLogger.d('🎫 [SLOT_SELECTION] BOOKING ERROR!');
      AppLogger.d('🎫 Error: $e');
      AppLogger.d('🎫 Stack trace: $stackTrace');
      AppLogger.d('🎫 ========================================');
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showError(context, 'Booking failed: $e');
      }
    }
  }

  /// Show booking confirmation bottom sheet
  Future<void> _showBookingConfirmation() async {
    final cafe = ref.read(cafeProvider(widget.cafeId)).valueOrNull;
    if (cafe == null) return;

    // Calculate duration and price
    final startMinutes = _timeToMinutes(_startTime!);
    int endMinutes = _timeToMinutes(_endTime!);
    
    // Handle midnight crossing
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // Add 24 hours
    }
    
    final durationHours = (endMinutes - startMinutes) / 60.0;
    
    // Get hourly rate
    double hourlyRate = cafe.hourlyRate;
    if (_stationType == AppConstants.stationTypePc && cafe.pcHourlyRate != null) {
      hourlyRate = cafe.pcHourlyRate!;
    }
    
    final totalAmount = hourlyRate * durationHours;

    // Check if booking is within 1 hour (for refund warning)
    final bookingDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(_startTime!.split(':')[0]),
      int.parse(_startTime!.split(':')[1]),
    );
    final now = DateTime.now();
    final hoursUntilBooking = bookingDateTime.difference(now).inHours;
    final isWithinOneHour = hoursUntilBooking < 1;

    // Show confirmation bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cyberCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: AppColors.cyberCyan,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm Booking',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Review your booking details',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Booking Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonPurple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _ConfirmationRow(
                    icon: Icons.store,
                    label: 'Cafe',
                    value: cafe.name,
                  ),
                  const Divider(color: AppColors.surfaceDark, height: 24),
                  _ConfirmationRow(
                    icon: Icons.computer,
                    label: 'Station',
                    value: 'PC #$_selectedStation',
                  ),
                  const Divider(color: AppColors.surfaceDark, height: 24),
                  _ConfirmationRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: DateTimeUtils.formatDate(_selectedDate),
                  ),
                  const Divider(color: AppColors.surfaceDark, height: 24),
                  _ConfirmationRow(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: '${DateTimeUtils.formatTimeString(_startTime!)} - ${DateTimeUtils.formatTimeString(_endTime!)}',
                  ),
                  const Divider(color: AppColors.surfaceDark, height: 24),
                  _ConfirmationRow(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: DateTimeUtils.formatDuration(durationHours),
                  ),
                  const Divider(color: AppColors.surfaceDark, height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cyberCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payments,
                          color: AppColors.cyberCyan,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyUtils.formatINR(totalAmount),
                        style: const TextStyle(
                          color: AppColors.cyberCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Refund Policy Warning (if booking is within 1 hour)
            if (isWithinOneHour)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No Refund Policy: This booking is within 1 hour. If you cancel, you will not receive any refund.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Payment Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cyberCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cyberCyan.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.payment, color: AppColors.cyberCyan, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will be redirected to secure payment gateway',
                      style: TextStyle(
                        color: AppColors.cyberCyan,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CyberOutlineButton(
                    text: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GlowButton(
                    text: 'PROCEED TO PAYMENT',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );

    // If confirmed, proceed with booking
    if (confirmed == true && mounted) {
      _confirmBooking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cafeAsync = ref.watch(cafeProvider(widget.cafeId));

    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.trueBlack,
        appBar: AppBar(
          backgroundColor: AppColors.trueBlack,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Ensure keyboard is dismissed before navigation
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Select Slot'),
        ),
        body: cafeAsync.when(
        data: (cafe) {
          if (cafe == null) {
            return const ErrorDisplay(message: 'Cafe not found');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cafe Operating Hours Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cyberCyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.cyberCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Open: ${_normalizeTime(cafe.openingTime)} - ${_normalizeTime(cafe.closingTime)}',
                        style: const TextStyle(
                          color: AppColors.cyberCyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Station Type Selection
                const Text(
                  'What do you want to play?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _TypeCard(
                  icon: Icons.computer,
                  title: 'PC',
                  subtitle: '${cafe.totalPcStations} stations',
                  isSelected: _stationType == AppConstants.stationTypePc,
                  onTap: () {
                    setState(() {
                      _stationType = AppConstants.stationTypePc;
                      _availableCount = 0;
                      _selectedStation = null;
                    });
                    // Call async function AFTER setState
                    if (_startTime != null && _endTime != null) {
                      _updateAvailableCount();
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Date Selection
                const Text(
                  'Select Date',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final date = DateTime.now().add(Duration(days: index));
                      final isSelected = _selectedDate.day == date.day &&
                          _selectedDate.month == date.month;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = date;
                            _startTime = null;
                            _endTime = null;
                            _availableCount = 0;
                            _selectedStation = null;
                          });
                          _loadAvailability();
                        },
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.neonPurple
                                : AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.neonPurple
                                  : AppColors.cardDark,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday % 7],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date.day.toString(),
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Time Selection Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Time',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap start time, then end time',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (_isLoadingAvailability)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cyberCyan,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Selected Time and Availability Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _availableCount > 0 
                          ? AppColors.success.withOpacity(0.5)
                          : _startTime != null && _endTime != null
                              ? AppColors.error.withOpacity(0.5)
                              : AppColors.cardDark,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time: ${_startTime ?? '--:--'} - ${_endTime ?? '--:--'}',
                              style: const TextStyle(
                                color: AppColors.cyberCyan,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            if (_startTime != null && _endTime != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _availableCount > 0
                                    ? '$_availableCount PC${_availableCount > 1 ? 's' : ''} available'
                                    : 'No availability for this time',
                                style: TextStyle(
                                  color: _availableCount > 0 
                                      ? AppColors.success 
                                      : AppColors.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else if (_startTime != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Now select end time',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_availableCount > 0 && _selectedStation != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _stationType == 'pc' ? 'PC' : 'Unit',
                                style: TextStyle(
                                  color: AppColors.success.withOpacity(0.8),
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                '#$_selectedStation',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Time Slots Grid
                if (_timeSlots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: const Center(
                      child: Text(
                        'Loading time slots...',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _timeSlots.map((time) {
                      final isPast = _isTimeSlotInPast(time);
                      final isStart = _startTime == time;
                      final isEnd = _endTime == time;
                      // Check if time is in selected range (handle midnight crossing)
                      bool isInRange = false;
                      if (_startTime != null && _endTime != null) {
                        final timeMins = _timeToMinutes(time);
                        final startMins = _timeToMinutes(_startTime!);
                        int endMins = _timeToMinutes(_endTime!);
                        
                        // If end is before start, it crosses midnight
                        if (endMins < startMins) {
                          endMins += 24 * 60;
                          // If current time is also before start, adjust it
                          int adjustedTimeMins = timeMins;
                          if (timeMins < startMins) {
                            adjustedTimeMins = timeMins + 24 * 60;
                          }
                          isInRange = adjustedTimeMins > startMins && adjustedTimeMins < endMins;
                        } else {
                          // Normal case - no midnight crossing
                          isInRange = timeMins > startMins && timeMins < endMins;
                        }
                      }

                      return GestureDetector(
                        onTap: isPast ? null : () {
                          // Determine if we should fetch availability after setState
                          bool shouldFetch = false;
                          
                          // Calculate before setState
                          if (_startTime != null && _endTime == null) {
                            // Check if this time is valid as end time
                            if (_isValidEndTime(time)) {
                              shouldFetch = true; // Will set end time, need to fetch
                            }
                          }
                          
                          setState(() {
                            if (_startTime == null) {
                              // First tap: set start time
                              // Validate: start time must not be in closed period or past
                              if (!_isInClosedPeriod(time) && !isPast) {
                                _startTime = time;
                                _endTime = null;
                                _availableCount = 0;
                                _selectedStation = null;
                              } else if (isPast) {
                                SnackbarUtils.showError(context, 'Cannot select past time slots');
                              } else {
                                SnackbarUtils.showError(context, 'Cannot start booking during closed hours');
                              }
                            } else if (_endTime == null) {
                              // Second tap: set end time (must be after start, considering midnight)
                              if (_isValidEndTime(time)) {
                                _endTime = time;
                              } else {
                                // Clicked invalid time, reset to new start
                                if (!_isInClosedPeriod(time) && !isPast) {
                                  _startTime = time;
                                  _endTime = null;
                                  _availableCount = 0;
                                  _selectedStation = null;
                                } else if (isPast) {
                                  SnackbarUtils.showError(context, 'Cannot select past time slots');
                                } else {
                                  SnackbarUtils.showError(context, 'Cannot start booking during closed hours');
                                }
                              }
                            } else {
                              // Third tap: reset and start new selection
                              if (!isPast) {
                                _startTime = time;
                                _endTime = null;
                                _availableCount = 0;
                                _selectedStation = null;
                              } else {
                                SnackbarUtils.showError(context, 'Cannot select past time slots');
                              }
                            }
                          });
                          
                          // Call async function AFTER setState completes
                          if (shouldFetch) {
                            _updateAvailableCount();
                          }
                        },
                        child: Opacity(
                          opacity: isPast ? 0.4 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isPast
                                  ? AppColors.surfaceDark
                                  : isStart || isEnd
                                      ? AppColors.neonPurple
                                      : isInRange
                                          ? AppColors.neonPurple.withOpacity(0.3)
                                          : AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isPast
                                    ? AppColors.cardDark.withOpacity(0.5)
                                    : isStart || isEnd
                                        ? AppColors.neonPurple
                                        : isInRange
                                            ? AppColors.neonPurple.withOpacity(0.5)
                                            : AppColors.cardDark,
                              ),
                            ),
                            child: Text(
                              time,
                              style: TextStyle(
                                color: isPast
                                    ? AppColors.textMuted
                                    : isStart || isEnd
                                        ? Colors.white
                                        : isInRange
                                            ? AppColors.neonPurple
                                            : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: isStart || isEnd ? FontWeight.bold : FontWeight.normal,
                                decoration: isPast ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
        loading: () => const Center(child: NeonLoader()),
        error: (error, stack) => ErrorDisplay(message: error.toString()),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
        ),
        child: SafeArea(
          child: GlowButton(
            text: _availableCount > 0 
                ? 'BOOK NOW ($_availableCount available)'
                : _startTime != null && _endTime != null
                    ? 'NO AVAILABILITY'
                    : 'SELECT TIME SLOT',
            isLoading: _isLoading,
            onPressed: _startTime != null && _endTime != null && _availableCount > 0
                ? _showBookingConfirmation
                : null,
          ),
        ),
      ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.neonPurple.withOpacity(0.15)
              : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.neonPurple : AppColors.cardDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? AppColors.neonPurple : AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? AppColors.textSecondary : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation Row Widget for Bottom Sheet
class _ConfirmationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.neonPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.neonPurple,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
