import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

/// A screen that handles user authentication via phone number and OTP.
///
/// This screen allows users to enter their phone number, receive a one-time password (OTP),
/// and verify it to sign in. It interfaces with [AuthService] to handle the
/// Firebase phone authentication flow.
class LoginScreen extends StatefulWidget {
  /// Creates a [LoginScreen].
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// The state for the [LoginScreen].
///
/// Manages the state of the form, including the phone number, OTP,
/// verification ID, and loading status.
class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _isLoading = false;

  /// Verifies the entered phone number with Firebase Authentication.
  ///
  /// Before sending the OTP, it checks if the phone number is registered
  /// in the Firestore 'users' collection. If authorized, it triggers the
  /// OTP sending process.
  void _verifyPhoneNumber() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 10-digit phone number.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final fullPhoneNumber = "+91$phoneNumber";

    // --- NEW: Correctly query for the phone number ---
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: fullPhoneNumber)
          .limit(1) // We only need to know if at least one exists
          .get();

      if (querySnapshot.docs.isEmpty) {
        // If the query returns no documents, the user is not authorized.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This number is not authorized. Please contact your administrator."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return; // Stop the function here
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error checking authorization. Please try again.")),
      );
      setState(() => _isLoading = false);
      return;
    }
    // --- END OF NEW CHECK ---

    final authService = Provider.of<AuthService>(context, listen: false);
    
    await authService.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      codeSent: (verificationId) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
        }
      },
      onVerificationFailed: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? "Verification failed. Please try again.")),
          );
        }
      },
    );
  }

  /// Signs the user in using the received verification ID and the entered OTP.
  ///
  /// Shows a loading indicator during the process and displays a snackbar
  /// on failure.
  void _signInWithOtp() async {
    if (_verificationId == null || _otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 6-digit OTP.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    final success = await authService.signInWithOtp(
      _verificationId!,
      _otpController.text.trim(),
    );
    
    if (!success && mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid OTP. Please try again."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The build method and its helpers remain unchanged.
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 80,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 20),
                const Text(
                  'NIRT Renewable Energy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Text(
                  'Workforce Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _codeSent ? _buildOtpForm() : _buildPhoneForm(),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _codeSent ? _signInWithOtp : _verifyPhoneNumber,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _codeSent ? "Verify & Continue" : "Send OTP",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the form for entering the phone number.
  Widget _buildPhoneForm() {
    return Column(
      key: const ValueKey('phoneForm'),
      children: [
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: "10-Digit Mobile Number",
            prefixText: "+91 ",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  /// Builds the form for entering the OTP.
  ///
  /// This form also includes a button to go back and change the phone number.
  Widget _buildOtpForm() {
    return Column(
      key: const ValueKey('otpForm'),
      children: [
        TextFormField(
          controller: _otpController,
          decoration: InputDecoration(
            labelText: "6-Digit OTP",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        TextButton(
          onPressed: () => setState(() {
            _codeSent = false;
            _isLoading = false;
          }),
          child: const Text("Change Phone Number"),
        )
      ],
    );
  }
}