import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../config/constants.dart';
import '../../../core/utils.dart';
import '../../../providers/cafe_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/cafe_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/input_field.dart';
import '../../../widgets/image_gallery_manager.dart';

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
  final _phoneNumberController = TextEditingController();
  final _mapsLinkController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _totalPcStationsController = TextEditingController();

  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isDataLoading = false;
  double? _latitude;
  double? _longitude;
  String? _locationError;
  List<String> _photos = [];
  bool get isEditing => widget.cafeId != null;

  // Operating Hours
  TimeOfDay _openingTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    
    // Check verification status for new cafes
    if (!isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Refresh user profile to get latest verification status
        await ref.read(authProvider.notifier).refreshProfile();
        
        final user = ref.read(currentUserProvider);
        if (user != null && user.isOwner && !user.isVerifiedOwner) {
          context.go(Routes.verificationPending);
          return;
        }
        // Get GPS location automatically for new cafes
        _getCurrentLocation();
      });
    } else {
      _loadCafeData();
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
        _phoneNumberController.text = cafe.phoneNumber;
        _mapsLinkController.text = cafe.mapsLink;
        _hourlyRateController.text = cafe.hourlyRate.toString();
        _totalPcStationsController.text = cafe.totalPcStations.toString();
        _latitude = cafe.latitude;
        _longitude = cafe.longitude;
        _photos = List.from(cafe.photos ?? []);
        
        // Load operating hours
        _openingTime = _parseTimeString(cafe.openingTime);
        _closingTime = _parseTimeString(cafe.closingTime);
        
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
    _phoneNumberController.dispose();
    _mapsLinkController.dispose();
    _hourlyRateController.dispose();
    _totalPcStationsController.dispose();
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

  /// Get current location automatically (fallback if maps link doesn't have coordinates)
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

    // Validate location is captured via GPS
    if (_latitude == null || _longitude == null) {
      SnackbarUtils.showError(context, 'Please enable location services to capture your cafe location');
      return;
    }

    setState(() => _isLoading = true);

    final cafeService = ref.read(cafeServiceProvider);

    final cafeData = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim(),
      'mapsLink': _mapsLinkController.text.trim(),
      'hourlyRate': double.parse(_hourlyRateController.text),
      'totalPcStations': int.parse(_totalPcStationsController.text),
      'latitude': _latitude,
      'longitude': _longitude,
      'openingTime': _formatTimeOfDay(_openingTime),
      'closingTime': _formatTimeOfDay(_closingTime),
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
              NeonTextField(
                controller: _phoneNumberController,
                label: 'Phone Number',
                hint: 'e.g., +91 9876543210',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  // Basic phone validation (10-15 digits, may include +, spaces, dashes)
                  final phoneRegex = RegExp(r'^[\+]?[(]?[0-9]{1,4}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,9}$');
                  if (!phoneRegex.hasMatch(v.trim())) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              NeonTextField(
                controller: _mapsLinkController,
                label: 'Google Maps Link',
                hint: 'Paste Google Maps URL of your cafe',
                prefixIcon: Icons.map,
                keyboardType: TextInputType.url,
                validator: (v) => Validators.validateUrl(v, 'Google Maps link'),
              ),
              const SizedBox(height: 8),
              if (_latitude != null && _longitude != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Location captured via GPS',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isLocationLoading)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.neonPurple,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Capturing location...',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationError ?? 'Location not captured. Please enable location services.',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _getCurrentLocation,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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

              // Photos Section (only show in edit mode)
              if (isEditing && widget.cafeId != null) ...[
                const _SectionHeader(title: 'Cafe Photos'),
                const SizedBox(height: 12),
                ImageGalleryManager(
                  cafeId: widget.cafeId!,
                  initialImages: _photos,
                  onImagesChanged: (updatedImages) {
                    setState(() {
                      _photos = updatedImages;
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Save Button
              GlowButton(
                text: isEditing ? 'UPDATE CAFE' : 'CREATE CAFE',
                isLoading: _isLoading,
                onPressed: _saveCafe,
              ),
              const SizedBox(height: 16),
              if (!isEditing)
                const Text(
                  'You can add photos and more details after creating the cafe.',
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

