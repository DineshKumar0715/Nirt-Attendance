import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'leave_approval_screen.dart';
import 'team_members_screen.dart';
import '../employee/home_screen.dart';
import '../employee/leave_screen.dart';
import '../employee/attendance_screen.dart';
import '../employee/profile_screen.dart';
import '../common/notification_screen.dart'; // Import notification screen

/// The main dashboard screen for users with a manager role.
///
/// This screen acts as a central hub for managers, providing navigation to
/// various functionalities through a [BottomNavigationBar] and a [Drawer].
/// It combines both personal employee views (like `HomeScreen`) and manager-specific
/// tools (like `TeamMembersScreen` and `LeaveApprovalScreen`).
class ManagerDashboard extends StatefulWidget {
  /// Creates a [ManagerDashboard].
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

/// The state for the [ManagerDashboard].
///
/// Manages the navigation state, including the `PageController` and the
/// current index for the selected screen.
class _ManagerDashboardState extends State<ManagerDashboard> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// A list of the screens accessible from the manager dashboard.
  List<Widget> get _screens => [
    HomeScreen(
      pageController: _pageController,
      leaveScreenIndex: 3,
      attendanceScreenIndex: 4,
    ),
    const TeamMembersScreen(),
    const LeaveApprovalScreen(),
    const LeaveScreen(),
    const AttendanceScreen(),
  ];

  /// The titles corresponding to each screen in the `_screens` list.
  final List<String> _titles = [
    "My Dashboard",
    "My Team",
    "Leave Approvals",
    "Apply for Leave",
    "Attendance Log",
  ];

  /// Handles navigation when a bottom bar item or drawer item is tapped.
  ///
  /// - [index]: The index of the screen to navigate to.
  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      // MODIFIED: AppBar is now styled to match the other screens
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.indigo, // Set background color
        foregroundColor: Colors.white, // Set icon and title color
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                await authService.signOut();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user?.name ?? 'Profile'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                  ),
                ),
              ];
            },
            icon: const Icon(Icons.person_pin),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(user?.name ?? 'Manager Name'),
              accountEmail: Text(user?.designation ?? 'Manager'),
              currentAccountPicture: CircleAvatar(
                backgroundImage: _getProfileImage(user),
              ),
              decoration: const BoxDecoration(
                color: Colors.indigo,
              ),
            ),
            _buildDrawerItem(icon: Icons.home_work, title: 'My Dashboard', index: 0),
            _buildDrawerItem(icon: Icons.group, title: 'My Team', index: 1),
            _buildDrawerItem(icon: Icons.checklist, title: 'Leave Approvals', index: 2),
            const Divider(),
            _buildDrawerItem(icon: Icons.edit_calendar, title: 'Apply for Leave', index: 3),
            _buildDrawerItem(icon: Icons.history, title: 'Attendance Log', index: 4),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_work),
            label: 'Team',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.approval),
            label: 'Approvals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_calendar),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            label: 'Log',
          ),
        ],
      ),
    );
  }

  /// Builds a single item for the navigation drawer.
  ///
  /// - [icon]: The icon for the drawer item.
  /// - [title]: The title text for the drawer item.
  /// - [index]: The page index this item corresponds to.
  /// - Returns a configured [ListTile].
  Widget _buildDrawerItem({required IconData icon, required String title, required int index}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _currentIndex == index,
      selectedTileColor: Colors.indigo.withOpacity(0.1),
      onTap: () {
        _onItemTapped(index);
        Navigator.pop(context);
      },
    );
  }

  /// Retrieves the user's profile image for the drawer header.
  ///
  /// Returns a [NetworkImage] if a URL is available, otherwise returns null.
  ///
  /// - [user]: The current [AppUser].
  /// - Returns an [ImageProvider] or null.
  ImageProvider? _getProfileImage(AppUser? user) {
    if (user?.profileImageUrl != null && user!.profileImageUrl!.isNotEmpty) {
      return NetworkImage(user.profileImageUrl!);
    }
    return null;
  }
}