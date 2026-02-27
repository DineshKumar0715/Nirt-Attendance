import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/biometric_service.dart';
import '../../services/location_service.dart';

/// A screen for employees to check in and check out for the day.
///
/// This screen uses biometric authentication ([BiometricService]) and location
/// tracking ([LocationService]) to securely record attendance. It fetches the
/// current day's attendance status to enable or disable the check-in and
/// check-out buttons accordingly.
class CheckInOutScreen extends StatefulWidget {
  /// Creates a [CheckInOutScreen].
  const CheckInOutScreen({super.key});

  @override
  State<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

/// The state for the [CheckInOutScreen].
///
/// Manages the UI state, including loading indicators and status messages.
/// It interacts with biometric, location, and Firestore services to handle
/// the attendance recording process.
class _CheckInOutScreenState extends State<CheckInOutScreen> {
  final BiometricService _biometricService = BiometricService();
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  String _status = "Ready to scan fingerprint.";
  
  // NEW: State variable to hold today's attendance record
  DocumentSnapshot? _todaysRecord;
  bool _isFetchingRecord = true;

  @override
  void initState() {
    super.initState();
    _getTodaysAttendance();
  }

  /// Fetches the current day's attendance record from Firestore.
  ///
  /// This method retrieves the attendance document for the logged-in user for
  /// today's date. The result is used to determine if the user has already
  /// checked in or out, which in turn controls the state of the UI buttons.
  Future<void> _getTodaysAttendance() async {
    final user = Provider.of<AppUser?>(context, listen: false);
    if (user == null) {
      setState(() => _isFetchingRecord = false);
      return;
    }

    final todayDocId = '${user.uid}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    final doc = await FirebaseFirestore.instance.collection('attendance').doc(todayDocId).get();

    if (mounted) {
      setState(() {
        if (doc.exists) {
          _todaysRecord = doc;
        }
        _isFetchingRecord = false;
      });
    }
  }

  /// Initiates and manages the attendance recording process (check-in or check-out).
  ///
  /// This method performs the following steps:
  /// 1. Prompts the user for biometric authentication.
  /// 2. If authentication is successful, it fetches the device's current location.
  /// 3. It then calls the [FirestoreService] to record the check-in or check-out event.
  /// 4. It provides UI feedback throughout the process via snackbars and status text.
  ///
  /// - [isCheckIn]: A boolean flag indicating whether the action is a check-in (`true`)
  ///   or a check-out (`false`).
  Future<void> _recordAttendance(bool isCheckIn) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _status = "Authenticating...";
    });

    final didAuthenticate = await _biometricService.authenticate();
    if (!didAuthenticate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fingerprint authentication failed."), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoading = false;
          _status = "Authentication failed. Please try again.";
        });
      }
      return;
    }

    final user = Provider.of<AppUser?>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    if (user == null) {
        setState(() => _isLoading = false);
        return;
    }

    if (mounted) setState(() => _status = "Getting secure location...");
    
    try {
      final locationData = await _locationService.getCurrentLocationAndAddress();
      final String? coords = locationData['coords'];
      final String? address = locationData['address'];

      if (coords == null || address == null) {
        throw Exception(address ?? "Unable to retrieve location.");
      }
      
      if (mounted) setState(() => _status = "Recording attendance...");

      if (isCheckIn) {
        await firestoreService.checkIn(user.uid, coords, address);
      } else {
        await firestoreService.checkOut(user.uid, coords, address);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${isCheckIn ? 'Check-In' : 'Check-Out'} successful!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Logic to determine button states based on the fetched record
    bool hasCheckedIn = false;
    bool hasCheckedOut = false;

    if (_todaysRecord != null) {
      final data = _todaysRecord!.data() as Map<String, dynamic>;
      hasCheckedIn = data['checkIn'] != null;
      hasCheckedOut = data['checkOut'] != null;
    }

    // Check-in button is enabled only if the user has NOT checked in yet.
    final bool isCheckInEnabled = !hasCheckedIn;
    // Check-out button is enabled only if the user HAS checked in and has NOT checked out yet.
    final bool isCheckOutEnabled = hasCheckedIn && !hasCheckedOut;

    return Scaffold(
      appBar: AppBar(title: const Text("Mark Attendance")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isFetchingRecord
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.fingerprint, size: 80, color: Colors.indigo),
                    const SizedBox(height: 16),
                    const Text(
                      "Scan Fingerprint to Proceed",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      Column(
                        children: [
                          const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 16),
                          Text(_status, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                        ],
                      )
                    else ...[
                      // MODIFIED: `onPressed` is now conditional
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login, color: Colors.white),
                        label: const Text("Check In", style: TextStyle(color: Colors.white)),
                        onPressed: isCheckInEnabled ? () => _recordAttendance(true) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          disabledBackgroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // MODIFIED: `onPressed` is now conditional
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text("Check Out", style: TextStyle(color: Colors.white)),
                        onPressed: isCheckOutEnabled ? () => _recordAttendance(false) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          disabledBackgroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        // Provide helpful status text to the user
                        hasCheckedOut ? "You have already completed your attendance for today." 
                        : hasCheckedIn ? "You have checked in. Ready to check out." 
                        : "You have not checked in yet.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}