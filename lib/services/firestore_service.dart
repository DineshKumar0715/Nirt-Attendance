import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ntp/ntp.dart';
import '../models/leave_request.dart';
import '../models/user_model.dart';

/// A service class for interacting with Cloud Firestore.
///
/// This class provides methods for performing CRUD operations on Firestore
/// collections such as `attendance`, `users`, and `leaves`.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- ATTENDANCE METHODS (with Late/Early logic) ---

  /// Records a user's check-in time and location in Firestore.
  ///
  /// Also determines if the user is late based on the company's shift start time.
  ///
  /// - [uid]: The user's unique ID.
  /// - [locationCoords]: The geographic coordinates of the check-in location.
  /// - [locationAddress]: The address of the check-in location.
  Future<void> checkIn(String uid, String locationCoords, String locationAddress) async {
    final DateTime now = await NTP.now();
    final String todayDocId = '$uid-${DateFormat('yyyy-MM-dd').format(now)}';

    // Define company shift start time (e.g., 9:30 AM)
    final DateTime shiftStartTime = DateTime(now.year, now.month, now.day, 9, 31);
    
    String remark = "On Time";
    if (now.isAfter(shiftStartTime)) {
      remark = "Late Comer";
    }

    final attendanceData = {
      'uid': uid,
      'date': DateFormat('yyyy-MM-dd').format(now),
      'checkIn': now,
      'checkInLocationCoords': locationCoords,
      'checkInLocationAddress': locationAddress,
      'checkOut': null,
      'checkOutLocationCoords': null,
      'checkOutLocationAddress': null,
      'status': 'Present',
      'remark': remark, 
    };

    await _db.collection('attendance').doc(todayDocId).set(attendanceData, SetOptions(merge: true));
  }

  /// Records a user's check-out time and location in Firestore.
  ///
  /// Determines if the user is leaving early based on the shift end time and
  /// updates their attendance record accordingly.
  ///
  /// - [uid]: The user's unique ID.
  /// - [locationCoords]: The geographic coordinates of the check-out location.
  /// - [locationAddress]: The address of the check-out location.
  Future<void> checkOut(String uid, String locationCoords, String locationAddress) async {
    final DateTime now = await NTP.now();
    final String todayDocId = '$uid-${DateFormat('yyyy-MM-dd').format(now)}';

    // Define company shift end time (e.g., 6:30 PM or 18:30)
    final DateTime shiftEndTime = DateTime(now.year, now.month, now.day, 17, 00);
    final docRef = _db.collection('attendance').doc(todayDocId);
    final doc = await docRef.get();
    
    String remark = "On Time"; 
    if (doc.exists) {
      remark = doc.data()?['remark'] ?? 'On Time'; 
    }

    // Check if the user is checking out before the shift ends
    if (now.isBefore(shiftEndTime)) {
      if (remark == "Late Comer") {
        // If they were already late, append the new remark
        remark += ", Early Check-Out";
      } else {
        // Otherwise, just set the remark
        remark = "Early Check-Out";
      }
    }

    final attendanceData = {
      'checkOut': now,
      'checkOutLocationCoords': locationCoords,
      'checkOutLocationAddress': locationAddress,
      'remark': remark,
    };

    await docRef.update(attendanceData);
  }

  // --- USER & MANAGER METHODS ---

  /// Updates a user's information in the Firestore database.
  ///
  /// - [user]: The [AppUser] object with updated information.
  Future<void> updateUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).update(user.toMap());
  }

  /// Retrieves a stream of all users from the Firestore database.
  ///
  /// - Returns a stream of a list of [AppUser] objects.
  Stream<List<AppUser>> getUsers() {
    return _db.collection('users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList());
  }

  /// Retrieves a specific user by their unique ID.
  ///
  /// - [uid]: The unique ID of the user to retrieve.
  /// - Returns a [Future] that completes with an [AppUser] object, or `null` if not found.
  Future<AppUser?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return AppUser.fromMap(doc.data()!, doc.id);
    }
    return null;
  }
  
  /// Retrieves a stream of direct reports for a given manager.
  ///
  /// - [managerUid]: The unique ID of the manager.
  /// - Returns a stream of a list of [AppUser] objects who report to the manager.
  Stream<List<AppUser>> getDirectReports(String managerUid) {
    return _db
        .collection('users')
        .where('reportsTo', isEqualTo: managerUid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList());
  }
  
  /// Retrieves a stream of all users with the 'manager' or 'hr' role.
  ///
  /// - Returns a stream of a list of [AppUser] objects.
  Stream<List<AppUser>> getAllManagers() {
    return _db
        .collection('users')
        .where('role', whereIn: ['manager', 'hr'])
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList());
  }

  // --- LEAVE METHODS ---

  /// Retrieves a stream of pending leave requests for a manager's direct reports.
  ///
  /// - [managerUid]: The unique ID of the manager.
  /// - Returns a stream of a list of [LeaveRequest] objects.
  Stream<List<LeaveRequest>> getLeaveRequestsForManager(String managerUid) async* {
    final usersSnapshot = await _db
        .collection('users')
        .where('reportsTo', isEqualTo: managerUid)
        .get();
    final reportUids = usersSnapshot.docs.map((doc) => doc.id).toList();

    if (reportUids.isEmpty) {
      yield [];
      return;
    }

    yield* _db
        .collection('leaves')
        .where('uid', whereIn: reportUids)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LeaveRequest.fromFirestore(doc))
            .toList());
  }
  
  /// Submits a new leave application to Firestore.
  ///
  /// - [user]: The user applying for leave.
  /// - [type]: The type of leave (e.g., 'Sick Leave').
  /// - [reason]: The reason for the leave.
  /// - [fromDate]: The start date of the leave.
  /// - [toDate]: The end date of the leave.
  /// - [durationType]: The duration of the leave (e.g., full day, half day).
  /// - [fromTime]: The start time for hourly leave.
  /// - [toTime]: The end time for hourly leave.
  /// - [halfDayPeriod]: The period for half-day leave (e.g., 'firstHalf').
  Future<void> applyLeave({
    required AppUser user,
    required String type,
    required String reason,
    required DateTime fromDate,
    required DateTime toDate,
    required LeaveDurationType durationType,
    String? fromTime,
    String? toTime,
    HalfDayPeriod? halfDayPeriod,
  }) async {
    await _db.collection('leaves').add({
      'uid': user.uid,
      'name': user.name,
      'department': user.department,
      'userRole': user.role.toString().split('.').last,
      'type': type,
      'reason': reason,
      'status': 'pending',
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'timestamp': FieldValue.serverTimestamp(),
      'durationType': durationType.toString().split('.').last,
      'fromTime': fromTime,
      'toTime': toTime,
      'halfDayPeriod': halfDayPeriod?.toString().split('.').last,
    });
  }

  /// Retrieves a stream of pending leave requests for managers and HR.
  ///
  /// - Returns a stream of a list of [LeaveRequest] objects.
  Stream<List<LeaveRequest>> getManagerLeaveRequests() {
    return _db
        .collection('leaves')
        .where('userRole', whereIn: ['manager', 'hr'])
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList());
  }

  /// Retrieves a stream of leave requests that have been pending for more than 24 hours.
  ///
  /// - Returns a stream of a list of escalated [LeaveRequest] objects.
  Stream<List<LeaveRequest>> getEscalatedLeaveRequests() {
    final escalationTime = Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));
    
    return _db
        .collection('leaves')
        .where('userRole', isEqualTo: 'employee')
        .where('status', isEqualTo: 'pending')
        .where('timestamp', isLessThanOrEqualTo: escalationTime)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => LeaveRequest.fromFirestore(doc)).toList());
  }
  
  /// Retrieves a stream of all leave requests, sorted by timestamp.
  ///
  /// - Returns a stream of a list of all [LeaveRequest] objects.
  Stream<List<LeaveRequest>> getAllLeaveRequests() {
    return _db
        .collection('leaves')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final List<LeaveRequest> leaveRequests = [];  
          for (var doc in snapshot.docs) {
            try {
              leaveRequests.add(LeaveRequest.fromFirestore(doc));
            } catch (e) {
              print('Error parsing leave request document: ${doc.id}, error: $e');
            }
          }
          return leaveRequests;
        });
  }

  /// Updates the status of a leave request.
  ///
  /// - [leaveId]: The ID of the leave request to update.
  /// - [status]: The new status (e.g., 'approved', 'rejected').
  Future<void> updateLeaveStatus(String leaveId, String status) {
    return _db.collection('leaves').doc(leaveId).update({'status': status});
  }

  /// Calculates the total number of approved leave days for a user in the current year.
  ///
  /// - [uid]: The unique ID of the user.
  /// - Returns the total number of approved leave days as a [double].
  Future<double> getApprovedLeaveDays(String uid) async {
    final currentYear = DateTime.now().year;
    final yearStart = Timestamp.fromDate(DateTime(currentYear, 1, 1));
    final yearEnd = Timestamp.fromDate(DateTime(currentYear, 12, 31, 23, 59, 59));

    final snapshot = await _db
        .collection('leaves')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .where('fromDate', isGreaterThanOrEqualTo: yearStart)
        .where('fromDate', isLessThanOrEqualTo: yearEnd)
        .get();

    if (snapshot.docs.isEmpty) {
      return 0;
    }

    double daysTaken = 0;
    for (var doc in snapshot.docs) {
      final leave = LeaveRequest.fromFirestore(doc);
      if (leave.durationType == LeaveDurationType.fullDay) {
        daysTaken += leave.toDate.difference(leave.fromDate).inDays + 1;
      } else {
        daysTaken += 0.5;
      }
    }
    return daysTaken;
  }
}