import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_role.dart';

class BiometricAuthService {
  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Check if the hardware supports biometrics and is enabled
  static Future<bool> isBiometricsSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Check if fingerprint or other strong biometric is enrolled
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Trigger biometric scanner prompt
  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true, // persistAcrossBackgrounding equivalent
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Check if fingerprint login is configured for this specific role
  static Future<bool> isRoleBiometricsSetup(UserRole role) async {
    try {
      final email = await _storage.read(key: 'bio_email_${role.value}');
      final password = await _storage.read(key: 'bio_password_${role.value}');
      return email != null && password != null;
    } catch (_) {
      return false;
    }
  }

  /// Save generated credentials to device secure storage
  static Future<void> saveCredentials({
    required String email,
    required String password,
    required UserRole role,
    String? fullName,
  }) async {
    await _storage.write(key: 'bio_email_${role.value}', value: email);
    await _storage.write(key: 'bio_password_${role.value}', value: password);
    if (fullName != null) {
      await _storage.write(key: 'bio_name_${role.value}', value: fullName);
    }
  }

  /// Retrieve stored credentials for a specific role
  static Future<Map<String, String>?> getCredentials(UserRole role) async {
    try {
      final email = await _storage.read(key: 'bio_email_${role.value}');
      final password = await _storage.read(key: 'bio_password_${role.value}');
      if (email == null || password == null) return null;
      return {
        'email': email,
        'password': password,
      };
    } catch (_) {
      return null;
    }
  }

  /// Retrieve the saved Full Name for display in UI
  static Future<String?> getRegisteredFullName(UserRole role) async {
    return await _storage.read(key: 'bio_name_${role.value}');
  }

  /// Delete credentials upon explicit user sign-out/disassociation
  static Future<void> clearCredentials(UserRole role) async {
    await _storage.delete(key: 'bio_email_${role.value}');
    await _storage.delete(key: 'bio_password_${role.value}');
    await _storage.delete(key: 'bio_name_${role.value}');
  }
}
