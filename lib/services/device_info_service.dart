import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// A service to manage unique device identifiers.
///
/// This class handles the creation, storage, and retrieval of a persistent
/// unique ID for each application installation.
class DeviceInfoService {
  final _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();
  
  static const _deviceIdKey = 'unique_device_id';

  /// Gets a truly unique and persistent identifier for this app installation.
  ///
  /// This method first checks if an ID has already been generated and stored
  /// in secure storage. If not, it generates a new Version 4 UUID, saves it
  /// securely, and then returns it. This ensures that every app installation
  /// has its own unique ID that persists across app restarts.
  ///
  /// - Returns a [Future<String>] containing the unique device identifier.
  ///   In case of an error reading from storage, it returns a temporary UUID
  ///   as a fallback.
  Future<String> getUniqueDeviceId() async {
    try {
      // 1. Try to read the ID from secure storage.
      String? deviceId = await _secureStorage.read(key: _deviceIdKey);

      // 2. If no ID is found, it's the first launch on this device.
      if (deviceId == null) {
        // Generate a new, random, and unique ID.
        deviceId = _uuid.v4();
        // Save the new ID securely for all future launches.
        await _secureStorage.write(key: _deviceIdKey, value: deviceId);
      }
      
      return deviceId;
    } catch (e) {
      print("Error getting or creating device ID: $e");
      // As a fallback, generate a temporary ID if storage fails.
      return _uuid.v4();
    }
  }
}
