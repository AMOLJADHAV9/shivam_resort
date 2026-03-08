import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_provider.dart';
import '../../core/report_service.dart';
import '../../core/responsive_layout.dart';

class AdminReportsPage extends ConsumerStatefulWidget {
  final String? initialStatus;
  
  const AdminReportsPage({super.key, this.initialStatus});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  @override
  void initState() {
    super.initState();
    // Auto-open filter dialog if initial status is provided
    // But only after data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialStatus != null && mounted) {
        final allBookingsAsync = ref.read(allBookingsProvider);
        // Only open dialog if data is available
        if (allBookingsAsync.hasValue && allBookingsAsync.value != null) {
          _showCategoryFilterDialog(context, widget.initialStatus!, allBookingsAsync.value!);
        } else if (!allBookingsAsync.isLoading) {
          // Data not loaded yet, wait and try again
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              final bookings = ref.read(allBookingsProvider).value ?? [];
              if (bookings.isNotEmpty || widget.initialStatus != null) {
                _showCategoryFilterDialog(context, widget.initialStatus!, bookings);
              }
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allBookingsAsync = ref.watch(allBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Generate Reports", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF673AB7),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: allBookingsAsync.when(
        data: (bookings) {
          int prebooked = 0;
          int occupied = 0;
          int cancelled = 0;
          int checkedOut = 0;
          for (var b in bookings) {
            final status = b['status'];
            if (status == 'pre-booked') prebooked++;
            if (status == 'occupied') occupied++;
            if (status == 'cancelled') cancelled++;
            if (status == 'checked-out') checkedOut++;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Report Categories",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF673AB7),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Select a category to generate and customize your report",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                
                // Report Category Cards
                _categoryReportCard(
                  title: "Pre-Bookings Report",
                  subtitle: "Generate report for pre-booked customers",
                  icon: Icons.calendar_today,
                  color: Colors.orange,
                  count: prebooked,
                  onTap: () => _showCategoryFilterDialog(context, 'pre-booked', bookings),
                ),
                const SizedBox(height: 12),
                _categoryReportCard(
                  title: "Confirmed Bookings Report",
                  subtitle: "Generate report for confirmed/occupied bookings",
                  icon: Icons.check_circle,
                  color: Colors.green,
                  count: occupied,
                  onTap: () => _showCategoryFilterDialog(context, 'occupied', bookings),
                ),
                const SizedBox(height: 12),
                _categoryReportCard(
                  title: "Checked-Out Report",
                  subtitle: "Generate report for checked-out customers",
                  icon: Icons.door_back_door,
                  color: Colors.purple,
                  count: checkedOut,
                  onTap: () => _showCategoryFilterDialog(context, 'checked-out', bookings),
                ),
                const SizedBox(height: 12),
                _categoryReportCard(
                  title: "Cancelled Bookings Report",
                  subtitle: "Generate report for cancelled bookings",
                  icon: Icons.cancel,
                  color: Colors.red,
                  count: cancelled,
                  onTap: () => _showCategoryFilterDialog(context, 'cancelled', bookings),
                ),
                const SizedBox(height: 12),
                _categoryReportCard(
                  title: "All Bookings Report",
                  subtitle: "Generate comprehensive report for all bookings",
                  icon: Icons.list_alt,
                  color: Colors.blue,
                  count: bookings.length,
                  onTap: () => _showCategoryFilterDialog(context, 'all', bookings),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error loading bookings: $e")),
      ),
    );
  }

  Widget _categoryReportCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryFilterDialog(BuildContext context, String category, List<Map<String, dynamic>> allBookings) {
    String? selectedCategory;
    Set<String> selectedCapacities = {};
    
    // Extract unique categories and capacities from bookings
    final categories = allBookings.map((b) => b['category'] as String).whereType<String>().toSet().toList();
    categories.sort();
    
    final capacities = allBookings.map((b) => b['capacity'] as String).whereType<String>().toSet().toList();
    capacities.sort();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.filter_list, 
                color: category == 'pre-booked' ? Colors.orange : 
                       category == 'occupied' ? Colors.green : 
                       category == 'checked-out' ? Colors.purple : 
                       category == 'cancelled' ? Colors.red : Colors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${category == 'all' ? 'All' : category.split('-').map((s) => s[0].toUpperCase() + s.substring(1)).join(' ')} Bookings Report',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Filter by Accommodation Type:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text("All Types"),
                      selected: selectedCategory == null,
                      onSelected: (val) => setDialogState(() => selectedCategory = null),
                    ),
                    ...categories.map((cat) => FilterChip(
                      label: Text(cat),
                      selected: selectedCategory == cat,
                      onSelected: (val) => setDialogState(() => selectedCategory = val ? cat : null),
                    )).toList(),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Filter by Capacity:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text("All Capacities"),
                      selected: selectedCapacities.isEmpty,
                      onSelected: (val) => setDialogState(() => selectedCapacities.clear()),
                    ),
                    ...capacities.map((cap) => FilterChip(
                      label: Text(cap),
                      selected: selectedCapacities.contains(cap),
                      onSelected: (val) => setDialogState(() {
                        if (val) {
                          selectedCapacities.add(cap);
                        } else {
                          selectedCapacities.remove(cap);
                        }
                      }),
                    )).toList(),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _generateFilteredReport(category, selectedCategory, selectedCapacities, allBookings);
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("GENERATE REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateFilteredReport(
    String statusCategory,
    String? filterCategory,
    Set<String> filterCapacities,
    List<Map<String, dynamic>> allBookings,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Filter bookings based on status
      List<Map<String, dynamic>> filteredBookings;
      
      if (statusCategory == 'all') {
        filteredBookings = allBookings.where((b) => b['status'] != 'cancelled').toList();
      } else {
        filteredBookings = allBookings.where((b) => b['status'] == statusCategory).toList();
      }

      // Apply category filter
      if (filterCategory != null) {
        filteredBookings = filteredBookings.where((b) => b['category'] == filterCategory).toList();
      }

      // Apply capacity filter
      if (filterCapacities.isNotEmpty) {
        filteredBookings = filteredBookings.where((b) => filterCapacities.contains(b['capacity'])).toList();
      }

      if (context.mounted) Navigator.pop(context); // Close loading

      if (filteredBookings.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No bookings found with selected filters'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Generate the customer report with filtered data
      await ReportService.generateCustomerReport(filteredBookings);
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
