import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../config/constants.dart';
import '../../../core/utils.dart';
import '../../../core/logger.dart';
import '../../../providers/cafe_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/cafe_service.dart';
import '../../../services/booking_service.dart';
import '../../../services/payment_service.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_widget.dart';
import '../payment/payment_screen_sdk.dart';
import 'booking_confirmation_screen.dart';

/// Slot Selection Screen with Real-Time Availability
class SlotSelectionScreen extends ConsumerStatefulWidget {
  final String cafeId;

  const SlotSelectionScreen({super.key, required this.cafeId});

  @override
  ConsumerState<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends ConsumerState<SlotSelectionScreen> 
    with SingleTickerProviderStateMixin {
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
  int _numberOfPcs = 1; // Number of PCs to book (for group bookings)
  
  // Dynamic time slots based on cafe hours
  List<String> _timeSlots = [];
  
  // Animation controller for availability display
  late AnimationController _availabilityAnimationController;
  late Animation<double> _availabilityFadeAnimation;
  late Animation<double> _availabilityScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _availabilityAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _availabilityFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _availabilityAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _availabilityScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _availabilityAnimationController,
      curve: Curves.elasticOut,
    ));
    
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
      
      // Start animation if availability is already set
      if (_availableCount > 0) {
        _availabilityAnimationController.forward();
      }
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
    
    // Store original values for validation
    final originalOpenHour = openHour;
    final originalCloseHour = closeHour;
    final crossesMidnight = closeHour < openHour;
    
    // If closing hour is less than opening hour, it means the cafe closes after midnight
    // Add 24 hours to closing hour for calculation
    if (crossesMidnight) {
      closeHour += 24;
    }
    
    // Round opening minute to nearest 30
    if (openMinute > 0 && openMinute < 30) {
      openMinute = 30;
    } else if (openMinute > 30) {
      openMinute = 0;
      openHour++;
    }
    
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
        break;
      }
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
        }
      } catch (e, stackTrace) {
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
  /// Handles cafes that operate past midnight (e.g., 9 AM to 1 AM next day)
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
    
    // If cafe availability is loaded, check for midnight crossing
    if (_availability != null) {
      final openMins = _timeToMinutes(_availability!.openingTime);
      final closeMins = _timeToMinutes(_availability!.closingTime);
      final slotMins = _timeToMinutes(time);
      final currentMins = now.hour * 60 + now.minute;
      
      // Check if cafe crosses midnight (closing time < opening time)
      final crossesMidnight = closeMins < openMins;
      
      if (crossesMidnight) {
        // Cafe operates past midnight (e.g., 10:00 to 05:00 next day)
        // If slot is after midnight (slot time < opening time), it's part of the next day's operation
        if (slotMins < openMins) {
          // Slot is after midnight (e.g., 00:00, 00:30, 05:00)
          // These slots are for the NEXT DAY, so they should be available if:
          // 1. Current time is before midnight (currentMins >= openMins), OR
          // 2. Current time is after midnight but hasn't passed the closing time yet
          // 
          // Example: Cafe 10:00-05:00, Current time 4:30 PM (990 mins)
          // - Slot 0:00 (0 mins) is for tomorrow, should be available
          // - Slot 0:00 is unavailable only if current time is after midnight AND past closing time
          
          // If current time is still before midnight (current time >= opening time)
          // then slots after midnight are for tomorrow and should be available
          if (currentMins >= openMins) {
            // Current time is before midnight, so slots after midnight are for tomorrow
            return false; // Available (for tomorrow)
          } else {
            // Current time is after midnight (e.g., 1:00 AM = 60 mins)
            // Slots after midnight are in the past only if current time has passed closing time
            // Example: closing is 05:00 (300 mins), current is 06:00 (360 mins)
            // Then 00:00-05:00 slots are in the past
            return currentMins > closeMins;
          }
        } else {
          // Slot is before midnight (e.g., 10:00 to 23:30)
          // Normal comparison: slot is past if it's before current time
          return slotTime.isBefore(now.subtract(const Duration(minutes: 1)));
        }
      }
    }
    
    // Normal case: cafe doesn't cross midnight, or availability not loaded yet
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
    AppLogger.d('📅 [SLOT_SELECTION] ========================================');
    AppLogger.d('📅 [SLOT_SELECTION] 🔍 VALIDATING END TIME');
    AppLogger.d('📅 [SLOT_SELECTION] Start Time: ${_startTime ?? "null"}');
    AppLogger.d('📅 [SLOT_SELECTION] End Time: $endTime');
    
    if (_startTime == null || _availability == null) {
      AppLogger.d('📅 [SLOT_SELECTION] ❌ Invalid: startTime or availability is null');
      AppLogger.d('📅 [SLOT_SELECTION] ========================================');
      return false;
    }

    final startMins = _timeToMinutes(_startTime!);
    final endMins = _timeToMinutes(endTime);
    final openMins = _timeToMinutes(_availability!.openingTime);
    final closeMins = _timeToMinutes(_availability!.closingTime);

    AppLogger.d('📅 [SLOT_SELECTION] Time Calculations:');
    AppLogger.d('📅 [SLOT_SELECTION] - Start: ${_startTime} = $startMins minutes');
    AppLogger.d('📅 [SLOT_SELECTION] - End: $endTime = $endMins minutes');
    AppLogger.d('📅 [SLOT_SELECTION] - Opening: ${_availability!.openingTime} = $openMins minutes');
    AppLogger.d('📅 [SLOT_SELECTION] - Closing: ${_availability!.closingTime} = $closeMins minutes');

    // Determine if cafe crosses midnight
    final crossesMidnight = closeMins < openMins;
    AppLogger.d('📅 [SLOT_SELECTION] - Crosses Midnight: $crossesMidnight');

    int adjustedStartMins = startMins;
    int adjustedEndMins = endMins;
    int adjustedCloseMins = closeMins;

    if (crossesMidnight) {
      // Cafe crosses midnight (e.g., 09:00 to 01:00 next day)
      adjustedCloseMins = closeMins + 24 * 60; // 01:00 becomes 1500 mins (25:00)
      AppLogger.d('📅 [SLOT_SELECTION] - Adjusted Closing: $adjustedCloseMins minutes (crosses midnight)');

      // If end time is after midnight (less than opening), adjust it
      if (endMins <= closeMins && endMins < openMins) {
        adjustedEndMins = endMins + 24 * 60;
        AppLogger.d('📅 [SLOT_SELECTION] - Adjusted End: $adjustedEndMins minutes (after midnight)');
      }

      // If start time is after midnight, adjust it too
      if (startMins <= closeMins && startMins < openMins) {
        adjustedStartMins = startMins + 24 * 60;
        AppLogger.d('📅 [SLOT_SELECTION] - Adjusted Start: $adjustedStartMins minutes (after midnight)');
      }
    }

    AppLogger.d('📅 [SLOT_SELECTION] Adjusted Values:');
    AppLogger.d('📅 [SLOT_SELECTION] - Adjusted Start: $adjustedStartMins minutes');
    AppLogger.d('📅 [SLOT_SELECTION] - Adjusted End: $adjustedEndMins minutes');
    AppLogger.d('📅 [SLOT_SELECTION] - Adjusted Close: $adjustedCloseMins minutes');

    // End time must be strictly after start time
    if (adjustedEndMins <= adjustedStartMins) {
      AppLogger.d('📅 [SLOT_SELECTION] ❌ Invalid: End time ($adjustedEndMins) must be after start time ($adjustedStartMins)');
      AppLogger.d('📅 [SLOT_SELECTION] ========================================');
      return false;
    }

    // Minimum booking duration is 1 hour (60 minutes)
    final durationMinutes = adjustedEndMins - adjustedStartMins;
    AppLogger.d('📅 [SLOT_SELECTION] - Duration: $durationMinutes minutes (${durationMinutes / 60} hours)');
    if (durationMinutes < 60) {
      AppLogger.d('📅 [SLOT_SELECTION] ❌ Invalid: Duration ($durationMinutes minutes) is less than minimum (60 minutes)');
      AppLogger.d('📅 [SLOT_SELECTION] ========================================');
      return false;
    }

    // End time must not exceed closing time
    if (adjustedEndMins > adjustedCloseMins) {
      AppLogger.d('📅 [SLOT_SELECTION] ❌ Invalid: End time ($adjustedEndMins) exceeds closing time ($adjustedCloseMins)');
      AppLogger.d('📅 [SLOT_SELECTION] ========================================');
      return false;
    }

    AppLogger.d('📅 [SLOT_SELECTION] ✅ VALID END TIME');
    AppLogger.d('📅 [SLOT_SELECTION] Selected Period: ${_startTime} (${DateTimeUtils.formatTimeString(_startTime!)}) to $endTime (${DateTimeUtils.formatTimeString(endTime)})');
    AppLogger.d('📅 [SLOT_SELECTION] Duration: ${durationMinutes / 60} hours');
    AppLogger.d('📅 [SLOT_SELECTION] ========================================');
    return true;
  }

  /// Check if selected duration meets minimum requirement (1 hour)
  bool _meetsMinimumDuration() {
    if (_startTime == null || _endTime == null) return false;
    
    final startMins = _timeToMinutes(_startTime!);
    int endMins = _timeToMinutes(_endTime!);
    
    // Handle midnight crossing
    if (endMins < startMins) {
      endMins += 24 * 60;
    }
    
    final durationMinutes = endMins - startMins;
    return durationMinutes >= 60; // At least 1 hour
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
    AppLogger.d('📅 [SLOT_SELECTION] _updateAvailableCount called');
    
    // If no time selected yet, don't show availability
    if (_startTime == null || _endTime == null) {
      AppLogger.d('📅 [SLOT_SELECTION] No time selected, clearing availability');
      if (mounted) {
        setState(() {
          _availableCount = 0;
          _selectedStation = null;
        });
      }
      return;
    }

    AppLogger.d('📅 [SLOT_SELECTION] Checking availability for: cafeId=${widget.cafeId}, stationType=$_stationType, numberOfPcs=$_numberOfPcs, bookingDate=${DateTimeUtils.formatDateForApi(_selectedDate)}, startTime=$_startTime, endTime=$_endTime');

    if (mounted) {
      setState(() => _isLoadingAvailability = true);
    }

    try {
      final bookingService = ref.read(bookingServiceProvider);
      
      AppLogger.d('📅 [SLOT_SELECTION] Calling getAvailableStations API...');
      // Call optimized backend API (server calculates availability)
      final response = await bookingService.getAvailableStations(
        cafeId: widget.cafeId,
        stationType: _stationType,
        consoleType: null,
        bookingDate: DateTimeUtils.formatDateForApi(_selectedDate),
        startTime: _startTime!,
        endTime: _endTime!,
      );

      AppLogger.d('📅 [SLOT_SELECTION] Availability response received');
      AppLogger.d('📅 [SLOT_SELECTION] Available stations: ${response.availableStations}');
      AppLogger.d('📅 [SLOT_SELECTION] Available count: ${response.availableCount}');
      AppLogger.d('📅 [SLOT_SELECTION] First available: ${response.firstAvailable}');
      AppLogger.d('📅 [SLOT_SELECTION] Total stations: ${response.totalStations}');

      // Check if we have enough consecutive stations for the requested number of PCs
      int availableConsecutiveCount = 0;
      int? firstConsecutiveStation;
      
      if (_numberOfPcs > 1 && response.availableStations.isNotEmpty) {
        // Find consecutive stations starting from the first available
        final sortedStations = List<int>.from(response.availableStations)..sort();
        
        for (int i = 0; i <= sortedStations.length - _numberOfPcs; i++) {
          bool isConsecutive = true;
          for (int j = 1; j < _numberOfPcs; j++) {
            if (sortedStations[i + j] != sortedStations[i] + j) {
              isConsecutive = false;
              break;
            }
          }
          if (isConsecutive) {
            firstConsecutiveStation = sortedStations[i];
            availableConsecutiveCount = response.availableCount; // All stations are available
            break;
          }
        }
      } else {
        // Single PC or no consecutive requirement
        availableConsecutiveCount = response.availableCount;
        firstConsecutiveStation = response.firstAvailable;
      }

      AppLogger.d('📅 [SLOT_SELECTION] After consecutive check:');
      AppLogger.d('📅 [SLOT_SELECTION] - Available consecutive count: $availableConsecutiveCount');
      AppLogger.d('📅 [SLOT_SELECTION] - First consecutive station: $firstConsecutiveStation');

      if (mounted) {
        final previousCount = _availableCount;
        setState(() {
          _availableCount = _numberOfPcs > 1 
            ? (availableConsecutiveCount >= _numberOfPcs ? availableConsecutiveCount : 0)
            : response.availableCount;
          _selectedStation = firstConsecutiveStation ?? response.firstAvailable;
          _isLoadingAvailability = false;
        });
        // Trigger animation if availability changed
        if (previousCount != _availableCount) {
          _availabilityAnimationController.reset();
          _availabilityAnimationController.forward();
        }
      }
    } catch (e) {
      AppLogger.e('📅 [SLOT_SELECTION] Error fetching available stations', e);
      if (mounted) {
        final previousCount = _availableCount;
        setState(() {
          _availableCount = 0;
          _selectedStation = null;
          _isLoadingAvailability = false;
        });
        // Trigger animation if availability changed
        if (previousCount != _availableCount) {
          _availabilityAnimationController.reset();
          _availabilityAnimationController.forward();
        }
        // Show error to user
        SnackbarUtils.showError(context, 'Unable to check availability. Please try again.');
      }
    }
  }

  Future<void> _confirmBooking() async {
    AppLogger.d('📅 [SLOT_SELECTION] ========================================');
    AppLogger.d('📅 [SLOT_SELECTION] === CONFIRM BOOKING STARTED ===');
    
    if (_startTime == null || _endTime == null) {
      AppLogger.w('📅 [SLOT_SELECTION] ERROR: Time slot not selected');
      SnackbarUtils.showError(context, 'Please select a time slot');
      return;
    }

    if (_selectedStation == null || _availableCount == 0) {
      AppLogger.w('📅 [SLOT_SELECTION] ERROR: No stations available');
      AppLogger.w('📅 [SLOT_SELECTION] Selected station: $_selectedStation');
      AppLogger.w('📅 [SLOT_SELECTION] Available count: $_availableCount');
      AppLogger.w('📅 [SLOT_SELECTION] Number of PCs requested: $_numberOfPcs');
      SnackbarUtils.showError(context, _numberOfPcs > 1 
        ? 'Not enough consecutive stations available for $_numberOfPcs PCs'
        : 'No stations available for this time slot');
      return;
    }

    // Check if we have enough stations for the requested number of PCs
    if (_numberOfPcs > 1 && _availableCount < _numberOfPcs) {
      AppLogger.w('📅 [SLOT_SELECTION] ERROR: Not enough consecutive stations');
      SnackbarUtils.showError(context, 'Not enough consecutive stations available. Only $_availableCount available, but $_numberOfPcs requested.');
      return;
    }

    AppLogger.d('📅 [SLOT_SELECTION] Booking details: cafeId=${widget.cafeId}, stationType=$_stationType, stationNumber=$_selectedStation, numberOfPcs=$_numberOfPcs, bookingDate=${DateTimeUtils.formatDateForApi(_selectedDate)}, startTime=$_startTime, endTime=$_endTime');

    // Dismiss keyboard before API call
    FocusScope.of(context).unfocus();

    if (mounted) {
      setState(() => _isLoading = true);
    }

    AppLogger.d('📅 [SLOT_SELECTION] Calling booking service...');
    try {
      final bookingService = ref.read(bookingServiceProvider);

      // Create booking with auto-assigned station
      final response = await bookingService.createBooking(
        BookingRequest(
          cafeId: widget.cafeId,
          stationType: _stationType,
          consoleType: null,
          stationNumber: _selectedStation!,
          numberOfPcs: _numberOfPcs,
          bookingDate: DateTimeUtils.formatDateForApi(_selectedDate),
          startTime: _startTime!,
          endTime: _endTime!,
        ),
      );

      AppLogger.d('📅 [SLOT_SELECTION] Booking response received');
      AppLogger.d('📅 [SLOT_SELECTION] Response success: ${response.success}');
      AppLogger.d('📅 [SLOT_SELECTION] Response message: ${response.message}');

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response.success && response.booking != null) {
        AppLogger.d('📅 [SLOT_SELECTION] ✅ Booking created successfully!');
        AppLogger.d('📅 [SLOT_SELECTION] Booking ID: ${response.booking!.id}');
        AppLogger.d('📅 [SLOT_SELECTION] Total Amount: ₹${response.booking!.totalAmount}');
        AppLogger.d('📅 [SLOT_SELECTION] Navigating to payment screen...');
        
        // Navigate to payment screen and await result
        // Using official Cashfree SDK - SDK manages WebView internally
        if (mounted) {
          final paymentResult = await Navigator.push<dynamic>(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreenSDK(
                bookingId: response.booking!.id,
                amount: response.booking!.totalAmount,
                firstName: response.booking!.user?.name,
                email: response.booking!.user?.email,
                phone: response.booking!.user?.phone,
                productInfo: 'Booking ${response.booking!.id}',
              ),
            ),
          );
          
          AppLogger.d('📅 [SLOT_SELECTION] Payment screen returned');
          AppLogger.d('📅 [SLOT_SELECTION] Payment result: $paymentResult');
          
          // Handle payment result
          if (mounted) {
            // paymentResult can be: String (orderId), true, false, or null
            if (paymentResult == true || paymentResult is String) {
              // Payment completion detected - verify payment
              final orderId = paymentResult is String ? paymentResult : null;
              
              AppLogger.d('📅 [SLOT_SELECTION] ✅ Payment completion detected! Verifying payment...');
              
              if (orderId != null) {
                try {
                  // Call verify endpoint
                  final paymentService = ref.read(paymentServiceProvider);
                  final verifyResponse = await paymentService.verifyPayment(orderId: orderId);
                  
                  if (verifyResponse.success) {
                    AppLogger.d('📅 [SLOT_SELECTION] ✅ Payment verified successfully!');
                    AppLogger.d('📅 [SLOT_SELECTION] Booking ID: ${verifyResponse.data?.bookingId}');
                    AppLogger.d('📅 [SLOT_SELECTION] Payment Status: ${verifyResponse.data?.paymentStatus}');
                  } else {
                    AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Payment verification failed: ${verifyResponse.message}');
                    SnackbarUtils.showError(context, verifyResponse.message);
                  }
                } catch (e) {
                  AppLogger.e('📅 [SLOT_SELECTION] Error verifying payment', e);
                  SnackbarUtils.showError(context, 'Error verifying payment. Please check booking status.');
                }
              }
              
              // Fetch updated booking with group bookings and show confirmation
              AppLogger.d('📅 [SLOT_SELECTION] Fetching updated booking...');
              try {
                // Always fetch fresh data from API to ensure we have all group bookings
                final bookingWithGroup = await bookingService.getBookingWithGroup(response.booking!.id);
                AppLogger.d('📅 [SLOT_SELECTION] Updated booking fetched: ${bookingWithGroup != null}');
                AppLogger.d('📅 [SLOT_SELECTION] Group bookings count: ${bookingWithGroup?.groupBookings?.length ?? 0}');
                
                if (bookingWithGroup != null && mounted) {
                  AppLogger.d('📅 [SLOT_SELECTION] Navigating to confirmation screen...');
                  final Map<String, dynamic> bookingData = {
                    'booking': bookingWithGroup.booking.toJson(),
                  };
                  if (bookingWithGroup.groupBookings != null && bookingWithGroup.groupBookings!.isNotEmpty) {
                    AppLogger.d('📅 [SLOT_SELECTION] Adding ${bookingWithGroup.groupBookings!.length} group bookings to confirmation data');
                    bookingData['groupBookings'] = bookingWithGroup.groupBookings!
                        .map((b) => b.toJson())
                        .toList();
                  } else {
                    AppLogger.w('📅 [SLOT_SELECTION] No group bookings found, but groupBookingId exists: ${bookingWithGroup.booking.groupBookingId}');
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingConfirmationScreen(
                        bookingData: bookingData,
                      ),
                    ),
                  );
                } else {
                  // Fallback: use original booking data
                  AppLogger.w('📅 [SLOT_SELECTION] Using original booking data (fallback)');
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingConfirmationScreen(
                          bookingData: {'booking': response.booking!.toJson()},
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                AppLogger.e('📅 [SLOT_SELECTION] Error fetching updated booking', e);
                // Still show success with original booking data
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingConfirmationScreen(
                        bookingData: {'booking': response.booking!.toJson()},
                      ),
                    ),
                  );
                }
              }
            } else if (paymentResult == false) {
              // Payment failed or cancelled
              AppLogger.w('📅 [SLOT_SELECTION] ❌ Payment failed or cancelled');
              SnackbarUtils.showError(context, 'Payment failed or was cancelled. Please try again.');
              // Stay on slot selection screen
            } else {
              AppLogger.d('📅 [SLOT_SELECTION] Payment screen closed without result');
            }
            // If paymentResult is null, user just closed the screen - do nothing
          }
        }
      } else {
        // Show error and stay on page
        AppLogger.e('📅 [SLOT_SELECTION] ❌ Booking creation failed');
        AppLogger.e('📅 [SLOT_SELECTION] Error message: ${response.message}');
        SnackbarUtils.showError(context, response.message);
        // Refresh availability in case it changed (but don't await)
        _updateAvailableCount();
      }
    } catch (e, stackTrace) {
      AppLogger.e('Booking error', e, stackTrace);
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

    // Validate minimum duration (1 hour)
    if (!_meetsMinimumDuration()) {
      SnackbarUtils.showError(context, 'Minimum booking duration is 1 hour');
      return;
    }

    // Calculate duration and price
    final startMinutes = _timeToMinutes(_startTime!);
    int endMinutes = _timeToMinutes(_endTime!);
    
    // Handle midnight crossing
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60; // Add 24 hours
    }
    
    // Calculate exact duration in hours (preserve decimal precision)
    final durationHours = (endMinutes - startMinutes) / 60.0;
    
    // Get hourly rate
    double hourlyRate = cafe.hourlyRate;
    if (_stationType == AppConstants.stationTypePc && cafe.pcHourlyRate != null) {
      hourlyRate = cafe.pcHourlyRate!;
    }
    
    // Calculate exact amount with decimal precision (no rounding)
    // Example: 1.5 hours * 100/hr = 150.0 (not 200)
    // Multiply by number of PCs for group bookings
    final totalAmount = (hourlyRate * durationHours) * _numberOfPcs;

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
                    label: _numberOfPcs > 1 ? 'Stations' : 'Station',
                    value: _numberOfPcs > 1
                        ? 'PC #$_selectedStation - #${_selectedStation! + _numberOfPcs - 1} ($_numberOfPcs PCs)'
                        : 'PC #$_selectedStation',
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
                        CurrencyUtils.formatINRExact(totalAmount),
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
            // Use Column for better overflow handling on smaller screens
            LayoutBuilder(
              builder: (context, constraints) {
                // Stack vertically on very small screens, horizontally on larger screens
                if (constraints.maxWidth < 300) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: GlowButton(
                          text: 'Pay Now',
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: CyberOutlineButton(
                          text: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                    ],
                  );
                }
                // Horizontal layout for larger screens
                return Row(
                  children: [
                    Expanded(
                      child: CyberOutlineButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlowButton(
                        text: 'Pay Now',
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                );
              },
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Ensure keyboard is dismissed before navigation
          FocusScope.of(context).unfocus();
          // If no parent screen, redirect to home
          if (!context.canPop()) {
            context.go(Routes.clientHome);
          } else {
            context.pop();
          }
        }
      },
      child: GestureDetector(
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
                // If no parent screen, redirect to home
                if (!context.canPop()) {
                  context.go(Routes.clientHome);
                } else {
                  context.pop();
                }
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

                // PC Stations Display - Full Width
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.cyberCyan.withOpacity(0.15),
                        AppColors.neonPurple.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.cyberCyan.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyberCyan.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cyberCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.computer,
                          color: AppColors.cyberCyan,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PC Stations',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${cafe.totalPcStations} ${cafe.totalPcStations == 1 ? 'station' : 'stations'} available',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Number of PCs Selection - Redesigned
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.cyberCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.groups,
                          color: AppColors.cyberCyan,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'How many PCs?',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.cyberCyan.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyberCyan.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyberCyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.computer,
                                      color: AppColors.cyberCyan,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Number of PCs',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$_numberOfPcs PC${_numberOfPcs > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Counter Controls
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.cyberCyan.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _numberOfPcs > 1
                                          ? () {
                                              setState(() {
                                                _numberOfPcs--;
                                                _availableCount = 0;
                                                _selectedStation = null;
                                              });
                                              if (_startTime != null && _endTime != null) {
                                                _updateAvailableCount();
                                              }
                                            }
                                          : null,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          color: _numberOfPcs > 1
                                              ? AppColors.cyberCyan
                                              : AppColors.textMuted,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 60,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.symmetric(
                                        vertical: BorderSide(
                                          color: AppColors.cyberCyan.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '$_numberOfPcs',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.cyberCyan,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _numberOfPcs < 20 &&
                                              _numberOfPcs < (cafe.totalPcStations ?? 1)
                                          ? () {
                                              setState(() {
                                                _numberOfPcs++;
                                                _availableCount = 0;
                                                _selectedStation = null;
                                              });
                                              if (_startTime != null && _endTime != null) {
                                                _updateAvailableCount();
                                              }
                                            }
                                          : null,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: _numberOfPcs < 20 &&
                                                  _numberOfPcs < (cafe.totalPcStations ?? 1)
                                              ? AppColors.cyberCyan
                                              : AppColors.textMuted,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_numberOfPcs > 1) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.cyberCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.cyberCyan.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.cyberCyan,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Consecutive PCs will be booked together',
                                    style: TextStyle(
                                      color: AppColors.cyberCyan.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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
                          'Tap start time, then end time (minimum 1 hour)',
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
                
                // Selected Time and Availability Display - Redesigned with animations
                AnimatedBuilder(
                  animation: _availabilityAnimationController,
                  builder: (context, child) {
                    final isAvailable = _availableCount >= _numberOfPcs;
                    final hasTimeSelected = _startTime != null && _endTime != null;
                    
                    return FadeTransition(
                      opacity: _availabilityFadeAnimation,
                      child: ScaleTransition(
                        scale: _availabilityScaleAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isAvailable && hasTimeSelected
                                  ? AppColors.cyberCyan.withOpacity(0.6)
                                  : hasTimeSelected
                                      ? AppColors.error.withOpacity(0.6)
                                      : AppColors.cardDark,
                              width: 2,
                            ),
                            boxShadow: isAvailable && hasTimeSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.cyberCyan.withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Time Display
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyberCyan.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.access_time,
                                      color: AppColors.cyberCyan,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Time: ${_startTime ?? '--:--'} - ${_endTime ?? '--:--'}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_startTime != null && _endTime != null) ...[
                                const SizedBox(height: 16),
                                // Availability Status
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? AppColors.cyberCyan.withOpacity(0.2)
                                            : AppColors.error.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isAvailable
                                              ? AppColors.cyberCyan.withOpacity(0.5)
                                              : AppColors.error.withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        isAvailable ? Icons.check_circle : Icons.cancel,
                                        color: isAvailable ? AppColors.cyberCyan : AppColors.error,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isAvailable
                                                ? (_numberOfPcs > 1 
                                                    ? '$_numberOfPcs Consecutive PCs Available'
                                                    : '$_availableCount PC${_availableCount > 1 ? 's' : ''} Available')
                                                : (_numberOfPcs > 1
                                                    ? 'Not Enough Consecutive PCs'
                                                    : 'No Availability'),
                                            style: TextStyle(
                                              color: isAvailable 
                                                  ? AppColors.cyberCyan 
                                                  : AppColors.error,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isAvailable && _selectedStation != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _numberOfPcs > 1
                                                  ? 'PC $_selectedStation - ${_selectedStation! + _numberOfPcs - 1}'
                                                  : 'PC $_selectedStation',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ] else if (!isAvailable && _numberOfPcs > 1) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Need $_numberOfPcs, only $_availableCount available',
                                              style: TextStyle(
                                                color: AppColors.error.withOpacity(0.8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isAvailable && _selectedStation != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.cyberCyan.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppColors.cyberCyan,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.cyberCyan.withOpacity(0.3),
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              _numberOfPcs > 1 ? 'PCs' : 'PC',
                                              style: TextStyle(
                                                color: AppColors.cyberCyan.withOpacity(0.8),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              _numberOfPcs > 1 
                                                  ? '$_selectedStation-${_selectedStation! + _numberOfPcs - 1}'
                                                  : '$_selectedStation',
                                              style: TextStyle(
                                                color: AppColors.cyberCyan,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ] else if (_startTime != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.arrow_forward,
                                      color: AppColors.textMuted,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Select end time',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                          AppLogger.d('📅 [SLOT_SELECTION] ========================================');
                          AppLogger.d('📅 [SLOT_SELECTION] 🕐 TIME SLOT CLICKED');
                          AppLogger.d('📅 [SLOT_SELECTION] Clicked Time: $time');
                          AppLogger.d('📅 [SLOT_SELECTION] Clicked Time (Formatted): ${DateTimeUtils.formatTimeString(time)}');
                          AppLogger.d('📅 [SLOT_SELECTION] Current State:');
                          AppLogger.d('📅 [SLOT_SELECTION] - Start Time: ${_startTime ?? "null"} ${_startTime != null ? "(${DateTimeUtils.formatTimeString(_startTime!)})" : ""}');
                          AppLogger.d('📅 [SLOT_SELECTION] - End Time: ${_endTime ?? "null"} ${_endTime != null ? "(${DateTimeUtils.formatTimeString(_endTime!)})" : ""}');
                          AppLogger.d('📅 [SLOT_SELECTION] - Is Past: $isPast');
                          AppLogger.d('📅 [SLOT_SELECTION] - Is In Closed Period: ${_isInClosedPeriod(time)}');
                          
                          // Determine if we should fetch availability after setState
                          bool shouldFetch = false;
                          
                          // Calculate before setState
                          if (_startTime != null && _endTime == null) {
                            // Check if this time is valid as end time
                            final isValidEnd = _isValidEndTime(time);
                            AppLogger.d('📅 [SLOT_SELECTION] Checking if valid end time: $isValidEnd');
                            if (isValidEnd) {
                              shouldFetch = true; // Will set end time, need to fetch
                              AppLogger.d('📅 [SLOT_SELECTION] ✅ Valid end time - will fetch availability');
                            } else {
                              final startMins = _timeToMinutes(_startTime!);
                              int endMins = _timeToMinutes(time);
                              if (endMins < startMins) {
                                endMins += 24 * 60;
                              }
                              final durationMinutes = endMins - startMins;
                              AppLogger.d('📅 [SLOT_SELECTION] ❌ Invalid end time:');
                              AppLogger.d('📅 [SLOT_SELECTION] - Start Minutes: $startMins (${_startTime})');
                              AppLogger.d('📅 [SLOT_SELECTION] - End Minutes: ${_timeToMinutes(time)} (raw), $endMins (adjusted)');
                              AppLogger.d('📅 [SLOT_SELECTION] - Duration Minutes: $durationMinutes');
                              AppLogger.d('📅 [SLOT_SELECTION] - Duration Hours: ${durationMinutes / 60}');
                            }
                          }
                          
                          setState(() {
                            if (_startTime == null) {
                              AppLogger.d('📅 [SLOT_SELECTION] 📍 ACTION: Setting START time (first tap)');
                              // First tap: set start time
                              // Validate: start time must not be in closed period or past
                              if (!_isInClosedPeriod(time) && !isPast) {
                                AppLogger.d('📅 [SLOT_SELECTION] ✅ Validation passed - setting start time');
                                _startTime = time;
                                _endTime = null;
                                _availableCount = 0;
                                _selectedStation = null;
                                AppLogger.d('📅 [SLOT_SELECTION] ✅ Start time set: $time (${DateTimeUtils.formatTimeString(time)})');
                              } else if (isPast) {
                                AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Cannot select past time slot');
                                SnackbarUtils.showError(context, 'Cannot select past time slots');
                              } else {
                                AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Cannot start booking during closed hours');
                                SnackbarUtils.showError(context, 'Cannot start booking during closed hours');
                              }
                            } else if (_endTime == null) {
                              AppLogger.d('📅 [SLOT_SELECTION] 📍 ACTION: Setting END time (second tap)');
                              // Second tap: set end time (must be after start, considering midnight)
                              if (_isValidEndTime(time)) {
                                AppLogger.d('📅 [SLOT_SELECTION] ✅ Validation passed - setting end time');
                                _endTime = time;
                                
                                // Calculate duration for logging
                                final startMins = _timeToMinutes(_startTime!);
                                int endMins = _timeToMinutes(_endTime!);
                                if (endMins < startMins) {
                                  endMins += 24 * 60;
                                }
                                final durationMinutes = endMins - startMins;
                                final durationHours = durationMinutes / 60;
                                
                                AppLogger.d('📅 [SLOT_SELECTION] ✅ End time set: $time (${DateTimeUtils.formatTimeString(time)})');
                                AppLogger.d('📅 [SLOT_SELECTION] 📊 SELECTED TIME PERIOD:');
                                AppLogger.d('📅 [SLOT_SELECTION] - Start: ${_startTime} (${DateTimeUtils.formatTimeString(_startTime!)})');
                                AppLogger.d('📅 [SLOT_SELECTION] - End: ${_endTime} (${DateTimeUtils.formatTimeString(_endTime!)})');
                                AppLogger.d('📅 [SLOT_SELECTION] - Duration: ${durationHours.toStringAsFixed(2)} hours ($durationMinutes minutes)');
                                AppLogger.d('📅 [SLOT_SELECTION] - Start Minutes: $startMins');
                                AppLogger.d('📅 [SLOT_SELECTION] - End Minutes: ${_timeToMinutes(_endTime!)} (raw), $endMins (adjusted)');
                              } else {
                                AppLogger.d('📅 [SLOT_SELECTION] ❌ Validation failed - invalid end time');
                                // Check if it's a duration issue
                                final startMins = _timeToMinutes(_startTime!);
                                int endMins = _timeToMinutes(time);
                                if (endMins < startMins) {
                                  endMins += 24 * 60;
                                }
                                final durationMinutes = endMins - startMins;
                                
                                AppLogger.d('📅 [SLOT_SELECTION] Validation Details:');
                                AppLogger.d('📅 [SLOT_SELECTION] - Start: ${_startTime} (${DateTimeUtils.formatTimeString(_startTime!)}) = $startMins minutes');
                                AppLogger.d('📅 [SLOT_SELECTION] - End: $time (${DateTimeUtils.formatTimeString(time)}) = ${_timeToMinutes(time)} minutes (raw), $endMins minutes (adjusted)');
                                AppLogger.d('📅 [SLOT_SELECTION] - Duration: ${durationMinutes} minutes (${durationMinutes / 60} hours)');
                                
                                if (durationMinutes > 0 && durationMinutes < 60) {
                                  AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Error: Minimum booking duration is 1 hour');
                                  SnackbarUtils.showError(context, 'Minimum booking duration is 1 hour');
                                } else if (endMins <= startMins) {
                                  AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Error: End time must be after start time');
                                  SnackbarUtils.showError(context, 'End time must be after start time');
                                } else {
                                  AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Error: Selected time is outside cafe hours');
                                  SnackbarUtils.showError(context, 'Selected time is outside cafe hours');
                                }
                                
                                // Clicked invalid time, reset to new start
                                if (!_isInClosedPeriod(time) && !isPast) {
                                  AppLogger.d('📅 [SLOT_SELECTION] 🔄 Resetting to new start time: $time');
                                  _startTime = time;
                                  _endTime = null;
                                  _availableCount = 0;
                                  _selectedStation = null;
                                } else if (isPast) {
                                  AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Cannot select past time slots');
                                  SnackbarUtils.showError(context, 'Cannot select past time slots');
                                } else {
                                  AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Cannot start booking during closed hours');
                                  SnackbarUtils.showError(context, 'Cannot start booking during closed hours');
                                }
                              }
                            } else {
                              AppLogger.d('📅 [SLOT_SELECTION] 📍 ACTION: Resetting selection (third tap)');
                              // Third tap: reset and start new selection
                              if (!isPast) {
                                AppLogger.d('📅 [SLOT_SELECTION] 🔄 Resetting to new start time: $time');
                                AppLogger.d('📅 [SLOT_SELECTION] Previous selection was:');
                                AppLogger.d('📅 [SLOT_SELECTION] - Start: ${_startTime} (${DateTimeUtils.formatTimeString(_startTime!)})');
                                AppLogger.d('📅 [SLOT_SELECTION] - End: ${_endTime} (${DateTimeUtils.formatTimeString(_endTime!)})');
                                _startTime = time;
                                _endTime = null;
                                _availableCount = 0;
                                _selectedStation = null;
                                AppLogger.d('📅 [SLOT_SELECTION] ✅ New start time set: $time (${DateTimeUtils.formatTimeString(time)})');
                              } else {
                                AppLogger.w('📅 [SLOT_SELECTION] ⚠️ Cannot select past time slots');
                                SnackbarUtils.showError(context, 'Cannot select past time slots');
                              }
                            }
                          });
                          
                          AppLogger.d('📅 [SLOT_SELECTION] Final State After Selection:');
                          AppLogger.d('📅 [SLOT_SELECTION] - Start Time: ${_startTime ?? "null"} ${_startTime != null ? "(${DateTimeUtils.formatTimeString(_startTime!)})" : ""}');
                          AppLogger.d('📅 [SLOT_SELECTION] - End Time: ${_endTime ?? "null"} ${_endTime != null ? "(${DateTimeUtils.formatTimeString(_endTime!)})" : ""}');
                          AppLogger.d('📅 [SLOT_SELECTION] - Should Fetch Availability: $shouldFetch');
                          AppLogger.d('📅 [SLOT_SELECTION] ========================================');
                          
                          // Call async function AFTER setState completes
                          if (shouldFetch) {
                            AppLogger.d('📅 [SLOT_SELECTION] 🔄 Fetching availability for selected time period...');
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
            text: _availableCount >= _numberOfPcs
                ? (_numberOfPcs > 1 
                    ? 'BOOK $_numberOfPcs PCs NOW'
                    : 'BOOK NOW ($_availableCount available)')
                : _startTime != null && _endTime != null
                    ? (_numberOfPcs > 1
                        ? 'NOT ENOUGH PCs AVAILABLE'
                        : 'NO AVAILABILITY')
                    : 'SELECT TIME SLOT',
            isLoading: _isLoading,
            onPressed: _startTime != null && _endTime != null && _availableCount >= _numberOfPcs && _meetsMinimumDuration()
                ? _showBookingConfirmation
                : null,
          ),
        ),
      ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _availabilityAnimationController.dispose();
    super.dispose();
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
