import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ntp/ntp.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'checkin_checkout_screen.dart';
import 'dart:async';
import 'leave_screen.dart';
import 'attendance_screen.dart';

/// A clock widget that displays time synchronized with a Network Time Protocol (NTP) server.
///
/// This widget fetches the accurate time from an NTP server to ensure the
/// displayed time is not dependent on the user's device clock, which can be
/// easily manipulated. It handles loading and error states gracefully.
class GlobalTimeClock extends StatefulWidget {
  /// Creates a [GlobalTimeClock].
  const GlobalTimeClock({super.key});

  @override
  State<GlobalTimeClock> createState() => _GlobalTimeClockState();
}

/// The state for the [GlobalTimeClock].
///
/// Manages the time fetching, synchronization, and the periodic timer
/// that updates the clock every second.
class _GlobalTimeClockState extends State<GlobalTimeClock> {
  DateTime _correctedTime = DateTime.now();
  Timer? _timer;
  bool _isLoadingTime = true;
  Duration _timeOffset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeTime();
  }

  /// Initializes the clock by fetching time from the NTP server.
  ///
  /// It calculates the offset between the NTP time and the device's local time.
  /// This offset is then used to correct the time displayed in the UI.
  /// A timer is started to update the clock every second.
  Future<void> _initializeTime() async {
    try {
      final ntpTime = await NTP.now().timeout(const Duration(seconds: 5));
      _timeOffset = ntpTime.difference(DateTime.now());
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _correctedTime = DateTime.now().add(_timeOffset);
          });
        }
      });
    } catch (e) {
      print("Error getting network time: $e");
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _correctedTime = DateTime.now();
          });
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTime = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTime) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(color: Colors.black54)),
      );
    }
    return Text(
      DateFormat('hh:mm:ss a').format(_correctedTime),
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// The main home screen or dashboard for an employee.
///
/// This screen provides a summary of the user's day, including a welcome
/// message, an attendance card with check-in/out status, quick actions
/// to apply for leave or view logs, and a summary of their leave balance.
class HomeScreen extends StatelessWidget {
  /// The [PageController] for the main navigation, used for quick actions.
  final PageController pageController;
  /// The index of the leave screen in the main navigation.
  final int leaveScreenIndex;
  /// The index of the attendance screen in the main navigation.
  final int attendanceScreenIndex;

  /// Creates a [HomeScreen].
  ///
  /// - [pageController]: The controller for the main screen's [PageView].
  /// - [leaveScreenIndex]: The page index for the leave screen.
  /// - [attendanceScreenIndex]: The page index for the attendance log screen.
  const HomeScreen({
    super.key,
    required this.pageController,
    this.leaveScreenIndex = 1, // Default for Employee
    this.attendanceScreenIndex = 2, // Default for Employee
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    final todayDocId = user != null ? '${user.uid}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}' : '';

    return Scaffold(
      body: ListView(
        children: [
          _buildHeader(context, user),
          if (user == null)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('attendance').doc(todayDocId).snapshots(),
                    builder: (context, snapshot) {
                      return _buildAttendanceCard(context, snapshot);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text("Quick Actions", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildQuickActions(context),
                  const SizedBox(height: 24),
                  Text("My Summary", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildLeaveBalanceCard(context, user.uid),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the header section of the home screen.
  ///
  /// This includes a welcome message with the user's name, their profile picture,
  /// and their department.
  ///
  /// - [context]: The build context.
  /// - [user]: The currently logged-in [AppUser].
  /// - Returns a [Container] widget for the header.
  Widget _buildHeader(BuildContext context, AppUser? user) {
    ImageProvider _getProfileImage() {
      if (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) {
        return NetworkImage(user.profileImageUrl!);
      } else {
        return const AssetImage('assets/images/default_avatar.png');
      }
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome,',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                    ),
                    Text(
                      user?.name ?? 'Employee',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _getProfileImage(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_center, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user?.department ?? 'No Department Assigned',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main attendance card for the dashboard.
  ///
  /// This card displays the synchronized clock, today's date, current attendance
  /// status, and a button to check in or out. It reflects real-time data from
  /// a Firestore stream.
  ///
  /// - [context]: The build context.
  /// - [snapshot]: The [AsyncSnapshot] from the Firestore stream.
  /// - Returns a [Card] widget.
  Widget _buildAttendanceCard(BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
    String status = "Absent";
    String checkInTime = "--:--";
    String checkOutTime = "--:--";
    String buttonText = "Check In";
    Color buttonColor = Colors.green;
    bool isButtonEnabled = true;
    String? locationAddress;

    if (snapshot.connectionState == ConnectionState.active && snapshot.hasData && snapshot.data!.exists) {
      final data = snapshot.data!.data() as Map<String, dynamic>;
      final hasCheckedIn = data['checkIn'] != null;
      final hasCheckedOut = data['checkOut'] != null;

      if (hasCheckedIn) {
        status = "Present";
        checkInTime = DateFormat.jm().format((data['checkIn'] as Timestamp).toDate());
        buttonText = "Check Out";
        buttonColor = Colors.orange;
        locationAddress = data['checkInLocationAddress'];
      }
      if (hasCheckedOut) {
        status = "Completed";
        checkOutTime = DateFormat.jm().format((data['checkOut'] as Timestamp).toDate());
        buttonText = "Day Completed";
        buttonColor = Colors.grey;
        isButtonEnabled = false;
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const GlobalTimeClock(),
            const SizedBox(height: 8),
            Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())),
            const Divider(height: 32),
            _buildStatusChip("Today's Status", status),
            if (locationAddress != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationAddress,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeInfo("Check-In", checkInTime, Icons.login),
                _buildTimeInfo("Check-Out", checkOutTime, Icons.logout),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isButtonEnabled
                    ? () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInOutScreen()));
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  disabledBackgroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(buttonText, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the "Quick Actions" section.
  ///
  /// This section contains tappable cards that navigate the user to other
  /// screens like "Apply for Leave" and "Attendance Log" using the [pageController].
  ///
  /// - [context]: The build context.
  /// - Returns a [Row] of action cards.
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.edit_calendar,
            label: "Apply for Leave",
            color: Colors.orange,
            onTap: () => pageController.animateToPage(
              leaveScreenIndex, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeInOut,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.history,
            label: "Attendance Log",
            color: Colors.blue,
            onTap: () => pageController.animateToPage(
              attendanceScreenIndex, 
              duration: const Duration(milliseconds: 300), 
              curve: Curves.easeInOut,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a single, tappable card for the "Quick Actions" section.
  ///
  /// - [context]: The build context.
  /// - [icon]: The icon for the action.
  /// - [label]: The text label for the action.
  /// - [color]: The color of the icon.
  /// - [onTap]: The callback function to execute when the card is tapped.
  /// - Returns an [InkWell] wrapped [Card].
  Widget _buildActionCard(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a card that displays the user's annual leave balance.
  ///
  /// It fetches the number of approved leave days taken by the user
  /// from Firestore and displays it.
  ///
  /// - [context]: The build context.
  /// - [uid]: The unique ID of the user.
  /// - Returns a [Card] widget.
  Widget _buildLeaveBalanceCard(BuildContext context, String uid) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<double>(
          future: firestoreService.getApprovedLeaveDays(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return const Center(child: Text("Could not load leave data."));
            }
            final daysTaken = snapshot.data ?? 0.0;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Annual Leaves Taken", style: TextStyle(fontSize: 16)),
                Text(
                  "$daysTaken / 15",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds a small widget to display time information (e.g., check-in time).
  ///
  /// - [title]: The label for the time info (e.g., "Check-In").
  /// - [time]: The time string to display.
  /// - [icon]: The icon to display next to the time.
  /// - Returns a [Column] widget.
  Widget _buildTimeInfo(String title, String time, IconData icon) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }

  /// Builds a styled chip to display the current attendance status.
  ///
  /// The chip's color and icon change based on the status (e.g., "Present", "Absent").
  ///
  /// - [title]: The title for the chip (e.g., "Today's Status").
  /// - [status]: The status string.
  /// - Returns a decorated [Container] widget.
  Widget _buildStatusChip(String title, String status) {
    Color statusColor;
    IconData statusIcon;
    switch(status) {
      case "Present":
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case "Completed":
        statusColor = Colors.grey;
        statusIcon = Icons.done_all;
        break;
      default: // Absent
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Icon(statusIcon, color: statusColor, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}