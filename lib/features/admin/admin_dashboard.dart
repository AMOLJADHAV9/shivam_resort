import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_history_screen.dart';
import '../../screens/staff/staff_dashboard.dart';
import '../../main.dart';

class AdminMainWrapper extends StatefulWidget {
  const AdminMainWrapper({super.key});

  @override
  State<AdminMainWrapper> createState() => _AdminMainWrapperState();
}

class _AdminMainWrapperState extends State<AdminMainWrapper> {
  int _selectedIndex = 0;

  // List of pages for the Admin
  final List<Widget> _pages = [
    const AdminDashboardContent(), // Stats
    const StaffDashboard(isEmbedded: true), // Reception Features
    const BookingHistoryScreen(),  // History
    const StaffManagementPage(), // Staff
    const SettingsPage(), // Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          selectedItemColor: const Color(0xFF673AB7), // Brand Purple
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.room_service_rounded),
              label: 'Reception',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

/// The actual Dashboard UI with Stats
class AdminDashboardContent extends StatelessWidget {
  const AdminDashboardContent({super.key});

  static const Color brandPurple = Color(0xFF673AB7);
  static const Color brandPink = Color(0xFFE91E63);
  static const Color brandGreen = Color(0xFF4CAF50);

  Stream<QuerySnapshot> bookingStream(DateTime? fromDate) {
    if (fromDate == null) {
      return FirebaseFirestore.instance.collection('bookings').snapshots();
    }
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('createdAt', isGreaterThanOrEqualTo: fromDate)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quick Stats", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandPurple)),
            const SizedBox(height: 20),
            
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.2,
              children: [
                _buildStatTile("Today's Revenue", bookingStream(DateTime.now().subtract(const Duration(days: 1))), brandGreen, true),
                _buildStatTile("Today's Bookings", bookingStream(DateTime.now().subtract(const Duration(days: 1))), brandPink, false),
                _buildStatTile("Total Revenue", bookingStream(null), brandPurple, true),
                _buildStatTile("Total Bookings", bookingStream(null), Colors.orange, false),
              ],
            ),
            
            const SizedBox(height: 30),
            const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // A simple placeholder for a chart or recent list
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [brandPurple.withOpacity(0.8), brandPurple]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text("Revenue Chart Coming Soon", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String title, Stream<QuerySnapshot> stream, Color color, bool isRevenue) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = "...";
        if (snapshot.hasData) {
          if (isRevenue) {
            double total = snapshot.data!.docs
                .where((doc) => doc['status'] != 'cancelled')
                .fold(0.0, (prev, doc) {
                  if (doc['status'] == 'checked-out') {
                    return prev + (double.tryParse(doc['totalPayment']?.toString() ?? '0') ?? 0.0);
                  } else {
                    return prev + (double.tryParse(doc['advancePayment']?.toString() ?? '0') ?? 0.0);
                  }
                });
            value = "₹${total.toStringAsFixed(0)}";
          } else {
            value = snapshot.data!.docs.length.toString();
          }
        }
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 5),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        );
      },
    );
  }
}

/// Staff Management Page
class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  static const Color brandPurple = Color(0xFF673AB7);
  static const Color brandPink = Color(0xFFE91E63);
  static const Color brandGreen = Color(0xFF4CAF50);

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();
  final _passwordController = TextEditingController();

  List<Map<String, String>> staffList = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Staff Management", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Staff Form
            const Text(
              "Add New Staff",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPurple),
            ),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  // Name Field
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Staff Name",
                      prefixIcon: const Icon(Icons.person, color: brandPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brandPurple, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email, color: brandPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brandPurple, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Phone Field
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: const Icon(Icons.phone, color: brandPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brandPurple, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Role Field
                  TextField(
                    controller: _roleController,
                    decoration: InputDecoration(
                      labelText: "Role (e.g., Receptionist, Manager)",
                      prefixIcon: const Icon(Icons.work, color: brandPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brandPurple, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock, color: brandPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: brandPurple, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _addStaff,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Add Staff", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Staff List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Staff List",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPurple),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: brandGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${staffList.length} Staff",
                    style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            if (staffList.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    const Text("No staff added yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: staffList.length,
                itemBuilder: (context, index) {
                  var staff = staffList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: brandPurple.withOpacity(0.3),
                          width: 4,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: brandPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              staff['name']![0].toUpperCase(),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandPurple),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Staff Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff['name'] ?? "",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.email_outlined, size: 12, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(staff['email'] ?? "", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(staff['phone'] ?? "", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: brandPink.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  staff['role'] ?? "",
                                  style: TextStyle(fontSize: 11, color: brandPink, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteStaff(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _addStaff() {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _roleController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      staffList.add({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'role': _roleController.text,
      });
    });

    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _roleController.clear();
    _passwordController.clear();

    messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text("Staff added successfully!"), backgroundColor: brandGreen),
    );
  }

  void _deleteStaff(int index) {
    setState(() {
      staffList.removeAt(index);
    });
    messengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text("Staff deleted"), backgroundColor: Colors.orange),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

/// Settings Page
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color brandPurple = Color(0xFF673AB7);
  static const Color brandPink = Color(0xFFE91E63);
  static const Color brandGreen = Color(0xFF4CAF50);

  bool _notificationsEnabled = true;
  bool _emailAlerts = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Profile Section
            const Text(
              "Admin Profile",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPurple),
            ),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  // Profile Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [brandPurple, brandPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Center(
                      child: Text(
                        "AD",
                        style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Profile Info
                  const Text(
                    "Admin User",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "admin@shivanresorts.com",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: brandGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Administrator",
                      style: TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () {
                        _showEditProfileDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Edit Profile", style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Preferences Section
            const Text(
              "Preferences",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPurple),
            ),
            const SizedBox(height: 15),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  // Notifications Toggle
                  _buildSettingTile(
                    icon: Icons.notifications_active_rounded,
                    title: "Enable Notifications",
                    subtitle: "Get updates on bookings and events",
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                  const Divider(height: 1),

                  // Email Alerts Toggle
                  _buildSettingTile(
                    icon: Icons.mail_outline_rounded,
                    title: "Email Alerts",
                    subtitle: "Receive important updates via email",
                    value: _emailAlerts,
                    onChanged: (value) {
                      setState(() {
                        _emailAlerts = value;
                      });
                    },
                  ),
                  const Divider(height: 1),

                  // Dark Mode Toggle
                  _buildSettingTile(
                    icon: Icons.dark_mode_rounded,
                    title: "Dark Mode",
                    subtitle: "Switch to dark theme",
                    value: _darkMode,
                    onChanged: (value) {
                      setState(() {
                        _darkMode = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Account Section
            const Text(
              "Account",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPurple),
            ),
            const SizedBox(height: 15),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  // Change Password
                  _buildClickableTile(
                    icon: Icons.lock_outline_rounded,
                    title: "Change Password",
                    subtitle: "Update your password",
                    onTap: () {
                      _showChangePasswordDialog();
                    },
                  ),
                  const Divider(height: 1),

                  // Security Settings
                  _buildClickableTile(
                    icon: Icons.security_rounded,
                    title: "Security Settings",
                    subtitle: "Manage security preferences",
                    onTap: () {
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(content: Text("Security settings coming soon"), backgroundColor: Colors.blue),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // Backup & Data
                  _buildClickableTile(
                    icon: Icons.backup_rounded,
                    title: "Backup & Data",
                    subtitle: "Manage backups",
                    onTap: () {
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(content: Text("Backup features coming soon"), backgroundColor: Colors.blue),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Support Section
            const Text(
              "Support & Info",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPurple),
            ),
            const SizedBox(height: 15),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                children: [
                  // Help Center
                  _buildClickableTile(
                    icon: Icons.help_outline_rounded,
                    title: "Help Center",
                    subtitle: "Get help and support",
                    onTap: () {
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(content: Text("Help center opening..."), backgroundColor: Colors.blue),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // About
                  _buildClickableTile(
                    icon: Icons.info_outline_rounded,
                    title: "About Shivam Resorts",
                    subtitle: "App version 1.0.0",
                    onTap: () {
                      _showAboutDialog();
                    },
                  ),
                  const Divider(height: 1),

                  // Logout
                  _buildClickableTile(
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    subtitle: "Sign out from your account",
                    onTap: () {
                      _showLogoutDialog();
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Build Setting Tile with Toggle
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(icon, color: brandPurple, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: brandPurple,
          ),
        ],
      ),
    );
  }

  // Build Clickable Tile
  Widget _buildClickableTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : brandPurple),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDestructive ? Colors.red : Colors.black,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              decoration: InputDecoration(
                labelText: "Phone",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              messengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text("Profile updated successfully"), backgroundColor: brandGreen),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandPurple),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Current Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              messengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text("Password changed successfully"), backgroundColor: brandGreen),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandPurple),
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("About Shivam Resorts"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Staff Booking Management System", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("Version: 1.0.0"),
            SizedBox(height: 10),
            Text("© 2024 Shivam Resorts. All rights reserved."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              messengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text("Logged out successfully"), backgroundColor: Colors.orange),
              );
              // Add actual logout logic here (Firebase or your auth system)
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}