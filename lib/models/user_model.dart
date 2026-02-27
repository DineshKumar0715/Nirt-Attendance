/// Defines the roles a user can have within the application.
enum UserRole {
  /// A regular employee.
  employee,
  /// A manager who can approve leaves and view team data.
  manager,
  /// A human resources staff member with administrative privileges.
  hr,
  /// A system administrator with full access.
  admin
}

/// Represents a user of the application.
///
/// This class holds all the profile information for a user, including their
/// role, status, and personal details.
class AppUser {
  /// The unique identifier for the user, typically from Firebase Auth.
  final String uid;
  /// The user's phone number.
  final String? phone;
  /// The role of the user within the application.
  final UserRole role;
  /// The full name of the user.
  final String? name;
  /// The current status of the user's account (e.g., "pending", "active").
  final String status;
  /// The unique identifier of the device associated with the user's account.
  final String? deviceId;
  /// The user's job title or designation.
  final String? designation;
  /// The department the user belongs to.
  final String? department;
  /// The user's primary work location.
  final String? workLocation;
  /// The UID of the user's reporting manager.
  final String? reportsTo;
  /// The URL of the user's profile picture.
  final String? profileImageUrl;

  /// Creates an [AppUser] instance.
  AppUser({
    required this.uid,
    this.phone,
    required this.role,
    this.name,
    this.status = 'pending',
    this.deviceId,
    this.designation,
    this.department,
    this.workLocation,
    this.reportsTo,
    this.profileImageUrl,
  });

  /// Creates an [AppUser] instance from a map of data, typically from Firestore.
  ///
  /// This factory constructor safely handles the conversion of data from a
  /// [Map<String, dynamic>] to an [AppUser] object, including parsing the user's role.
  ///
  /// - [data]: The map of user data.
  /// - [uid]: The user's unique identifier.
  /// - Returns a new [AppUser] object.
  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    UserRole determineRole(String? roleString) {
      switch (roleString) {
        case 'manager':
          return UserRole.manager;
        case 'hr':
          return UserRole.hr;
        case 'admin':
          return UserRole.admin;
        case 'employee':
        default:
          return UserRole.employee;
      }
    }

    return AppUser(
      uid: uid,
      phone: data['phone'],
      role: determineRole(data['role']),
      name: data['name'],
      status: data['status'] ?? 'pending',
      deviceId: data['deviceId'],
      designation: data['designation'],
      department: data['department'],
      workLocation: data['workLocation'],
      reportsTo: data['reportsTo'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  /// Converts the [AppUser] object to a map suitable for storing in Firestore.
  ///
  /// - Returns a [Map<String, dynamic>] representation of the user.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'role': role.toString().split('.').last,
      'name': name,
      'status': status,
      'deviceId': deviceId,
      'designation': designation,
      'department': department,
      'workLocation': workLocation,
      'reportsTo': reportsTo,
      'profileImageUrl': profileImageUrl,
    };
  }
}