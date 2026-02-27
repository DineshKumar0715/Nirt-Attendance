import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/material.dart';

/// Provides authentication services using Firebase Authentication.
///
/// This class handles user authentication, including phone number verification,
/// sign-in, and sign-out. It also provides a stream of [AppUser] objects to
/// listen for authentication state changes.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates an [AppUser] object from a Firebase [User].
  ///
  /// Listens to the user's document in Firestore and returns a stream of
  /// [AppUser] objects. If the user is `null` or their document doesn't exist,
  /// it returns an appropriate stream.
  ///
  /// - [user]: The Firebase [User] object.
  /// - Returns a stream of [AppUser] objects or `null`.
  Stream<AppUser?> _userFromFirebase(User? user) {
    if (user == null) {
      return Stream.value(null);
    }
    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!, user.uid);
      }
      // Return a default/empty AppUser if Firestore doc doesn't exist yet
      // This might happen for a brief moment during the very first login
      return AppUser(
        uid: user.uid,
        phone: user.phoneNumber,
        role: UserRole.employee, // Default role
        name: user.displayName,
        status: 'pending',
      );
    });
  }

  /// A stream that notifies listeners about authentication state changes.
  ///
  /// Emits an [AppUser] object when a user signs in, and `null` when they
  /// sign out.
  Stream<AppUser?> get user {
    return _auth.authStateChanges().asyncExpand(_userFromFirebase);
  }

  /// Signs the current user out of the application.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- METHODS FOR PHONE AUTHENTICATION ---

  /// Triggers sending an OTP to the user's phone number.
  ///
  /// - [phoneNumber]: The user's phone number to verify.
  /// - [codeSent]: A callback function that is called when the OTP is sent.
  /// - [onVerificationFailed]: A callback for handling verification failures.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) codeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // This is for auto-retrieval on Android.
        // You might want to sign the user in directly here.
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onVerificationFailed,
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Called when auto-retrieval has timed out.
      },
    );
  }

  /// Signs the user in using the verification ID and the OTP they entered.
  ///
  /// - [verificationId]: The ID from the OTP sending process.
  /// - [smsCode]: The one-time password entered by the user.
  /// - Returns `true` if sign-in is successful, otherwise `false`.
  Future<bool> signInWithOtp(String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      return true; // Sign-in was successful
    } catch (e) {
      print("Error signing in with OTP: $e");
      return false; // Sign-in failed
    }
  }
}