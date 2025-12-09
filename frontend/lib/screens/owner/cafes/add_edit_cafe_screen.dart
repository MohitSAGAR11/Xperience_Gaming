import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../config/constants.dart';
import '../../../core/utils.dart';
import '../../../providers/cafe_provider.dart';
import '../../../services/cafe_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/input_field.dart';

/// Add/Edit Cafe Screen
class AddEditCafeScreen extends ConsumerStatefulWidget {
  final String? cafeId;

  const AddEditCafeScreen({super.key, this.cafeId});

  @override
  ConsumerState<AddEditCafeScreen> createState() => _AddEditCafeScreenState();
}

class _AddEditCafeScreenState extends ConsumerState<AddEditCafeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _totalPcStationsController = TextEditingController();

  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isDataLoading = false;
  double? _latitude;
  double? _longitude;
  String? _locationError;
  bool get isEditing => widget.cafeId != null;

  // Operating Hours
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);

  // Console data - stores quantity and hourly rate for each console type
  final Map<String, int> _consoleQuantities = {};
  final Map<String, TextEditingController> _consoleRateControllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize console rate controllers
    for (final type in AppConstants.consoleTypes) {
      _consoleRateControllers[type] = TextEditingController();
      _consoleQuantities[type] = 0;
    }
    
    if (isEditing) {
      _loadCafeData();
    } else {
      _getCurrentLocation();
    }
  }

  /// Load existing cafe data for editing
  Future<void> _loadCafeData() async {
    if (widget.cafeId == null) return;

    setState(() => _isDataLoading = true);

    final cafeService = ref.read(cafeServiceProvider);
    final cafe = await cafeService.getCafeById(widget.cafeId!);

    if (cafe != null) {
      setState(() {
        _nameController.text = cafe.name;
        _descriptionController.text = cafe.description ?? '';
        _addressController.text = cafe.address;
        _cityController.text = cafe.city;
        _hourlyRateController.text = cafe.hourlyRate.toString();
        _totalPcStationsController.text = cafe.totalPcStations.toString();
        _latitude = cafe.latitude;
        _longitude = cafe.longitude;
        
        // Load operating hours
        _openingTime = _parseTimeString(cafe.openingTime);
        _closingTime = _parseTimeString(cafe.closingTime);
        
        // Load console data
        for (final entry in cafe.consoles.entries) {
          _consoleQuantities[entry.key] = entry.value.quantity;
          _consoleRateControllers[entry.key]?.text = entry.value.hourlyRate.toString();
        }
        
        _isDataLoading = false;
      });
    } else {
      setState(() => _isDataLoading = false);
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to load cafe data');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _hourlyRateController.dispose();
    _totalPcStationsController.dispose();
    for (final controller in _consoleRateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Parse time string (e.g., "09:00:00" or "09:00") to TimeOfDay
  TimeOfDay _parseTimeString(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Format TimeOfDay to string (e.g., "09:00:00")
  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  /// Show time picker
  Future<void> _selectTime(bool isOpening) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? _openingTime : _closingTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.neonPurple,
              surface: AppColors.surfaceDark,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  /// Get current location automatically
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _locationError = null;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition();

      if (position != null) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isLocationLoading = false;
        });
      } else {
        setState(() {
          _isLocationLoading = false;
          _locationError = 'Could not get location. Please enable location services.';
        });
      }
    } catch (e) {
      setState(() {
        _isLocationLoading = false;
        _locationError = 'Error getting location: ${e.toString()}';
      });
    }
  }

  Future<void> _saveCafe() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate location is captured
    if (_latitude == null || _longitude == null) {
      SnackbarUtils.showError(context, 'Please capture your cafe location first');
      return;
    }

    setState(() => _isLoading = true);

    final cafeService = ref.read(cafeServiceProvider);

    // Build console data
    final Map<String, dynamic> consolesData = {};
    for (final type in AppConstants.consoleTypes) {
      final qty = _consoleQuantities[type] ?? 0;
      if (qty > 0) {
        final rate = double.tryParse(_consoleRateControllers[type]?.text ?? '') ?? 0;
        consolesData[type] = {
          'quantity': qty,
          'hourlyRate': rate > 0 ? rate : double.parse(_hourlyRateController.text),
          'games': [],
        };
      }
    }

    final cafeData = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'hourlyRate': double.parse(_hourlyRateController.text),
      'totalPcStations': int.parse(_totalPcStationsController.text),
      'latitude': _latitude,
      'longitude': _longitude,
      'openingTime': _formatTimeOfDay(_openingTime),
      'closingTime': _formatTimeOfDay(_closingTime),
      'consoles': consolesData,
    };

    final response = isEditing
        ? await cafeService.updateCafe(widget.cafeId!, cafeData)
        : await cafeService.createCafe(cafeData);

    setState(() => _isLoading = false);

    if (response.success) {
      // Invalidate the provider to refresh the list
      ref.invalidate(myCafesProvider);
      
      SnackbarUtils.showSuccess(
        context,
        isEditing ? 'Cafe updated successfully' : 'Cafe created successfully',
      );
      context.go(Routes.myCafes);
    } else {
      SnackbarUtils.showError(context, response.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.trueBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(isEditing ? 'Edit Cafe' : 'Add New Cafe'),
      ),
      body: _isDataLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.success),
            )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info Section
              const _SectionHeader(title: 'Basic Information'),
              const SizedBox(height: 12),
              NeonTextField(
                controller: _nameController,
                label: 'Cafe Name',
                hint: 'Enter cafe name',
                prefixIcon: Icons.store,
                validator: (v) => Validators.validateRequired(v, 'Cafe name'),
              ),
              const SizedBox(height: 16),
              NeonTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Describe your cafe',
                prefixIcon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Location Section
              const _SectionHeader(title: 'Location'),
              const SizedBox(height: 12),
              NeonTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Street address',
                prefixIcon: Icons.location_on,
                validator: (v) => Validators.validateRequired(v, 'Address'),
              ),
              const SizedBox(height: 16),
              NeonTextField(
                controller: _cityController,
                label: 'City',
                hint: 'City name',
                prefixIcon: Icons.location_city,
                validator: (v) => Validators.validateRequired(v, 'City'),
              ),
              const SizedBox(height: 16),
              
              // GPS Location - Auto Captured
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _latitude != null && _longitude != null
                        ? AppColors.success.withOpacity(0.5)
                        : _locationError != null
                            ? Colors.red.withOpacity(0.5)
                            : AppColors.cardDark,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gps_fixed,
                          color: _latitude != null && _longitude != null
                              ? AppColors.success
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'GPS Coordinates',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (_isLocationLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.success,
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(
                              Icons.my_location,
                              size: 16,
                              color: AppColors.success,
                            ),
                            label: Text(
                              _latitude != null ? 'Update' : 'Get Location',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLocationLoading)
                      const Text(
                        'Getting your current location...',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      )
                    else if (_locationError != null)
                      Text(
                        _locationError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      )
                    else if (_latitude != null && _longitude != null)
                      Row(
                        children: [
                          Expanded(
                            child: _CoordinateDisplay(
                              label: 'Latitude',
                              value: _latitude!.toStringAsFixed(6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _CoordinateDisplay(
                              label: 'Longitude',
                              value: _longitude!.toStringAsFixed(6),
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Tap "Get Location" to capture your cafe\'s coordinates',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We automatically capture your cafe\'s GPS location for distance-based search',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 24),

              // Operating Hours Section
              const _SectionHeader(title: 'Operating Hours'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimePickerField(
                      label: 'Opening Time',
                      time: _openingTime,
                      onTap: () => _selectTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePickerField(
                      label: 'Closing Time',
                      time: _closingTime,
                      onTap: () => _selectTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Users can only book slots within these operating hours',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 24),

              // Pricing Section
              const _SectionHeader(title: 'PC Gaming'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeonTextField(
                      controller: _hourlyRateController,
                      label: 'Hourly Rate (₹)',
                      hint: 'e.g., 100',
                      prefixIcon: Icons.currency_rupee,
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.validateRequired(v, 'Rate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeonTextField(
                      controller: _totalPcStationsController,
                      label: 'PC Stations',
                      hint: 'e.g., 10',
                      prefixIcon: Icons.computer,
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.validateRequired(v, 'PC count'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Console Section
              const _SectionHeader(title: 'Gaming Consoles (Optional)'),
              const SizedBox(height: 8),
              const Text(
                'Add consoles available at your cafe with quantity and rates',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ...AppConstants.consoleTypes.map((type) => _ConsoleRow(
                consoleType: type,
                displayName: AppConstants.consoleDisplayNames[type] ?? type,
                quantity: _consoleQuantities[type] ?? 0,
                rateController: _consoleRateControllers[type]!,
                onQuantityChanged: (qty) {
                  setState(() {
                    _consoleQuantities[type] = qty;
                  });
                },
              )),
              const SizedBox(height: 32),

              // Save Button
              GlowButton(
                text: isEditing ? 'UPDATE CAFE' : 'CREATE CAFE',
                isLoading: _isLoading,
                onPressed: _saveCafe,
              ),
              const SizedBox(height: 16),
              if (!isEditing)
                const Text(
                  'You can add games, console inventory, and photos after creating the cafe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
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
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CoordinateDisplay extends StatelessWidget {
  final String label;
  final String value;

  const _CoordinateDisplay({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.trueBlack,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConsoleRow extends StatelessWidget {
  final String consoleType;
  final String displayName;
  final int quantity;
  final TextEditingController rateController;
  final ValueChanged<int> onQuantityChanged;

  const _ConsoleRow({
    required this.consoleType,
    required this.displayName,
    required this.quantity,
    required this.rateController,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = quantity > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEnabled ? AppColors.surfaceDark : AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? AppColors.cyberCyan.withOpacity(0.5) : AppColors.cardDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ConsoleUtils.getIcon(consoleType),
                color: isEnabled ? AppColors.cyberCyan : AppColors.textMuted,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: isEnabled ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              // Quantity controls
              Container(
                decoration: BoxDecoration(
                  color: AppColors.trueBlack,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      color: AppColors.textMuted,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: quantity > 0
                          ? () => onQuantityChanged(quantity - 1)
                          : null,
                    ),
                    Container(
                      width: 32,
                      alignment: Alignment.center,
                      child: Text(
                        quantity.toString(),
                        style: TextStyle(
                          color: isEnabled ? AppColors.cyberCyan : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      color: AppColors.cyberCyan,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => onQuantityChanged(quantity + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Hourly Rate: ₹',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: rateController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rate',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: AppColors.trueBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '/hr',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${quantity} unit${quantity > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppColors.cyberCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerField({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: AppColors.neonPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

