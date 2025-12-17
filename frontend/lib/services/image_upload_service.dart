import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';

import '../core/api_client.dart';
import '../core/firebase_service.dart';
import '../core/logger.dart';
import '../config/constants.dart';

/// Image Upload Service
class ImageUploadService {
  final ApiClient _apiClient;

  ImageUploadService(this._apiClient);

  /// Upload cafe image
  Future<ImageUploadResponse> uploadCafeImage(
    String cafeId,
    File imageFile,
  ) async {
    try {
      AppLogger.d('📸 Uploading image for cafe: $cafeId');

      // Get auth token from Firebase
      final token = await FirebaseService.getIdToken();
      if (token == null) {
        return ImageUploadResponse(
          success: false,
          message: 'Authentication required',
        );
      }

      // Create multipart request
      final uri = Uri.parse('${ApiConstants.baseUrl}/upload/cafe-image/$cafeId');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      // IMPORTANT: Do NOT manually set 'Content-Type' header!
      // http.MultipartRequest automatically sets it with the correct boundary
      // (e.g., 'multipart/form-data; boundary=----WebKitFormBoundary...')
      // Manually setting it would remove the boundary and cause "Unexpected end of form" errors
      request.headers['Authorization'] = 'Bearer $token';

      // Add image file
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      
      // Determine content type from file extension
      String contentType = 'image/jpeg'; // default
      final extension = imageFile.path.split('.').last.toLowerCase();
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      }
      
      AppLogger.d('📸 File path: ${imageFile.path}');
      AppLogger.d('📸 File extension: $extension');
      AppLogger.d('📸 Content type: $contentType');
      AppLogger.d('📸 File size: $length bytes');
      
      final multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last,
        contentType: MediaType.parse(contentType),
      );
      request.files.add(multipartFile);

      AppLogger.d('📸 Sending request...');

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      AppLogger.d('📸 Response status: ${response.statusCode}');
      AppLogger.d('📸 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return ImageUploadResponse.fromJson(data);
      } else {
        final data = json.decode(response.body);
        return ImageUploadResponse(
          success: false,
          message: data['message'] ?? 'Upload failed',
        );
      }
    } catch (e) {
      AppLogger.d('📸 Upload error: $e');
      return ImageUploadResponse(
        success: false,
        message: 'Error uploading image: $e',
      );
    }
  }

  /// Delete cafe image
  Future<bool> deleteCafeImage(String cafeId, String imageUrl) async {
    try {
      // Get auth token from Firebase
      final token = await FirebaseService.getIdToken();
      if (token == null) {
        return false;
      }

      // Make DELETE request
      final uri = Uri.parse('${ApiConstants.baseUrl}/upload/cafe-image/$cafeId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'imageUrl': imageUrl}),
      );

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('Delete image error: $e');
      return false;
    }
  }
}

/// Image Upload Response
class ImageUploadResponse {
  final bool success;
  final String? message;
  final String? url;
  final int? totalPhotos;

  ImageUploadResponse({
    required this.success,
    this.message,
    this.url,
    this.totalPhotos,
  });

  factory ImageUploadResponse.fromJson(Map<String, dynamic> json) {
    return ImageUploadResponse(
      success: json['success'] ?? false,
      message: json['message'],
      url: json['data']?['url'],
      totalPhotos: json['data']?['totalPhotos'],
    );
  }
}

/// Image Upload Service Provider
final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ImageUploadService(apiClient);
});

