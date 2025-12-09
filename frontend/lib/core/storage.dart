import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/user_model.dart';

/// Storage Service for secure token and user data management
class StorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  StorageService(this._secureStorage, this._prefs);

  // ============ Token Management ============

  /// Save JWT Token securely
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  /// Get JWT Token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.tokenKey);
  }

  /// Delete JWT Token
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ============ User Data Management ============

  /// Save User Data
  Future<void> saveUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    await _prefs.setString(AppConstants.userKey, userJson);
  }

  /// Get User Data
  User? getUser() {
    final userJson = _prefs.getString(AppConstants.userKey);
    if (userJson == null) return null;
    return User.fromJson(jsonDecode(userJson));
  }

  /// Delete User Data
  Future<void> deleteUser() async {
    await _prefs.remove(AppConstants.userKey);
  }

  // ============ Role Management ============

  /// Save User Role
  Future<void> saveRole(String role) async {
    await _prefs.setString(AppConstants.roleKey, role);
  }

  /// Get User Role
  String? getRole() {
    return _prefs.getString(AppConstants.roleKey);
  }

  /// Check if user is Owner
  bool isOwner() {
    return getRole() == AppConstants.roleOwner;
  }

  /// Check if user is Client
  bool isClient() {
    return getRole() == AppConstants.roleClient;
  }

  // ============ Onboarding ============

  /// Mark onboarding as complete
  Future<void> setOnboardingComplete() async {
    await _prefs.setBool(AppConstants.onboardingKey, true);
  }

  /// Check if onboarding is complete
  bool isOnboardingComplete() {
    return _prefs.getBool(AppConstants.onboardingKey) ?? false;
  }

  // ============ Clear All Data ============

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
  }
}

/// Shared Preferences Provider
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

/// Secure Storage Provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
});

/// Storage Service Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final prefs = ref.watch(sharedPrefsProvider);
  return StorageService(secureStorage, prefs);
});

