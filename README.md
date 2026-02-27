# Workforce Management & Attendance App

This is a comprehensive Flutter-based mobile application designed for managing employee attendance, leave requests, and team oversight. It provides a robust, role-based system tailored for Employees, Managers, and HR personnel.

## Features

- **Role-Based Access Control**: Separate dashboards and functionalities for different user roles (Employee, Manager, HR).
- **Secure Authentication**: Users log in securely using their phone number and a one-time password (OTP).
- **Attendance Tracking**:
  - Employees can check in and check out for the day.
  - Check-ins are verified with biometric authentication (fingerprint/face ID).
  - Geolocation is captured and stored with each attendance event.
  - The system automatically flags late check-ins and early check-outs.
- **Leave Management System**:
  - Employees can apply for various types of leave (full-day, half-day, timed).
  - Managers can view and approve/reject leave requests from their direct reports.
  - HR has an overview of all leave requests, including escalated ones.
- **Manager Dashboard**:
  - View a list of direct reports and their real-time attendance status.
  - Access a dedicated screen to approve pending leave requests.
- **HR Dashboard**:
  - View all teams and drill down into specific manager's reports.
  - Manage leave requests from managers and those that have been escalated.
- **Notifications**:
  - Push notifications for important events (e.g., leave approvals).
  - Daily reminders for employees to check in.

## Project Structure

The project is organized into the following main directories:

- `lib/`
  - `main.dart`: The entry point of the application, handles initialization and routing.
  - `models/`: Contains the data models for the app, such as `AppUser` and `LeaveRequest`.
  - `services/`: Houses the business logic and communication with external services like Firebase, location, and biometrics.
  - `screens/`: Contains all the UI widgets, organized into subdirectories based on user roles (`employee/`, `manager/`, `hr/`) and common features (`auth/`, `common/`).

## Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version >=3.0.0)
- A code editor like [VS Code](https://code.visualstudio.com/) or [Android Studio](https://developer.android.com/studio).
- A Firebase project.

### Setup

1.  **Clone the repository:**
    ```sh
    git clone <repository-url>
    cd attendence_app
    ```

2.  **Set up Firebase:**
    - Create a new project on the [Firebase Console](https://console.firebase.google.com/).
    - Add an Android and/or iOS app to your Firebase project.
    - Follow the instructions to download the `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS) files and place them in the correct directories.
    - In your Firebase project, enable the following services:
      - **Authentication**: Enable the "Phone Number" sign-in provider.
      - **Firestore**: Create a Firestore database. You will need to manually create the `users` collection and add documents for authorized users. A user document should have at least a `phone` field (e.g., `+911234567890`) and a `role` field (e.g., `employee`).
    - Use the FlutterFire CLI to generate the `lib/firebase_options.dart` file for your project:
      ```sh
      flutterfire configure
      ```

3.  **Add Google Maps API Key:**
    - In the [Google Cloud Console](https://console.cloud.google.com/), enable the **Geocoding API**.
    - Generate an API key.
    - Open the file `lib/services/location_service.dart` and paste your API key into the `_apiKey` variable.
      ```dart
      class LocationService {
        // --- PASTE YOUR GOOGLE MAPS API KEY HERE ---
        final String _apiKey = "YOUR_API_KEY_HERE";
        // ...
      }
      ```
    **Note:** For production apps, it is critical to secure this API key properly (e.g., using environment variables or a secret management service).

4.  **Install dependencies:**
    ```sh
    flutter pub get
    ```

### Usage

Run the application on a connected device or emulator:

```sh
flutter run
```

The app requires a physical device to test features that rely on hardware, such as biometric authentication and cellular services for receiving OTPs.