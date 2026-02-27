import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// A service to handle location-related functionalities.
///
/// This class is responsible for getting the device's current GPS location,
/// handling location permissions, and converting coordinates into a human-readable
/// address using the Google Geocoding API.
class LocationService {
  // TODO: Secure the API key instead of hardcoding it.
  // --- PASTE YOUR GOOGLE MAPS API KEY HERE ---
  final String _apiKey = "AIzaSyCLZ2eDLnPT0P8AfXjghownDH6UlaSFw3k";

  /// Determines the current position of the device.
  ///
  /// This method checks if location services are enabled and if the necessary
  /// permissions have been granted. If not, it requests them.
  ///
  /// - Throws an error if location services are disabled or permissions are denied.
  /// - Returns a [Future<Position>] containing the device's current location.
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Fetches the current GPS location and converts it to a formatted address.
  ///
  /// This method first determines the device's position and then uses the
  /// Google Geocoding API to get the corresponding address. It also cleans up
  /// the address string.
  ///
  /// - Returns a [Future<Map<String, String?>>] containing the coordinates
  ///   and the formatted address. In case of an error, the values in the map
  ///   may be `null` or contain an error message.
  Future<Map<String, String?>> getCurrentLocationAndAddress() async {
    try {
      Position position = await _determinePosition();
      String coords = '${position.latitude},${position.longitude}';

      // This URL calls the Google Geocoding API directly
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_apiKey');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // We use the 'formatted_address' which is Google's best version of the address
          final String address = data['results'][0]['formatted_address'];
          
          // Clean up the address by removing the country and any Google Plus Codes
          String finalAddress = address.replaceAll(', India', '');
          
          // FIX: Corrected the regular expression by removing the extra hyphen
          finalAddress = finalAddress.replaceAll(RegExp(r'^[A-Z0-9]{4}\+[A-Z0-9]{2,}\s?,'), '').trim();

          return {'coords': coords, 'address': finalAddress};
        } else {
          return {'coords': coords, 'address': 'No address found via Google API.'};
        }
      } else {
        return {'coords': coords, 'address': 'Failed to connect to Google Maps API.'};
      }
    } catch (e) {
      print("Error getting location or address: $e");
      return {'coords': null, 'address': e.toString()};
    }
  }
}