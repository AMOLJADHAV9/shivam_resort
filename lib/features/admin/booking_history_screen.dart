import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/auth_provider.dart';
import '../shared/booking_detail_dialog.dart';

class BookingHistoryScreen extends ConsumerStatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  ConsumerState<BookingHistoryScreen> createState() =>
      _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedStatus = "All";

  // Brand colors matching Admin UI
  static const Color brandPurple = Color(0xFF673AB7);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allBookingsAsync = ref.watch(allBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          "Booking History",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search by guest name or phone...",
                    prefixIcon: const Icon(Icons.search, color: brandPurple),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          _buildFilterScroll(),

          Expanded(
            child: allBookingsAsync.when(
              data: (bookings) {
                final filtered = _applyFilters(bookings);
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildBookingCard(filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterScroll() {
    final statuses = [
      "All",
      "pre-booked",
      "occupied",
      "checked-out",
      "cancelled",
    ];
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = statuses[i];
          final isSelected = _selectedStatus == s;
          return ChoiceChip(
            label: Text(
              s == "All" ? "All Status" : s.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            selected: isSelected,
            selectedColor: brandPurple,
            onSelected: (val) => setState(() => _selectedStatus = s),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> bookings,
  ) {
    return bookings.where((b) {
      // 1. Status Filter
      bool statusMatch =
          _selectedStatus == "All" || (b['status'] ?? "") == _selectedStatus;

      // 3. Search Filter
      bool searchMatch = true;
      if (_searchQuery.isNotEmpty) {
        final name = (b['customerName'] ?? "").toString().toLowerCase();
        final phone = (b['phone'] ?? "").toString().toLowerCase();
        searchMatch =
            name.contains(_searchQuery) || phone.contains(_searchQuery);
      }

      return statusMatch && searchMatch;
    }).toList();
  }

  Widget _buildBookingCard(Map<String, dynamic> b) {
    final status = b['status'] ?? 'unknown';
    final date = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color statusColor = Colors.grey;
    if (status == 'pre-booked') statusColor = Colors.orange;
    if (status == 'occupied') statusColor = Colors.green;
    if (status == 'checked-out') statusColor = brandPurple;
    if (status == 'cancelled') statusColor = Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () => BookingDetailDialog.show(context, b),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['customerName'] ?? 'Guest',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${b['category']} - Unit ${b['unitNumber']}",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy, hh:mm a').format(date),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "₹${b['totalPayment'] ?? b['advancePayment'] ?? 0}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: brandPurple,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Delete Booking?"),
                      content: const Text(
                        "Are you sure you want to permanently delete this booking? This action cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await ref
                                  .read(bookingRepositoryProvider)
                                  .deleteBooking(b['id']);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Booking deleted successfully.",
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error deleting booking: $e"),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No bookings found for the selected filters.",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
