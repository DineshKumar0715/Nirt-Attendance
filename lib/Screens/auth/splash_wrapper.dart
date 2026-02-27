import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../main.dart'; 
import 'login_screen.dart';
import 'package:attendence_app/services/auth/terms_and_conditions_screen.dart';

/// A wrapper widget that serves as the initial entry point of the app.
///
/// This widget handles the initial routing logic by checking two main conditions
/// in sequence:
/// 1. Whether the user has accepted the Terms and Conditions.
/// 2. The user's current authentication state.
///
/// It displays a loading indicator while checks are in progress and navigates
/// the user to the appropriate screen ([TermsAndConditionsScreen], [LoginScreen],
/// or [RoleBasedWrapper]) based on the results.
class SplashWrapper extends StatelessWidget {
  /// Creates a [SplashWrapper].
  const SplashWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return StreamBuilder<AppUser?>(
      stream: authService.user,
      builder: (context, authSnapshot) {
        // While checking for a logged-in user, show a loading screen.
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // After the auth check, check for the Terms and Conditions.
        // We use a FutureBuilder for the one-time check of SharedPreferences.
        return FutureBuilder<bool>(
          future: _hasAcceptedTerms(),
          builder: (context, termsSnapshot) {
            // While checking SharedPreferences, show a loading screen.
            if (termsSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final hasAccepted = termsSnapshot.data ?? false;

            if (!hasAccepted) {
              // If terms are not accepted, this is the highest priority. Show the T&C screen.
              return const TermsAndConditionsScreen();
            }

            // If terms ARE accepted, proceed with the original login check.
            if (authSnapshot.hasData && authSnapshot.data != null) {
              // User is logged in.
              return const RoleBasedWrapper();
            } else {
              // User is logged out.
              return const LoginScreen();
            }
          },
        );
      },
    );
  }

  /// Checks [SharedPreferences] to see if the user has accepted the terms and conditions.
  ///
  /// - Returns a [Future<bool>] that completes with `true` if the terms have
  ///   been accepted, and `false` otherwise.
  Future<bool> _hasAcceptedTerms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasAcceptedTerms') ?? false;
  }
}