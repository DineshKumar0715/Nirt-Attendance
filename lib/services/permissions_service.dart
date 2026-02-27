import 'package:permission_handler/permission_handler.dart';

/// A service to handle runtime permission requests.
///
/// This class centralizes the logic for requesting necessary permissions
/// from the user, such as location and sensor access.
class PermissionsService {
  /// Requests location and biometric (sensor) permissions.
  ///
  /// This method requests a set of essential permissions required for the app's
  /// core functionality.
  ///
  /// - Returns a [Future<bool>] which is `true` if all requested permissions
  ///   are granted, and `false` otherwise.
  Future<bool> requestInitialPermissions() async {
    // A map of all permissions we need for the app to function.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationWhenInUse,
      Permission.sensors, // Often used for biometrics
    ].request();

    // Check if all permissions in the map were granted.
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    return allGranted;
  }
}
