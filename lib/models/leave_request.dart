import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// Defines the different types of leave durations.
enum LeaveDurationType {
  /// A full day of leave.
  fullDay,
  /// A half day of leave.
  halfDay,
  /// Leave for a specific time interval.
  timed
}

/// Defines the period for a half-day leave.
enum HalfDayPeriod {
  /// The morning session.
  forenoon,
  /// The afternoon session.
  afternoon
}

/// Represents a leave request made by a user.
///
/// This class holds all the information related to a leave application,
/// including the user who requested it, the type and duration of leave,
/// its status, and relevant timestamps.
class LeaveRequest {
  /// The unique identifier of the leave request document in Firestore.
  final String id;
  /// The unique ID of the user who made the request.
  final String uid;
  /// The name of the user.
  final String name;
  /// The type of leave (e.g., "Sick Leave", "Vacation").
  final String type;
  /// The reason provided for the leave.
  final String reason;
  /// The current status of the leave request (e.g., "pending", "approved").
  String status;
  /// The start date of the leave period.
  final DateTime fromDate;
  /// The end date of the leave period.
  final DateTime toDate;
  /// The timestamp when the leave request was submitted.
  final Timestamp timestamp;
  /// The role of the user who made the request.
  final UserRole userRole;

  /// The duration type of the leave (e.g., full day, half day).
  final LeaveDurationType durationType;
  /// The start time for a timed leave.
  final String? fromTime;
  /// The end time for a timed leave.
  final String? toTime;
  
  /// The specific period for a half-day leave (forenoon or afternoon).
  final HalfDayPeriod? halfDayPeriod;

  /// Creates a new [LeaveRequest] instance.
  LeaveRequest({
    required this.id,
    required this.uid,
    required this.name,
    required this.type,
    required this.reason,
    required this.status,
    required this.fromDate,
    required this.toDate,
    required this.timestamp,
    required this.userRole,
    required this.durationType,
    this.fromTime,
    this.toTime,
    this.halfDayPeriod,
  });

  /// Creates a [LeaveRequest] instance from a Firestore document snapshot.
  ///
  /// This factory constructor handles the parsing of data from Firestore,
  /// including safe parsing of enums and providing default values for missing fields.
  ///
  /// - [doc]: The [DocumentSnapshot] from Firestore.
  /// - Returns a new [LeaveRequest] object.
  factory LeaveRequest.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return LeaveRequest(
      id: doc.id,
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? 'Unknown',
      reason: data['reason'] ?? '-',
      status: data['status'] ?? 'pending',
      fromDate: (data['fromDate'] as Timestamp).toDate(),
      toDate: (data['toDate'] as Timestamp).toDate(),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      userRole: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['userRole']}',
        orElse: () => UserRole.employee,
      ),
      durationType: LeaveDurationType.values.firstWhere(
        (e) => e.toString() == 'LeaveDurationType.${data['durationType']}',
        orElse: () => LeaveDurationType.fullDay,
      ),
      fromTime: data['fromTime'],
      toTime: data['toTime'],
      // Safely parse the new halfDayPeriod from a string
      halfDayPeriod: data['halfDayPeriod'] == null
          ? null
          : HalfDayPeriod.values.firstWhere(
              (e) => e.toString() == 'HalfDayPeriod.${data['halfDayPeriod']}',
              orElse: () => HalfDayPeriod.forenoon,
            ),
    );
  }
}