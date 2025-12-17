import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;

import '../../config/theme.dart';
import '../../services/image_upload_service.dart';
import '../../core/utils.dart';

/// Image Gallery Manager Widget
/// Allows owners to upload, reorder, and delete cafe images
class ImageGalleryManager extends ConsumerStatefulWidget {
  final String cafeId;
  final List<String> initialImages;
  final Function(List<String>) onImagesChanged;

  const ImageGalleryManager({
    super.key,
    required this.cafeId,
    required this.initialImages,
    required this.onImagesChanged,
  });

  @override
  ConsumerState<ImageGalleryManager> createState() => _ImageGalleryManagerState();
}

class _ImageGalleryManagerState extends ConsumerState<ImageGalleryManager> {
  late List<String> _images;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        // Crop to landscape aspect ratio (16:9)
        final croppedImage = await _cropToLandscape(File(image.path));
        if (croppedImage != null) {
          await _uploadImage(croppedImage);
        } else {
        await _uploadImage(File(image.path));
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error picking image: $e');
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        for (final image in images) {
          // Crop to landscape aspect ratio (16:9)
          final croppedImage = await _cropToLandscape(File(image.path));
          if (croppedImage != null) {
            await _uploadImage(croppedImage);
          } else {
          await _uploadImage(File(image.path));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Error picking images: $e');
      }
    }
  }

  /// Crop image to landscape aspect ratio (16:9)
  Future<File?> _cropToLandscape(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) return null;
      
      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;
      final targetAspectRatio = 16 / 9;
      final currentAspectRatio = originalWidth / originalHeight;
      
      int cropWidth = originalWidth;
      int cropHeight = originalHeight;
      int cropX = 0;
      int cropY = 0;
      
      if (currentAspectRatio > targetAspectRatio) {
        // Image is wider than 16:9, crop width
        cropWidth = (originalHeight * targetAspectRatio).round();
        cropX = (originalWidth - cropWidth) ~/ 2;
      } else {
        // Image is taller than 16:9, crop height
        cropHeight = (originalWidth / targetAspectRatio).round();
        cropY = (originalHeight - cropHeight) ~/ 2;
      }
      
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );
      
      // Resize to max 1920x1080 while maintaining aspect ratio
      final resizedImage = img.copyResize(
        croppedImage,
        width: 1920,
        height: 1080,
        interpolation: img.Interpolation.linear,
      );
      
      // Save to temporary file
      final croppedBytes = img.encodeJpg(resizedImage, quality: 85);
      final tempFile = File('${imageFile.path}_cropped.jpg');
      await tempFile.writeAsBytes(croppedBytes);
      
      return tempFile;
    } catch (e) {
      // If cropping fails, return null to use original image
      return null;
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final uploadService = ref.read(imageUploadServiceProvider);
      
      // Simulate progress (since we can't track actual upload progress easily)
      _simulateProgress();
      
      final response = await uploadService.uploadCafeImage(
        widget.cafeId,
        imageFile,
      );

      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });

      if (response.success && response.url != null) {
        setState(() {
          _images.add(response.url!);
        });
        widget.onImagesChanged(_images);
        
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'Image uploaded successfully!');
        }
      } else {
        if (mounted) {
          SnackbarUtils.showError(
            context,
            response.message ?? 'Upload failed',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
      
      if (mounted) {
        SnackbarUtils.showError(context, 'Error uploading image: $e');
      }
    }
  }

  void _simulateProgress() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isUploading && _uploadProgress < 0.9) {
        setState(() {
          _uploadProgress += 0.1;
        });
        _simulateProgress();
      }
    });
  }

  Future<void> _deleteImage(String imageUrl, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Delete Image',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this image?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final uploadService = ref.read(imageUploadServiceProvider);
      final success = await uploadService.deleteCafeImage(
        widget.cafeId,
        imageUrl,
      );

      if (success) {
        setState(() {
          _images.removeAt(index);
        });
        widget.onImagesChanged(_images);
        
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'Image deleted');
        }
      } else {
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to delete image');
        }
      }
    }
  }

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
    widget.onImagesChanged(_images);
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.cyberCyan),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.neonPurple),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.warning),
                title: const Text(
                  'Choose Multiple',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickMultipleImages();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cafe Photos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_images.length} photo${_images.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (!_isUploading)
              ElevatedButton.icon(
                onPressed: _showImageOptions,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Photos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPurple,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Upload Progress
        if (_isUploading)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Uploading...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: AppColors.cardDark,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.neonPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Image Grid
        if (_images.isEmpty && !_isUploading)
          _buildEmptyState()
        else if (_images.isNotEmpty)
          _buildImageGrid(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cardDark,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'No photos yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add photos to showcase your gaming cafe',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showImageOptions,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add First Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      onReorder: _reorderImages,
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final imageUrl = _images[index];
        final isCover = index == 0;

        return Card(
          key: ValueKey(imageUrl),
          color: AppColors.surfaceDark,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Drag Handle
                const Icon(
                  Icons.drag_indicator,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                
                // Image Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.cardDark,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.neonPurple,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.cardDark,
                      child: const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCover)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cyberCyan,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COVER PHOTO',
                            style: TextStyle(
                              color: AppColors.trueBlack,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (!isCover)
                        Text(
                          'Photo ${index + 1}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'Drag to reorder',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Delete Button
                IconButton(
                  onPressed: () => _deleteImage(imageUrl, index),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

