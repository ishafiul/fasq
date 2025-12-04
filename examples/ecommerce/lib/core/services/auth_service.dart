import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ecommerce/api/api_client.dart';
import 'package:ecommerce/api/models/auth_create_device_uuid_request.dart';
import 'package:ecommerce/api/models/auth_logout_request.dart';
import 'package:ecommerce/api/models/auth_refresh_token_request.dart';
import 'package:ecommerce/api/models/auth_request_otp_request.dart';
import 'package:ecommerce/api/models/auth_request_otp_response.dart';
import 'package:ecommerce/api/models/auth_verify_otp_request.dart';
import 'package:ecommerce/api/models/auth_verify_otp_response.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Authentication service that handles all auth-related operations.
///
/// This service manages:
/// - Device UUID creation and storage
/// - OTP request and verification
/// - Access token management
/// - Logout and token refresh
/// - Secure credential storage
@singleton
class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String _deviceIdKey = 'device_id';
  static const String _accessTokenKey = 'access_token';
  static const String _userEmailKey = 'user_email';

  AuthService(this._apiClient) : _secureStorage = const FlutterSecureStorage();

  /// Creates or retrieves a device UUID.
  ///
  /// This method will:
  /// 1. Check if a device ID exists in secure storage
  /// 2. If not, gather device info and create a new device UUID via API
  /// 3. Store the device ID in secure storage
  /// 4. Return the device ID
  Future<String> createOrGetDeviceUuid() async {
    // Check if device ID already exists
    final existingDeviceId = await _secureStorage.read(key: _deviceIdKey);
    if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
      return existingDeviceId;
    }

    // Gather device information
    final deviceInfo = DeviceInfoPlugin();

    String? deviceType;
    String? deviceModel;
    String? osName;
    String? osVersion;
    bool? isPhysicalDevice;
    String? appVersion;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceType = 'Android';
        deviceModel = androidInfo.model;
        osName = 'Android';
        osVersion = androidInfo.version.release;
        isPhysicalDevice = androidInfo.isPhysicalDevice;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceType = 'iOS';
        deviceModel = iosInfo.model;
        osName = iosInfo.systemName;
        osVersion = iosInfo.systemVersion;
        isPhysicalDevice = iosInfo.isPhysicalDevice;
      }

      // Try to get package info, use fallback if not available
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = packageInfo.version;
      } catch (e) {
        appVersion = '1.0.0'; // Fallback version
      }
    } catch (e) {
      // Fallback to basic info if device info fails
      deviceType = Platform.isAndroid
          ? 'Android'
          : Platform.isIOS
              ? 'iOS'
              : 'Unknown';
      osName = deviceType;
    }

    // Create device UUID request
    final request = AuthCreateDeviceUuidRequest(
      deviceType: deviceType,
      deviceModel: deviceModel,
      osName: osName,
      osVersion: osVersion,
      isPhysicalDevice: isPhysicalDevice,
      appVersion: appVersion,
    );

    // Call API to create/get device UUID
    final response = await _apiClient.auth.postAuthCreateDeviceUuid(body: request);

    // Store device ID
    await _secureStorage.write(key: _deviceIdKey, value: response.deviceId);

    return response.deviceId;
  }

  /// Requests an OTP to be sent to the specified email.
  ///
  /// This method will:
  /// 1. Ensure a device UUID exists
  /// 2. Request OTP from the API
  /// 3. Return the response indicating success or if the device is trusted
  ///
  /// If the device is trusted, it will automatically log in and return an access token.
  Future<AuthRequestOtpResponse> requestOtp(String email) async {
    final deviceId = await createOrGetDeviceUuid();

    final request = AuthRequestOtpRequest(email: email, deviceUuId: deviceId);

    final response = await _apiClient.auth.postAuthOtpRequestOtp(body: request);

    // If trusted device, store access token and email
    if (response.accessToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: response.accessToken);
      await _secureStorage.write(key: _userEmailKey, value: email);
    }

    return response;
  }

  /// Verifies the OTP and logs in the user.
  ///
  /// This method will:
  /// 1. Verify the OTP with the API
  /// 2. Store the access token in secure storage
  /// 3. Store the user email
  /// 4. Return the response with access token
  ///
  /// [isTrusted] - Whether to mark this device as trusted for future logins
  Future<AuthVerifyOtpResponse> verifyOtp({required AuthVerifyOtpRequest request}) async {
    final response = await _apiClient.auth.postAuthOtpVerifyOtp(body: request);

    // Store access token and email on successful verification
    if (response.success && response.accessToken != null) {
      await _secureStorage.write(key: _accessTokenKey, value: response.accessToken);
      await _secureStorage.write(key: _userEmailKey, value: request.email);
    }

    return response;
  }

  /// Logs out the user by deleting the auth session.
  ///
  /// This method will:
  /// 1. Call the logout API
  /// 2. Clear stored access token and email
  /// 3. Return success status
  Future<bool> logout() async {
    final deviceId = await getDeviceId();
    if (deviceId == null) {
      throw Exception('Device ID not found');
    }

    final request = AuthLogoutRequest(deviceId: deviceId);
    final response = await _apiClient.auth.postAuthLogout(body: request);

    if (response.success) {
      // Clear stored credentials
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _userEmailKey);
    }

    return response.success;
  }

  /// Refreshes the access token.
  ///
  /// This method will:
  /// 1. Request a new access token from the API
  /// 2. Store the new access token
  /// 3. Return the new access token
  Future<String> refreshToken() async {
    final deviceId = await getDeviceId();
    if (deviceId == null) {
      throw Exception('Device ID not found');
    }

    final request = AuthRefreshTokenRequest(deviceId: deviceId);
    final response = await _apiClient.auth.postAuthRefreshToken(body: request);

    // Store new access token
    await _secureStorage.write(key: _accessTokenKey, value: response.accessToken);

    return response.accessToken;
  }

  /// Gets the current device ID from secure storage.
  Future<String?> getDeviceId() {
    return _secureStorage.read(key: _deviceIdKey);
  }

  /// Gets the current access token from secure storage.
  Future<String?> getAccessToken() {
    return _secureStorage.read(key: _accessTokenKey);
  }

  /// Gets the stored user email from secure storage.
  Future<String?> getUserEmail() {
    return _secureStorage.read(key: _userEmailKey);
  }

  /// Checks if the user is currently logged in.
  ///
  /// Returns true if an access token exists in secure storage.
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Clears all stored authentication data.
  ///
  /// This is useful for debugging or when the user wants to completely reset.
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
