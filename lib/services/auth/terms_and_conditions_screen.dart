import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../models/user_model.dart';
import 'package:attendence_app/Screens/auth/login_screen.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  Future<void> _acceptTerms(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasAcceptedTerms', true);

    if (!context.mounted) return;

    // Check the user's login state BEFORE navigating
    final user = Provider.of<AppUser?>(context, listen: false);

    if (user != null) {
      // If a user is already logged in, go directly to the main app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RoleBasedWrapper()),
      );
    } else {
      // If no user is logged in, go to the login screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Terms and Conditions"),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _getTermsAndConditionsText(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _acceptTerms(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Agree and Continue"),
              ),
            ),
          ),
        ],
      ),
    );
  }
  String _getTermsAndConditionsText() {
    // Your full terms and conditions text
    return """
Nirt Renewable Energy Pvt Ltd AttendanceApp Effective Date: August 01, 2025 Document Version: 1.0

I. Acceptance of Terms By downloading, installing, registering for, or using AttendanceApp (the "Application"), you ("User," "you," or "your") confirm that you have read, understood, and agree to these Terms and Conditions and our Privacy Policy. If you do not agree, do not use the Application.

II. Definitions "Application" refers to AttendanceApp, including any updates or enhancements. "Biometric Data" means fingerprint scans and other biological identifiers processed by the Application. "Location Data" means GPS coordinates and related information captured during attendance marking. "Personal Data" means any information relating to an identified or identifiable individual. "Services" refers to all features provided through the Application. "SPDI" means Sensitive Personal Data or Information as defined under Indian law.

III. Eligibility and User Accounts A. Age and Capacity Users must be at least eighteen years old or have reached the age of majority in their jurisdiction. By using the Application, you warrant that you have the legal authority to enter this Agreement.

B. Account Registration

1. Registration requires verification via SMS-based One-Time Password (OTP) to your mobile number.


2. You are responsible for keeping your account credentials confidential.


3. You must provide and maintain accurate, current, and complete information.


4. You agree to update your account information promptly to preserve accuracy.



C. Account Security You are accountable for all activities under your account. You agree to:

Notify the Company immediately of unauthorized account use.

Use available strong authentication methods.

Secure your device with appropriate locks.


IV. Biometric and Location Data Processing A. Biometric Data

1. Fingerprint data is processed locally on your device for attendance verification.


2. Biometric data is classified as SPDI under the Information Technology Act, 2000.


3. Processing occurs only after you provide informed, unambiguous consent.



B. Location Data

1. GPS coordinates are captured only at check-in/check-out times.


2. Location tracking is not continuous.


3. Location data is used solely for attendance verification.



C. Consent and Withdrawal

1. Consent is obtained in compliance with the Digital Personal Data Protection Act, 2023.


2. You may withdraw consent at any time via Application settings.


3. Withdrawal may prevent attendance marking.



V. Data Storage and Security A. Cloud Storage

1. Data is stored in Google Firebase Cloud Firestore.


2. Google Firebase is a data processor; the Company is the data fiduciary.


3. Storage complies with applicable Indian data protection laws.



B. Security Measures

1. All data transmissions are encrypted using TLS.


2. Data at rest is encrypted per industry standards.


3. The Company follows reasonable security practices under Section 43A of the IT Act, 2000.


4. Access controls are enforced on a least-privilege basis.



C. Data Retention

1. Personal data is retained only as needed.


2. Retention periods comply with legal requirements and policies.


3. Upon account termination, data will be deleted per retention schedules.



VI. Permitted Uses and Restrictions A. Authorized Use The Application may be used only to:

Record personal attendance and leave requests.

Review attendance history and leave balances.

Submit and track leave applications.

Access attendance reports and notifications.


B. Prohibited Conduct You must not:

1. Reverse engineer or attempt to derive the Application's source code.


2. Circumvent or disable biometric authentication.


3. Manipulate or spoof location data.


4. Use the Application for unlawful purposes.


5. Send unauthorized commercial communications.


6. Violate any applicable laws or third-party rights.


7. Attempt unauthorized access to Company systems.



VII. Intellectual Property Rights A. Company Ownership All intellectual property in the Application, including code, designs, trademarks, and documentation, is owned exclusively by Nirt Renewable Energy Pvt Ltd.

B. Limited License Subject to your compliance, the Company grants you a limited, non-exclusive, non-transferable license to use the Application for its intended purposes.

VIII. Disclaimers A. As Is The Application and Services are provided "as is" and "as available," without warranties of any kind.

B. Disclaimer of Warranties The Company disclaims all warranties, including merchantability, fitness for a particular purpose, non-infringement, and uninterrupted operation.

IX. Limitation of Liability A. Liability Cap The Company's total liability is capped at the lesser of INR 10,000 or the fees you paid in the 12 months before a claim.

B. Exclusion of Damages The Company is not liable for indirect, incidental, special, consequential, or punitive damages, including loss of profits or data.

X. Indemnification You agree to indemnify the Company and its affiliates against any claims or losses arising from your use or misuse of the Application, violation of these Terms, or infringement of third-party rights.

XI. Termination A. By the Company Your access may be suspended or terminated for violations of these Terms, fraudulent behavior, security breaches, or prolonged inactivity.

B. Effect of Termination Upon termination, your rights to use the Application cease immediately, and the Company may delete your account and data.

XII. Privacy and Data Protection A. Privacy Policy Our Privacy Policy governs data collection, use, and disclosure and is incorporated herein by reference.

B. Compliance Data processing complies with the Digital Personal Data Protection Act, 2023, the Information Technology Act, 2000, and other applicable laws.

C. Data Subject Rights You have the right to access, correct, or request deletion of personal data, subject to legal retention requirements.

XIII. Governing Law and Dispute Resolution A. Governing Law These Terms are governed by the laws of India.

B. Dispute Resolution

1. Informal negotiations for 30 days.


2. Binding arbitration under the Arbitration and Conciliation Act, 1996, in Chennai, Tamil Nadu, in English, with a sole arbitrator.


3. The arbitrator's award is final.



C. Jurisdiction Courts in Chennai, Tamil Nadu, have exclusive jurisdiction for non-arbitrable matters.

XIV. Amendments and Modifications A. Right to Modify The Company may update these Terms to comply with laws, reflect feature changes, or address security needs.

B. Notice of Changes Material changes will be communicated via SMS, in-app notifications, or email at least seven days before they take effect.

C. Continued Use Continued use after changes constitutes acceptance of revised Terms.

XV. General Provisions A. Entire Agreement These Terms and the Privacy Policy constitute the complete agreement regarding the Application.

B. Severability If any provision is invalid, the remainder remains in effect.

C. Waiver No waiver is effective unless in writing and signed by the Company.

D. Assignment You may not assign these Terms; the Company may assign without restriction.

E. Force Majeure The Company is not liable for delays or failures caused by events beyond its control.

XVI. Contact Information For questions or concerns, contact our Data Protection Officer: Email: nirtinfo@gmail.com Phone: +91-9655646464 Address: 104/7, 3rd Floor, SPC Bhawan, Manivannan Road, Alagapuram, Salem, Tamil Nadu 636004 Business Hours: Monday to Friday, 9:00 AM to 6:00 PM IST

Acknowledgment By clicking "Accept," downloading, installing, or using the Application, you acknowledge that you have read, understood, and agree to be bound by these Terms.
    """;
  }
}
