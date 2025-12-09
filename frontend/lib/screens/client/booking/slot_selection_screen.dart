import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/constants.dart';
import '../../../core/utils.dart';
import '../../../providers/cafe_provider.dart';
import '../../../providers/booking_provider.dart';
import '../../../services/cafe_service.dart';
import '../../../services/booking_service.dart';
import '../../../models/booking_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_widget.dart';

/// Slot Selection Screen with Real-Time Availability
class SlotSelectionScreen extends ConsumerStatefulWidget {
  final String cafeId;

  const SlotSelectionScreen({super.key, required this.cafeId});

  @override
  ConsumerState<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends ConsumerState<SlotSelectionScreen> {
  String _stationType = AppConstants.stationTypePc;
  String? _consoleType;
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
    
    // Round opening minute to nearest 30
    if (openMinute > 0 && openMinute < 30) {
      openMinute = 30;
    } else if (openMinute > 30) {
      openMinute = 0;
      openHour++;
    }
    
    // Generate 30-minute slots
    int currentHour = openHour;
    int currentMinute = openMinute;
    
    while (currentHour < closeHour || (currentHour == closeHour && currentMinute <= closeMinute)) {
      final timeStr = '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
      slots.add(timeStr);
      
      // Increment by 30 minutes
      currentMinute += 30;
      if (currentMinute >= 60) {
        currentMinute = 0;
        currentHour++;
      }
      
      // Safety check to prevent infinite loop
      if (slots.length > 48) break;
    }
    
    setState(() {
      _timeSlots = slots;
    });
  }

  /// Load cafe hours for generating time slots
  Future<void> _loadAvailability() async {
    try {
      final dateStr = DateTimeUtils.formatDateForApi(_selectedDate);
      
      // Fetch cafe info to get opening/closing times
      final cafeService = ref.read(cafeServiceProvider);
      final availability = await cafeService.getCafeAvailability(
        widget.cafeId,
        dateStr,
      );
      
      if (mounted && availability != null) {
        setState(() {
          _availability = availability;
          
          // Update time slots based on cafe operating hours
          if (availability.openingTime.isNotEmpty && 
              availability.closingTime.isNotEmpty) {
            _generateTimeSlots(availability.openingTime, availability.closingTime);
          }
        });
      }
    } catch (e) {
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
        consoleType: _stationType == AppConstants.stationTypeConsole ? _consoleType : null,
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
    if (_startTime == null || _endTime == null) {
      SnackbarUtils.showError(context, 'Please select a time slot');
      return;
    }

    if (_selectedStation == null || _availableCount == 0) {
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

      // Create booking with auto-assigned station
      final response = await bookingService.createBooking(
        BookingRequest(
          cafeId: widget.cafeId,
          stationType: _stationType,
          consoleType: _stationType == 'console' ? _consoleType : null,
          stationNumber: _selectedStation!,
          bookingDate: DateTimeUtils.formatDateForApi(_selectedDate),
          startTime: _startTime!,
          endTime: _endTime!,
        ),
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response.success && response.booking != null) {
        // Navigate to confirmation
        context.go(
          '/client/booking/confirm',
          extra: {
            'booking': response.booking!.toJson(),
            'billing': response.billing,
          },
        );
      } else {
        // Show error and stay on page
        SnackbarUtils.showError(context, response.message);
        // Refresh availability in case it changed (but don't await)
        _updateAvailableCount();
      }
    } catch (e) {
      debugPrint('Booking error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarUtils.showError(context, 'Booking failed. Please try again.');
      }
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
                Row(
                  children: [
                    if (cafe.hasPcs)
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.computer,
                          title: 'PC',
                          subtitle: '${cafe.totalPcStations} stations',
                          isSelected: _stationType == AppConstants.stationTypePc,
                          onTap: () {
                            setState(() {
                              _stationType = AppConstants.stationTypePc;
                              _consoleType = null;
                              _availableCount = 0;
                              _selectedStation = null;
                            });
                            // Call async function AFTER setState
                            if (_startTime != null && _endTime != null) {
                              _updateAvailableCount();
                            }
                          },
                        ),
                      ),
                    if (cafe.hasPcs && cafe.hasConsoles)
                      const SizedBox(width: 12),
                    if (cafe.hasConsoles)
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.sports_esports,
                          title: 'Console',
                          subtitle: '${cafe.totalConsoles} units',
                          isSelected: _stationType == AppConstants.stationTypeConsole,
                          onTap: () {
                            setState(() {
                              _stationType = AppConstants.stationTypeConsole;
                              _consoleType = cafe.availableConsoleTypes.isNotEmpty 
                                  ? cafe.availableConsoleTypes.first 
                                  : null;
                              _availableCount = 0;
                              _selectedStation = null;
                            });
                            // Call async function AFTER setState
                            if (_startTime != null && _endTime != null) {
                              _updateAvailableCount();
                            }
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Console Type Selection
                if (_stationType == AppConstants.stationTypeConsole &&
                    cafe.availableConsoleTypes.isNotEmpty) ...[
                  const Text(
                    'Select Console',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cafe.availableConsoleTypes.map((type) {
                      final info = cafe.consoles[type]!;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _consoleType = type;
                            _availableCount = 0;
                            _selectedStation = null;
                          });
                          // Call async function AFTER setState
                          if (_startTime != null && _endTime != null) {
                            _updateAvailableCount();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _consoleType == type
                                ? AppColors.neonPurple.withOpacity(0.15)
                                : AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _consoleType == type
                                  ? AppColors.neonPurple
                                  : AppColors.cardDark,
                            ),
                          ),
                          child: Text(
                            '${ConsoleUtils.getDisplayName(type)} (${info.quantity})',
                            style: TextStyle(
                              color: _consoleType == type
                                  ? AppColors.neonPurple
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

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
                                    ? '$_availableCount ${_stationType == 'pc' ? 'PC' : _consoleType ?? 'console'}${_availableCount > 1 ? 's' : ''} available'
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
                      final isStart = _startTime == time;
                      final isEnd = _endTime == time;
                      final isInRange = _startTime != null &&
                          _endTime != null &&
                          _timeToMinutes(time) > _timeToMinutes(_startTime!) &&
                          _timeToMinutes(time) < _timeToMinutes(_endTime!);

                      return GestureDetector(
                        onTap: () {
                          // Determine if we should fetch availability after setState
                          bool shouldFetch = false;
                          
                          // Calculate before setState
                          if (_startTime != null && _endTime == null) {
                            if (_timeToMinutes(time) > _timeToMinutes(_startTime!)) {
                              shouldFetch = true; // Will set end time, need to fetch
                            }
                          }
                          
                          setState(() {
                            if (_startTime == null) {
                              // First tap: set start time
                              _startTime = time;
                              _endTime = null;
                              _availableCount = 0;
                              _selectedStation = null;
                            } else if (_endTime == null) {
                              // Second tap: set end time (must be after start)
                              if (_timeToMinutes(time) > _timeToMinutes(_startTime!)) {
                                _endTime = time;
                              } else {
                                // Clicked before start time, reset start
                                _startTime = time;
                                _availableCount = 0;
                                _selectedStation = null;
                              }
                            } else {
                              // Third tap: reset and start new selection
                              _startTime = time;
                              _endTime = null;
                              _availableCount = 0;
                              _selectedStation = null;
                            }
                          });
                          
                          // Call async function AFTER setState completes
                          if (shouldFetch) {
                            _updateAvailableCount();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isStart || isEnd
                                ? AppColors.neonPurple
                                : isInRange
                                    ? AppColors.neonPurple.withOpacity(0.3)
                                    : AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isStart || isEnd
                                  ? AppColors.neonPurple
                                  : isInRange
                                      ? AppColors.neonPurple.withOpacity(0.5)
                                      : AppColors.cardDark,
                            ),
                          ),
                          child: Text(
                            time,
                            style: TextStyle(
                              color: isStart || isEnd
                                  ? Colors.white
                                  : isInRange
                                      ? AppColors.neonPurple
                                      : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isStart || isEnd ? FontWeight.bold : FontWeight.normal,
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
                ? _confirmBooking
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
