import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// A service for handling biometric authentication.
///
/// This class provides methods to check for biometric hardware availability
/// and to trigger the authentication prompt for fingerprint or face recognition.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if biometric hardware is available on the device.
  ///
  /// - Returns a [Future<bool>] which is `true` if biometrics are available,
  ///   and `false` otherwise.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print("Error checking biometrics: $e");
      return false;
    }
  }

  /// Triggers the biometric authentication prompt (fingerprint, face, etc.).
  ///
  /// Before prompting, it checks if biometric authentication is available.
  ///
  /// - Returns `true` if authentication is successful, `false` otherwise.
  Future<bool> authenticate() async {
    try {
      // First, check if biometrics are available
      if (!await canCheckBiometrics()) {
        return false;
      }
      
      // Trigger the authentication dialog
      return await _auth.authenticate(
        localizedReason: 'Please scan your fingerprint to mark attendance',
        options: const AuthenticationOptions(
          biometricOnly: true, // Only allow biometric, no PIN fallback
          stickyAuth: true,    // Keep the dialog open on app switch
        ),
      );
    } on PlatformException catch (e) {
      print("Error during authentication: $e");
      return false;
    }
  }
}
