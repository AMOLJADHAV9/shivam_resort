import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../main.dart';
import 'booking_history_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_reports_page.dart';
import '../shared/booking_detail_dialog.dart';
import '../shared/help_support_screen.dart';
import '../shared/privacy_policy_screen.dart';
import '../../core/responsive_layout.dart';

class AdminMainWrapper extends ConsumerStatefulWidget {
  const AdminMainWrapper({super.key});

  @override
  ConsumerState<AdminMainWrapper> createState() => _AdminMainWrapperState();
}

class _AdminMainWrapperState extends ConsumerState<AdminMainWrapper> {
  int _selectedIndex = 0;

  // Modern UI Colors
  static const Color brandPurple = Color(0xFF673AB7);
  static const Color brandPink = Color(0xFFE91E63);

  final List<Widget> _pages = [
    const AdminDashboardContent(),
    BookingHistoryScreen(),
    const StaffManagementPage(),
    const AdminReportsPage(),  // NEW: Reports page
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobile: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        desktop: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: brandPurple),
              selectedLabelTextStyle: const TextStyle(color: brandPurple),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_customize), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.list_alt_rounded), label: Text('Bookings')),
                NavigationRailDestination(icon: Icon(Icons.people_alt_rounded), label: Text('Staff')),
                NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('Reports')),  // NEW: Reports page
                NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ResponsiveLayout.isDesktop(context)
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              selectedItemColor: brandPurple,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Bookings'),
                BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Staff'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),  // NEW: Reports page
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
    );
  }
}

// --- 2. DASHBOARD CONTENT (STATS & GREETING) ---
class AdminDashboardContent extends ConsumerWidget {
  const AdminDashboardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminProfile = ref.watch(adminProfileProvider);
    final allBookingsAsync = ref.watch(allBookingsProvider);
    final staffListAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Admin Overview", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ref.read(authRepositoryProvider).signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          )
        ],
      ),
      body: allBookingsAsync.when(
        data: (bookings) {
          final staffList = staffListAsync.value ?? [];
          
          // Calculations
          double totalRevenue = bookings
              .where((b) => b['status'] == 'checked-out')
              .fold(0.0, (sum, b) => sum + (double.tryParse(b['totalPayment']?.toString() ?? '0') ?? 0.0));
          
          int activeBookings = bookings.where((b) => b['status'] == 'occupied').length;
          int preBooked = bookings.where((b) => b['status'] == 'pre-booked').length;
          int checkedOut = bookings.where((b) => b['status'] == 'checked-out').length;
          
          // Total units in resort (as defined in inventory) is 44
          int totalUnits = 44;
          int availableRooms = totalUnits - activeBookings - preBooked;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting Section
                adminProfile.when(
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hello, ${data?['name'] ?? 'Admin'}",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF673AB7)),
                      ),
                      const Text("Welcome back to your management dashboard.", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 25),
                      
                      // Quick Reports Cards - Desktop only
                      if (ResponsiveLayout.isDesktop(context)) ...[
                        const Text("Quick Reports", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF673AB7))),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildMiniReportCard(context, "Pre-Bookings", "$preBooked", Colors.orange, Icons.calendar_today, 'pre-booked')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMiniReportCard(context, "Confirmed", "$activeBookings", Colors.green, Icons.check_circle, 'occupied')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMiniReportCard(context, "Checked-Out", "$checkedOut", Colors.purple, Icons.door_back_door, 'checked-out')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildMiniReportCard(context, "All Bookings", "${bookings.length}", Colors.blue, Icons.list_alt, 'all')),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                  loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Text("Error loading profile: $e"),
                ),

                if (!ResponsiveLayout.isDesktop(context))
                  const Text("Quick Stats", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (!ResponsiveLayout.isDesktop(context)) const SizedBox(height: 15),
                if (!ResponsiveLayout.isDesktop(context)) _buildRevenueCard(totalRevenue),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: ResponsiveLayout.isDesktop(context) ? 4 : (ResponsiveLayout.isTablet(context) ? 3 : 2), 
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.5,
                  children: [
                    _statTile("Occupied Units", "$activeBookings", Icons.book, Colors.blue),
                    _statTile("Total Staff", "${staffList.length}", Icons.people, Colors.green),
                    _statTile("Available Units", "$availableRooms", Icons.bed, Colors.orange),
                    _statTile("Pre-booked", "$preBooked", Icons.timer, Colors.red),
                  ],
                ),
                const SizedBox(height: 30),
                const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildActivityList(context, bookings),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error loading bookings: $e")),
      ),
    );
  }

  Widget _buildRevenueCard(double revenue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFFE91E63)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text("Total Realized Revenue", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 5),
          Text("₹ ${revenue.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statTile(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 5),
          Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActivityList(BuildContext context, List<Map<String, dynamic>> bookings) {
    final recentBookings = bookings.take(5).toList();
    if (recentBookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: const [
            Icon(Icons.history, color: Colors.grey, size: 40),
            SizedBox(height: 10),
            const Text("No recent activities to show.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: recentBookings.map((b) {
        final status = b['status'] ?? 'unknown';
        Color statusColor = Colors.grey;
        if (status == 'pre-booked') statusColor = Colors.yellow[700]!;
        if (status == 'occupied') statusColor = Colors.green;
        if (status == 'checked-out') statusColor = Colors.blue;
        if (status == 'cancelled') statusColor = Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () => BookingDetailDialog.show(context, b),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(Icons.person, color: statusColor, size: 20),
            ),
            title: Text(b['customerName'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Unit ${b['unitNumber']} • ${status.toUpperCase()}", style: const TextStyle(fontSize: 11)),
            trailing: Text("₹${b['advancePayment'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF673AB7))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniReportCard(BuildContext context, String title, String val, Color color, IconData icon, String status) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminReportsPage(initialStatus: status)),
        ),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 5),
              Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 3. STAFF MANAGEMENT ---
class StaffManagementPage extends ConsumerStatefulWidget {
  const StaffManagementPage({super.key});

  @override
  ConsumerState<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends ConsumerState<StaffManagementPage> {
  bool _isSaving = false;

  final List<String> _staffRoles = [
    'Staff',
    'Restaurant Manager',
    'Supervisor',
    'Receptionist',
    'Housekeeping',
    'Chef',
    'Waiter',
  ];

  static const Color brandPurple = Color(0xFF673AB7);
  static const Color brandPink = Color(0xFFE91E63);

  // Helper methods removed to be part of StaffFormModalContent

  void _showStaffModal({Map<String, dynamic>? staff}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StaffFormModalContent(staff: staff),
    );
  }

  Future<void> _deleteStaff(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Staff?"),
        content: const Text("This will remove the record from Firestore. The user may still have an active Auth account."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authRepositoryProvider).deleteStaff(uid);
        if (mounted) {
          messengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Staff deleted from records")));
        }
      } catch (e) {
        if (mounted) {
          messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Delete Failed: $e")));
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffListAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Staff Management"),
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
      ),
      body: staffListAsync.when(
        data: (staff) => staff.isEmpty
            ? const Center(
                child: Text("No staff members added yet.", style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: staff.length,
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE91E63),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(staff[i]['name'] ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${staff[i]['role']} • ${staff[i]['phone']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: brandPurple), onPressed: () => _showStaffModal(staff: staff[i])),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteStaff(staff[i]['uid'])),
                      ],
                    ),
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error loading staff: $e")),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: brandPink,
        onPressed: () => _showStaffModal(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// --- 4. SETTINGS PAGE ---
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSettingsTile(context, Icons.person, "Profile Settings", "Manage your personal info"),
          _buildSettingsTile(context, Icons.help_outline, "Help & Support", "FAQs and contact support"),
          _buildSettingsTile(context, Icons.privacy_tip_outlined, "Privacy Policy", "Data usage and user rights"),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              // Sign out logic could also go here
            },
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            label: const Text("App Version 1.0.0", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF673AB7)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (title == "Profile Settings") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfileScreen()));
          } else if (title == "Help & Support") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
          } else if (title == "Privacy Policy") {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
          }
        },
      ),
    );
  }
}

class StaffFormModalContent extends ConsumerStatefulWidget {
  final Map<String, dynamic>? staff;
  const StaffFormModalContent({super.key, this.staff});

  @override
  ConsumerState<StaffFormModalContent> createState() => _StaffFormModalContentState();
}

class _StaffFormModalContentState extends ConsumerState<StaffFormModalContent> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedRole;
  bool _isSaving = false;

  final List<String> _staffRoles = [
    'Staff',
    'Restaurant Manager',
    'Supervisor',
    'Receptionist',
    'Housekeeping',
    'Chef',
    'Waiter',
  ];

  static const Color brandPurple = Color(0xFF673AB7);
  static const Color brandPink = Color(0xFFE91E63);

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      _nameController.text = widget.staff!['name'] ?? '';
      _emailController.text = widget.staff!['email'] ?? '';
      _phoneController.text = widget.staff!['phone'] ?? '';
      _selectedRole = widget.staff!['role'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final isEdit = widget.staff != null;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || (isEdit ? false : email.isEmpty) || phone.isEmpty || _selectedRole == null || (isEdit ? false : password.isEmpty)) {
      messengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (isEdit) {
        await ref.read(authRepositoryProvider).updateStaffProfile(
              uid: widget.staff!['uid'],
              name: name,
              phone: phone,
              role: _selectedRole!,
            );
        if (mounted) {
          Navigator.pop(context);
          messengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Staff details updated!")));
        }
      } else {
        await ref.read(authRepositoryProvider).signUpStaff(
              email: email,
              password: password,
              name: name,
              phone: phone,
              role: _selectedRole ?? 'Staff',
            );
        if (mounted) {
          Navigator.pop(context);
          messengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Staff account created successfully!")));
        }
      }
    } catch (e) {
      if (mounted) {
        messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Operation Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.staff != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? "Update Staff" : "Create New Staff", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandPurple)),
            const Divider(color: brandPink),
            const SizedBox(height: 10),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person_outline))),
            TextField(controller: _emailController, enabled: !isEdit, decoration: const InputDecoration(labelText: "Email Address", prefixIcon: Icon(Icons.email_outlined))),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: "Select Role",
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: _staffRoles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(role),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedRole = value),
            ),
            TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: isEdit ? "New Password (Optional)" : "Initial Password", prefixIcon: const Icon(Icons.lock_outline))),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: brandPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEdit ? "UPDATE ACCOUNT" : "SAVE STAFF ACCOUNT", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
