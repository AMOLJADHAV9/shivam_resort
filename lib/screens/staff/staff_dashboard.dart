import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/format_utils.dart';
import '../../core/auth_provider.dart';
import '../../core/receipt_service.dart';
import '../../core/cloudinary_service.dart';
import '../../main.dart';
import '../../core/report_service.dart';
import '../../features/shared/booking_detail_dialog.dart';
import '../../features/shared/unit_calendar_sheet.dart';
import '../../features/auth/login_screen.dart';
import '../../features/staff/staff_profile_screen.dart';
import '../../features/shared/help_support_screen.dart';
import '../../features/shared/privacy_policy_screen.dart';
import '../../main.dart';

class StaffDashboard extends ConsumerStatefulWidget {
  const StaffDashboard({super.key});

  @override
  ConsumerState<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends ConsumerState<StaffDashboard> {
  // Brand Colors
  static const Color brandPink = Color(0xFFE91E63);   
  static const Color brandPurple = Color(0xFF673AB7); 
  static const Color brandGreen = Color(0xFF4CAF50);  
  static const Color lightBg = Color(0xFFF4F7F9);

  int _currentIndex = 0; 

  // Form State
  String? selectedCategory;
  String? selectedCapacity;
  dynamic selectedUnit;
  String bookingType = "Prebook";
  DateTime? selectedDate;
  DateTime? expectedCheckOutDate;
  String chargingMode = "24h"; // 24h or flexible

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final paymentController = TextEditingController();
  final idProofController = TextEditingController();
  final totalPeopleController = TextEditingController(text: "1");

  // History State
  final searchController = TextEditingController();
  String searchQuery = "";
  String filterStatus = "All";
  String filterCategory = "All";
  int _arrivalsInitialTab = 0; // 0 = Today, 1 = Tomorrow

  bool _isSaving = false;
  File? _idImage;

  final Map<String, dynamic> inventory = {
    "Cottages": {
      "Magic – 2 Bed Cottage": [501, 502, 503, 504, 512, 511, 509, 510],
      "Magic – 3 Bed Cottage": [505, 506, 507, 508],
    },
    "Lodging Deluxe": {
      "Vishva Residency – 2 Bed Room": ["003", "004", "103", "104"],
      "Vishva Residency – 3 Bed Room": ["001", "002", "005", "006", "007", "008", "101", "102", "105", "106", "107", "108", "111"],
    },
    "Dormitory": {
      "Vishva Residency – 6 Bed Hall": ["009", "010", "109", "110"],
      "Party Hub – 11 Bed Hall": 1,
      "Magic Guest House – 20 Bed Hall": 1,
    },
    "Banquet Hall (AC)": {
      "Central Vistara – 300–400 Capacity": 1,
      "Green Orchid – 100–200 Capacity": 2,
    },
    "Lawn": {
      "Vanila Lawn – 50 People": 1,
      "Bombaya Lawn – 250–300 People": 1,
      "Shivamji Lawn – 2000–2500 People": 1,
    },
    "Function Hall": {
      "Shivam Function – 800–1200 Capacity": 1,
      "Royal Rituals – 300–400 Capacity": 1,
    },
    "Meeting Hall": {
      "Royal Dine – 20 Persons": 1,
    },
    "Saptapadi Hall": {
      "Mango Farm –150–200 Persons": 1,
    },
  };

  void _logout() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) {
      // main.dart's AuthWrapper handles the navigation
    }
  }

  /// ================= CUSTOMER FORM (MODAL) =================
  void openCustomerForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("New Booking", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandPurple)),
                const Divider(color: brandPink),
                
                // 1. Booking Type Selection
                Row(
                  children: [
                    Radio(
                      value: "Prebook",
                      groupValue: bookingType,
                      activeColor: brandPink,
                      onChanged: (val) => setModalState(() => bookingType = val!),
                    ),
                    const Text("Pre-Booking"),
                    Radio(
                      value: "Confirmed",
                      groupValue: bookingType,
                      activeColor: brandPink,
                      onChanged: (val) => setModalState(() => bookingType = val!),
                    ),
                    const Text("Confirmed"),
                  ],
                ),

                // 2. Input Fields
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Customer Name", prefixIcon: Icon(Icons.person))),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone))),
                TextField(controller: idProofController, decoration: const InputDecoration(labelText: "Aadhar / ID Proof", prefixIcon: Icon(Icons.badge))),
                TextField(controller: totalPeopleController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Total People", prefixIcon: Icon(Icons.groups))),
                
                const SizedBox(height: 10),
                
                // Image Picker Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await showDialog<XFile?>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Select ID Proof Source"),
                              actions: [
                                TextButton.icon(
                                  onPressed: () async {
                                    final img = await picker.pickImage(source: ImageSource.camera);
                                    if (context.mounted) Navigator.pop(context, img);
                                  }, 
                                  icon: const Icon(Icons.camera_alt), label: const Text("Camera")
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final img = await picker.pickImage(source: ImageSource.gallery);
                                    if (context.mounted) Navigator.pop(context, img);
                                  }, 
                                  icon: const Icon(Icons.photo_library), label: const Text("Gallery")
                                ),
                              ],
                            ),
                          );
                          
                          if (image != null) {
                            setModalState(() => _idImage = File(image.path));
                          }
                        },
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text("Capture ID Proof"),
                        style: OutlinedButton.styleFrom(foregroundColor: brandPink),
                      ),
                    ),
                    if (_idImage != null) ...[
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Builder(
                          builder: (context) {
                            final imageFile = _idImage;
                            if (imageFile == null) return const SizedBox.shrink();
                            return Image.file(imageFile, width: 50, height: 50, fit: BoxFit.cover);
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () => setModalState(() => _idImage = null),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                      )
                    ]
                  ],
                ),
                
                const SizedBox(height: 15),

                OutlinedButton.icon(
                  onPressed: () async {
                    DateTime? date = await showDatePicker(
                      context: context, 
                      initialDate: DateTime.now(), 
                      firstDate: DateTime.now(), 
                      lastDate: DateTime(2030)
                    );
                    if (date != null) {
                      TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setModalState(() => selectedDate = DateTime(
                          date.year, date.month, date.day, time.hour, time.minute
                        ));
                      }
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(selectedDate == null 
                    ? "Select Reporting Date & Time" 
                    : "Reporting: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year} ${selectedDate!.hour}:${selectedDate!.minute.toString().padLeft(2, '0')}"),
                  style: OutlinedButton.styleFrom(foregroundColor: brandPurple),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () async {
                    DateTime? date = await showDatePicker(
                      context: context, 
                      initialDate: selectedDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1)), 
                      firstDate: selectedDate ?? DateTime.now(), 
                      lastDate: DateTime(2030)
                    );
                    if (date != null) {
                      TimeOfDay? time = await showTimePicker(
                        context: context, 
                        initialTime: const TimeOfDay(hour: 11, minute: 0)
                      );
                      setModalState(() {
                        if (time != null) {
                          expectedCheckOutDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        } else {
                          expectedCheckOutDate = DateTime(date.year, date.month, date.day, 11, 0); // Default to 11 AM if time picker cancelled
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(expectedCheckOutDate == null 
                    ? "Expected Check-Out Date & Time" 
                    : "Check-Out: ${DateFormat('dd MMM yyyy, hh:mm a').format(expectedCheckOutDate!)}"),
                  style: OutlinedButton.styleFrom(foregroundColor: brandPurple),
                ),

                const SizedBox(height: 15),
                const Text("Charging Cycle", style: TextStyle(fontWeight: FontWeight.bold, color: brandPurple)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text("22-Hr Strict", style: TextStyle(fontSize: 12)),
                        value: "24h",
                        groupValue: chargingMode,
                        activeColor: brandPink,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setModalState(() => chargingMode = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text("Flexible Day", style: TextStyle(fontSize: 12)),
                        value: "flexible",
                        groupValue: chargingMode,
                        activeColor: brandPink,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setModalState(() => chargingMode = val!),
                      ),
                    ),
                  ],
                ),

                TextField(
                  controller: paymentController, 
                  keyboardType: TextInputType.number, 
                  decoration: InputDecoration(
                    labelText: bookingType == "Prebook" ? "Advance Payment (₹)" : "Full Payment (₹)", 
                    prefixIcon: const Icon(Icons.currency_rupee)
                  )
                ),

                const SizedBox(height: 25),

                // 4. Save Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPurple, 
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _isSaving ? null : () async {
                    if (selectedDate == null || expectedCheckOutDate == null) {
                      if (context.mounted) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(content: Text("Please select both Reporting and Check-Out dates")),
                        );
                      }
                      return;
                    }
                    
                    setState(() => _isSaving = true);
                    try {
                      String? idImageUrl;
                      if (_idImage != null) {
                        idImageUrl = await CloudinaryService.uploadIdProof(_idImage!);
                        if (idImageUrl == null && mounted) {
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(content: Text("Failed to upload ID image. Continuing with database only.")),
                          );
                        }
                      }

                      await ref.read(bookingRepositoryProvider).saveBooking(
                        customerName: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        idProof: idProofController.text.trim(),
                        category: selectedCategory!,
                        capacity: selectedCapacity!,
                        unitNumber: selectedUnit!,
                        reportingDate: selectedDate!,
                        checkOutDate: expectedCheckOutDate!,
                        advancePayment: double.tryParse(paymentController.text.trim()) ?? 0.0,
                        status: bookingType == "Prebook" ? "pre-booked" : "occupied",
                        chargingMode: chargingMode,
                        totalPeople: int.tryParse(totalPeopleController.text) ?? 1,
                        idImageUrl: idImageUrl,
                      );
                      
                      if (mounted) {
                        Navigator.pop(context);
                        
                        final isConfirmed = (bookingType != "Prebook");
                        
                        if (isConfirmed) {
                           final bookingCheckIn = selectedDate;
                           final bookingCheckOut = expectedCheckOutDate;
                           showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Booking Confirmed"),
                              content: const Text("Would you like to generate a receipt for this customer?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO")),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    
                                    if (bookingCheckIn == null || bookingCheckOut == null) return;

                                    final bookingData = {
                                      'customerName': nameController.text.trim(),
                                      'phone': phoneController.text.trim(),
                                      'idProof': idProofController.text.trim(),
                                      'category': selectedCategory!,
                                      'capacity': selectedCapacity!,
                                      'unitNumber': selectedUnit!,
                                      'reportingDate': Timestamp.fromDate(bookingCheckIn),
                                      'checkOutDate': Timestamp.fromDate(bookingCheckOut),
                                      'checkInAt': Timestamp.fromDate(bookingCheckIn),
                                      'advancePayment': double.tryParse(paymentController.text.trim()) ?? 0.0,
                                      'status': 'occupied',
                                      'chargingMode': chargingMode,
                                      'totalPeople': int.tryParse(totalPeopleController.text) ?? 1,
                                      'idImageUrl': idImageUrl,
                                    };
                                    ReceiptService.showPrintOptions(context, bookingData);
                                  },
                                  child: const Text("GENERATE RECEIPT"),
                                ),
                              ],
                            ),
                          );
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: brandGreen, content: Text("Booking Saved for ${FormatUtils.formatUnit(selectedCategory, selectedUnit)}!")),
                          );
                        }
                        // Clear fields
                        nameController.clear();
                        phoneController.clear();
                        paymentController.clear();
                        idProofController.clear();
                        totalPeopleController.text = "1";
                        setState(() {
                          selectedUnit = null;
                          selectedDate = null;
                          expectedCheckOutDate = null;
                          _idImage = null; // Clear image state
                        });
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e")),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isSaving = false);
                    }
                  },
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE BOOKING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ================= PAGE WIDGETS =================
  
  Widget homePage() {
    final staffProfile = ref.watch(staffProfileProvider);
    final activeBookingsRef = ref.watch(activeBookingsProvider);
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return activeBookingsRef.when(
      data: (bookings) {
        final todayArrivals = bookings.where((b) {
          if (b['status'] != 'pre-booked') return false;
          final date = (b['reportingDate'] as Timestamp?)?.toDate();
          if (date == null) return false;
          return date.day == now.day && date.month == now.month && date.year == now.year;
        }).length;

        final tomorrowArrivals = bookings.where((b) {
          if (b['status'] != 'pre-booked') return false;
          final date = (b['reportingDate'] as Timestamp?)?.toDate();
          if (date == null) return false;
          return date.day == tomorrow.day && date.month == tomorrow.month && date.year == tomorrow.year;
        }).length;

        final todayCheckOuts = bookings.where((b) {
          if (b['status'] != 'occupied') return false;
          final cTs = b['checkOutDate'] as Timestamp?;
          if (cTs == null) return false;
          final date = cTs.toDate();
          return date.day == now.day && date.month == now.month && date.year == now.year;
        }).length;

        final activeCheckIns = bookings.where((b) => b['status'] == 'occupied').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome back,", style: TextStyle(fontSize: 16, color: Colors.black54)),
              staffProfile.when(
                data: (data) => Text(
                  data?['name'] ?? "Shivam Resort Staff",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: brandPurple),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => const Text("Shivam Resort Staff"),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                children: [
                  _homeActionCard("New Booking", Icons.add_business, brandPink, () => setState(() => _currentIndex = 1)),
                  _homeActionCard("Today Arrivals", Icons.today, brandGreen, () => setState(() { _currentIndex = 4; _arrivalsInitialTab = 0; }), count: todayArrivals),
                  _homeActionCard("Tomorrow Arrivals", Icons.event_note, Colors.teal, () => setState(() { _currentIndex = 4; _arrivalsInitialTab = 1; }), count: tomorrowArrivals),
                  _homeActionCard("Active Check-ins", Icons.hotel, brandGreen, () => setState(() => _currentIndex = 7), count: activeCheckIns),
                  _homeActionCard("Booking History", Icons.history, const Color(0xFF2196F3), () => setState(() => _currentIndex = 2)),
                  _homeActionCard("Check-Outs", Icons.exit_to_app, Colors.orange, () => setState(() => _currentIndex = 5), count: todayCheckOuts),
                  _homeActionCard("Reports", Icons.assessment, Colors.indigo, () => setState(() => _currentIndex = 6)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) {
        debugPrint("Active Bookings Error: $e");
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text("Connection Error", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red)),
                const SizedBox(height: 8),
                Text("$e", textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(activeBookingsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry Connection"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget bookingsPage() {
    final activeBookings = ref.watch(activeBookingsProvider);
    Map<String, dynamic> currentCapacities = selectedCategory != null ? inventory[selectedCategory] : {};
    final capacityValue = (selectedCategory != null && selectedCapacity != null) ? currentCapacities[selectedCapacity] : 0;
    int totalUnits = capacityValue is List ? (capacityValue as List).length : (capacityValue as int);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("Category", Icons.category),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: inventory.keys.map((c) => ChoiceChip(
            label: Text(c), selected: selectedCategory == c, selectedColor: brandPink,
            onSelected: (v) => setState(() { selectedCategory = c; selectedCapacity = null; selectedUnit = null; }),
          )).toList()),
          
          if (selectedCategory != null) ...[
            const SizedBox(height: 20),
            _sectionHeader("Capacity", Icons.groups),
            Wrap(spacing: 8, children: currentCapacities.keys.map((cap) => ChoiceChip(
              label: Text(cap), selected: selectedCapacity == cap, selectedColor: brandPurple,
              onSelected: (v) => setState(() { selectedCapacity = cap; selectedUnit = null; }),
            )).toList()),
          ],

          if (selectedCapacity != null) ...[
            const SizedBox(height: 20),
            _sectionHeader("Select Unit", Icons.grid_view),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text("Tap any unit to view its calendar & availability", style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                _unitLegendCircle(const Color(0xFF81D4FA), "Avail"),
                const SizedBox(width: 8),
                _unitLegendCircle(Colors.orange, "Pre"),
                const SizedBox(width: 8),
                _unitLegendCircle(brandGreen, "Occ"),
              ],
            ),
            const SizedBox(height: 8),
            activeBookings.when(
              data: (bookings) {
                return Wrap(
                  spacing: 8, 
                  runSpacing: 8, 
                  children: List.generate(totalUnits, (i) {
                    final unitNum = capacityValue is List ? capacityValue[i] : i + 1;
                    final booking = bookings.firstWhere(
                      (b) => b['category'] == selectedCategory && 
                             b['capacity'] == selectedCapacity && 
                             b['unitNumber'] == unitNum,
                      orElse: () => {},
                    );
                    
                    final status = booking['status'] ?? 'Available';
                    final now = DateTime.now();
                    bool isOverdue = false;
                    String timeHint = '';

                    if (status == 'occupied' && booking['checkOutDate'] != null) {
                      final checkOut = (booking['checkOutDate'] as Timestamp?)?.toDate();
                      if (checkOut != null) {
                        if (checkOut.isBefore(now)) {
                          isOverdue = true;
                          final diff = now.difference(checkOut);
                          timeHint = 'Overdue ${diff.inHours}h ${diff.inMinutes % 60}m';
                        } else {
                          final diff = checkOut.difference(now);
                          if (diff.inHours < 24) {
                            timeHint = 'Out in ${diff.inHours}h ${diff.inMinutes % 60}m';
                          }
                        }
                      }
                    } else if (status == 'pre-booked' && booking['reportingDate'] != null) {
                       final reporting = (booking['reportingDate'] as Timestamp).toDate();
                       if (reporting.isBefore(now.subtract(const Duration(hours: 2)))) {
                         isOverdue = true;
                         timeHint = 'Late Arrival';
                       }
                    }

                    Color chipColor = const Color(0xFF81D4FA); // Sky Blue for Available
                    Color textColor = Colors.black87;
                    bool isSolid = false;

                    if (status == 'pre-booked') {
                      chipColor = isOverdue ? Colors.red : Colors.orange;
                      textColor = Colors.white;
                      isSolid = true;
                    } else if (status == 'occupied') {
                      chipColor = isOverdue ? Colors.red : brandGreen;
                      textColor = Colors.white;
                      isSolid = true;
                    }

                    // Build date-range sub-label for booked units
                    String dateLabel = '';
                    if (status != 'Available' && booking['reportingDate'] != null && booking['checkOutDate'] != null) {
                      final fmt = (Timestamp t) {
                        final d = t.toDate();
                        const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                        return '${d.day} ${months[d.month]}';
                      };
                      dateLabel = '${fmt(booking['reportingDate'] as Timestamp)} → ${fmt(booking['checkOutDate'] as Timestamp)}';
                    }

                    return GestureDetector(
                      onTap: () {
                        // Always open the calendar sheet
                        setState(() => selectedUnit = unitNum);
                        showUnitCalendar(
                          context,
                          category: selectedCategory!,
                          capacity: selectedCapacity!,
                          unitNumber: unitNum,
                          chargingMode: chargingMode,
                          currentBooking: status != 'Available' ? booking : null,
                          onBookDates: (checkIn, checkOut) {
                            // Pre-fill dates and open the customer form
                            setState(() {
                              selectedDate = checkIn;
                              expectedCheckOutDate = checkOut;
                            });
                            openCustomerForm();
                          },
                          onCheckIn: (b) async {
                            await ref.read(bookingRepositoryProvider).confirmCheckIn(b['id']);
                            if (mounted) {
                              Navigator.pop(context); // Close calendar sheet
                              _handleExistingBooking(b); // Re-open detail if needed, or just show success
                            }
                          },
                          onCheckOut: (b) {
                            Navigator.pop(context); // Close calendar sheet
                            _showCheckOutDialog(b); // Open checkout billing dialog
                          },
                          onCancel: (b, {reason}) async {
                            await ref.read(bookingRepositoryProvider).cancelBooking(b['id'], reason: reason);
                            if (mounted) {
                              Navigator.pop(context); // Close calendar sheet
                            if (mounted) {
                              messengerKey.currentState?.showSnackBar(
                                SnackBar(content: Text("Booking Cancelled ${reason != null ? '($reason)' : ''}")),
                              );
                            }
                            }
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSolid ? chipColor : chipColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSolid ? chipColor : chipColor.withOpacity(0.5), width: 1),
                          boxShadow: isSolid ? [BoxShadow(color: chipColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'Available' ? Icons.check_circle_outline
                                    : status == 'occupied' ? Icons.hotel
                                    : Icons.event_seat,
                                  size: 14,
                                  color: status == 'Available' ? Colors.blueGrey : (isOverdue ? Colors.red : chipColor),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    FormatUtils.formatUnit(selectedCategory, unitNum),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              isOverdue ? "OVERDUE" : (status == 'Available' ? 'Available' : status.toUpperCase()),
                              style: TextStyle(fontSize: 10, color: isSolid ? Colors.white.withOpacity(0.9) : chipColor, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            if (dateLabel.isNotEmpty)
                              Text(dateLabel, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                            if (timeHint.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(timeHint, style: TextStyle(fontSize: 9, color: isOverdue ? Colors.red[700] : Colors.black87, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
                              ),
                            // Tap icon hint
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                status == 'Available' ? '📅 Tap to book' : '📅 Tap for calendar',
                                style: const TextStyle(fontSize: 9, color: Colors.black45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text("Error loading units: $e"),
            ),
          ],
        ],
      ),
    );
  }

  void _handleExistingBooking(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${booking['customerName']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Phone: ${booking['phone']}"),
            Text("Status: ${booking['status'].toUpperCase()}"),
            if (booking['status'] == 'pre-booked')
              Text("Reporting Date: ${(booking['reportingDate'] as Timestamp).toDate().toString().split(' ')[0]}"),
            if (booking['checkOutDate'] != null)
              Text("Expected Check-Out: ${(booking['checkOutDate'] as Timestamp).toDate().toString().split(' ')[0]}"),
            const SizedBox(height: 10),
            Text("Advance Paid: ₹${booking['advancePayment']}"),
          ],
        ),
        actions: [
          if (booking['status'] == 'pre-booked') ...[
            TextButton(
              onPressed: () async {
                await ref.read(bookingRepositoryProvider).cancelBooking(booking['id']);
                Navigator.pop(context);
              },
              child: const Text("CANCEL BOOKING", style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(bookingRepositoryProvider).confirmCheckIn(booking['id']);
                Navigator.pop(context);
              },
              child: const Text("CONFIRM CHECK-IN", style: TextStyle(color: Colors.green)),
            ),
          ],
          if (booking['status'] == 'occupied') ...[
             TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCheckOutDialog(booking);
              },
              child: const Text("CHECK-OUT", style: TextStyle(color: Colors.orange)),
            ),
          ],
        ],
      ),
    );
  }

  void _showCheckOutDialog(Map<String, dynamic> booking) {
    final double? existingTotal = booking['totalPayment'] != null ? (booking['totalPayment'] as num).toDouble() : null;
    final hasFullPayment = existingTotal != null && existingTotal > 0;
    final totalController = TextEditingController(text: existingTotal?.toStringAsFixed(0) ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Check-Out Confirmation"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${booking['customerName']}"),
            Text("Amount Paid: ₹${booking['advancePayment']}"),
            const SizedBox(height: 10),
            if (!hasFullPayment)
              TextField(
                controller: totalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Total Bill Amount (₹)"),
              )
            else
              Text("Status: Paid in Full (₹$existingTotal)", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final total = double.tryParse(totalController.text) ?? 0;
              await ref.read(bookingRepositoryProvider).checkOut(
                bookingId: booking['id'],
                totalPayment: total,
                paymentMode: "Cash",
              );
              
              if (mounted) {
                Navigator.pop(context);
                
                // Show choice for receipt
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Checkout Complete"),
                    content: const Text("Would you like to generate a receipt for this customer?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("NO, LATER"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // We pass the updated values to the generator
                          final updatedBooking = {
                            ...booking,
                            'totalPayment': total,
                            'paymentMode': 'Cash',
                            'checkOutAt': Timestamp.now(),
                          };
                          ReceiptService.showPrintOptions(context, updatedBooking);
                        },
                        child: const Text("GENERATE RECEIPT"),
                      ),
                    ],
                  ),
                );
              }
              
              if (mounted) {
                messengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text("Checked out successfully!")),
                );
              }
            },
            child: const Text("CONFIRM CHECK-OUT"),
          ),
        ],
      ),
    );
  }

  void _showBookingDetailDialog(Map<String, dynamic> b) {
    BookingDetailDialog.show(context, b);
  }

  Widget historyPage() {
    final allBookingsAsync = ref.watch(allBookingsProvider);

    return allBookingsAsync.when(
      data: (bookings) {
        // Apply Filters & Search
        List<Map<String, dynamic>> filteredList = bookings.where((b) {
          final matchesSearch = b['customerName'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || 
                              b['phone'].toString().contains(searchQuery);
          
          final matchesStatus = filterStatus == "All" || b['status'] == filterStatus.toLowerCase().replaceAll(" ", "-");
          final matchesCategory = filterCategory == "All" || b['category'] == filterCategory;

          return matchesSearch && matchesStatus && matchesCategory;
        }).toList();

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: (val) => setState(() => searchQuery = val),
                        decoration: InputDecoration(
                          hintText: "Search name or phone...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _filterMenu(),
                  ],
                ),
              ),

              // Categorization Tabs
              TabBar(
                labelColor: brandPurple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: brandPink,
                tabs: const [
                  Tab(text: "Today"),
                  Tab(text: "Month"),
                  Tab(text: "Year"),
                ],
              ),

              // Grouped Content
              Expanded(
                child: TabBarView(
                  children: [
                    _historyListGrouped(filteredList, "day"),
                    _historyListGrouped(filteredList, "month"),
                    _historyListGrouped(filteredList, "year"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  Widget _filterMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune, color: brandPurple),
      onSelected: (val) {
        if (["All", "Prebooked", "Occupied", "Checked Out", "Cancelled"].contains(val)) {
          setState(() => filterStatus = val);
        } else {
          setState(() => filterCategory = val);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(enabled: false, child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
        ...["All", "Prebooked", "Occupied", "Checked Out", "Cancelled"].map((s) => PopupMenuItem(value: s, child: Text(s))),
        const PopupMenuDivider(),
        const PopupMenuItem(enabled: false, child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
        ...["All", ...inventory.keys].map((c) => PopupMenuItem(value: c, child: Text(c))),
      ],
    );
  }

  Widget _historyListGrouped(List<Map<String, dynamic>> items, String type) {
    final now = DateTime.now();
    List<Map<String, dynamic>> list = items.where((b) {
      final date = (b['createdAt'] as Timestamp).toDate();
      if (type == "day") return date.day == now.day && date.month == now.month && date.year == now.year;
      if (type == "month") return date.month == now.month && date.year == now.year;
      return date.year == now.year;
    }).toList();

    if (list.isEmpty) return const Center(child: Text("No records found."));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final b = list[index];
        final status = b['status']?.toString().toUpperCase() ?? 'UNKNOWN';
        Color color = Colors.grey;
        if (status == 'PRE-BOOKED') color = Colors.orange;
        if (status == 'OCCUPIED') color = brandGreen;
        if (status == 'CHECKED-OUT') color = brandPurple;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            onTap: () => _showBookingDetailDialog(b),
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(Icons.receipt_long, color: color),
            ),
            title: Text(b['customerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${b['category']} | Unit ${b['unitNumber']}\n${DateFormat('dd MMM yyyy').format((b['createdAt'] as Timestamp).toDate())}"),
                const SizedBox(height: 4),
                Text(
                  _getPhaseString(b),
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${b['advancePayment'] + (b['totalPayment'] ?? 0)}", style: TextStyle(color: brandPurple, fontWeight: FontWeight.bold)),
                Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getPhaseString(Map<String, dynamic> b) {
    final status = b['status'] ?? '';
    final wasPrebooked = b['wasPrebooked'] ?? false;

    if (status == 'pre-booked') return "Pre-booked -> Next: Check-in";
    if (status == 'occupied') {
      return wasPrebooked ? "Pre-booked -> Checked-in" : "Direct Check-in";
    }
    if (status == 'checked-out') {
      return wasPrebooked ? "Pre-booked -> In -> Out" : "In -> Checked-out";
    }
    if (status == 'cancelled') {
      return wasPrebooked ? "Pre-booked -> Cancelled" : "Cancelled";
    }
    return status.toUpperCase();
  }

  Widget arrivalsPage() {
    final activeBookingsRef = ref.watch(activeBookingsProvider);
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return activeBookingsRef.when(
      data: (bookings) {
        return DefaultTabController(
          length: 2,
          initialIndex: _arrivalsInitialTab,
          child: Column(
            children: [
              TabBar(
                labelColor: brandPurple,
                indicatorColor: brandPink,
                tabs: [
                  Tab(text: "Today · ${DateFormat('dd MMM').format(now)}"),
                  Tab(text: "Tomorrow · ${DateFormat('dd MMM').format(tomorrow)}"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _arrivalListFilter(bookings, now),
                    _arrivalListFilter(bookings, tomorrow),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) {
        debugPrint("Arrivals Data Error: $e");
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Unable to load arrivals: $e", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          ),
        );
      },
    );
  }

  Widget _arrivalListFilter(List<Map<String, dynamic>> bookings, DateTime target) {
    // Include BOTH pre-booked AND occupied (confirmed) arrivals on the target date
    final filtered = bookings.where((b) {
      final status = b['status'];
      if (status != 'pre-booked') return false;
      final rTs = b['reportingDate'] as Timestamp?;
      if (rTs == null) return false;
      final date = rTs.toDate();
      return date.day == target.day && date.month == target.month && date.year == target.year;
    }).toList()
      ..sort((a, b) {
        final da = (a['reportingDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final db = (b['reportingDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        return da.compareTo(db);
      });

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              "No arrivals for ${DateFormat('dd MMM yyyy').format(target)}",
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: brandPurple.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: brandPurple.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _arrivalStat("Total Upcoming Arrivals", filtered.length, brandPurple),
            ],
          ),
        ),
        // Arrival cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final b = filtered[index];
              final isPrebooked = b['status'] == 'pre-booked';
              final cardColor = isPrebooked ? Colors.orange : brandGreen;
              final rTs = b['reportingDate'] as Timestamp?;
              if (rTs == null) return const SizedBox();
              final reportingTime = rTs.toDate();
              final checkOutDate = b['checkOutDate'] != null
                  ? (b['checkOutDate'] as Timestamp).toDate()
                  : null;
              
              // Countdown calculation
              final now = DateTime.now();
              final diff = reportingTime.difference(now);
              String countdown;
              Color countdownColor;
              if (diff.isNegative) {
                countdown = isPrebooked ? 'Overdue ${diff.inHours.abs()}h' : 'Checked In';
                countdownColor = isPrebooked ? Colors.red : brandGreen;
              } else if (diff.inMinutes < 60) {
                countdown = 'In ${diff.inMinutes}m';
                countdownColor = Colors.orange;
              } else if (diff.inHours < 24) {
                countdown = 'In ${diff.inHours}h';
                countdownColor = brandPurple;
              } else {
                countdown = DateFormat('hh:mm a').format(reportingTime);
                countdownColor = Colors.grey;
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Color accent bar
                      Container(width: 5, color: cardColor),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: cardColor.withOpacity(0.15),
                                    child: Icon(Icons.person, size: 18, color: cardColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b['customerName'] ?? 'Guest',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          b['phone'] ?? '',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Status badge
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: cardColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isPrebooked ? 'PRE-BOOKED' : 'CONFIRMED',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cardColor),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getPhaseString(b),
                                        style: TextStyle(fontSize: 8, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Info row
                              Wrap(
                                spacing: 12,
                                children: [
                                  _infoChip(Icons.hotel, 'Unit ${b['unitNumber']}', Colors.blueGrey),
                                  _infoChip(Icons.category, b['category'] ?? '', Colors.blueGrey),
                                  if (checkOutDate != null)
                                    _infoChip(Icons.logout, 'Out: ${DateFormat('dd MMM').format(checkOutDate)}', Colors.blueGrey),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Time + countdown + actions
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                                      const SizedBox(width: 3),
                                      Text(
                                        DateFormat('hh:mm a').format(reportingTime),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: countdownColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          countdown, 
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: countdownColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isPrebooked) 
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (diff.isNegative)
                                          InkWell(
                                            onTap: () async {
                                              await ref.read(bookingRepositoryProvider).cancelBooking(b['id'], reason: 'No-Show (Auto-Cancel)');
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text('AUTO-CANCEL', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        InkWell(
                                          onTap: () async {
                                            await ref.read(bookingRepositoryProvider).cancelBooking(b['id']);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.red),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('CANCEL', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            await ref.read(bookingRepositoryProvider).confirmCheckIn(b['id']);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: brandGreen,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('CHECK-IN', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    InkWell(
                                      onTap: () => _handleExistingBooking(b),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: brandPurple,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('DETAILS', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget activeCheckInsPage() {
    final activeBookingsRef = ref.watch(activeBookingsProvider);
    return activeBookingsRef.when(
      data: (bookings) {
        final occupied = bookings.where((b) => b['status'] == 'occupied').toList();
        if (occupied.isEmpty) {
          return const Center(child: Text("No active check-ins at the moment."));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: occupied.length,
          itemBuilder: (context, index) {
            final b = occupied[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                onTap: () => _handleExistingBooking(b),
                leading: const CircleAvatar(backgroundColor: brandGreen, child: Icon(Icons.hotel, color: Colors.white)),
                title: Text(b['customerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${FormatUtils.formatUnit(b['category'], b['unitNumber'])} · ${b['category']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showAddFoodDialog(b),
                      icon: const Icon(Icons.restaurant, size: 16),
                      label: const Text("ADD FOOD"),
                      style: TextButton.styleFrom(foregroundColor: brandPurple),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  void _showAddFoodDialog(Map<String, dynamic> b) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Food Bill - ${b['customerName']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController, 
              decoration: const InputDecoration(labelText: "Item Name", hintText: "e.g. Lunch, Breakfast"),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController, 
              decoration: const InputDecoration(labelText: "Price (₹)", prefixText: "₹ "),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandPurple, foregroundColor: Colors.white),
            onPressed: () async {
              final price = double.tryParse(priceController.text) ?? 0.0;
              if (nameController.text.isNotEmpty && price > 0) {
                try {
                  await ref.read(bookingRepositoryProvider).addFoodItem(b['id'], nameController.text, price);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Added ${nameController.text} to ${b['customerName']}'s bill")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              }
            },
            child: const Text("ADD ITEM"),
          ),
        ],
      ),
    );
  }

  Widget _unitLegendCircle(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _arrivalStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget checkOutsPage() {
    final allBookingsAsync = ref.watch(allBookingsProvider);
    final now = DateTime.now();

    return allBookingsAsync.when(
      data: (bookings) {
        final departures = bookings.where((b) {
          if (b['status'] != 'checked-out') return false;
          final cTs = b['checkOutAt'] as Timestamp?;
          if (cTs == null) return false;
          final date = cTs.toDate();
          return date.day == now.day && date.month == now.month && date.year == now.year;
        }).toList();

        if (departures.isEmpty) {
          return const Center(child: Text("No check-outs recorded for today."));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _sectionHeader("Checked-Out Today (${departures.length})", Icons.fact_check),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: departures.length,
                itemBuilder: (context, index) {
                  final b = departures[index];
                  
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      onTap: () => _handleExistingBooking(b),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(b['customerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Unit ${b['unitNumber']} | ${b['category']}\nOut at: ${DateFormat('hh:mm a').format((b['checkOutAt'] as Timestamp).toDate())}"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandPurple,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero
                        ),
                        onPressed: () => _showBookingDetailDialog(b),
                        child: const Text("DETAILS", style: TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  Widget reportsPage() {
    final allBookingsAsync = ref.watch(allBookingsProvider);

    return allBookingsAsync.when(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader("Booking Statistics", Icons.pie_chart),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                   _miniReportCard("Pre-booked", "$prebooked", Colors.orange, Icons.history_edu, isSmall: true, onTap: () => setState(() => _currentIndex = 4)),
                   _miniReportCard("Confirmed", "$occupied", brandGreen, Icons.check_circle, isSmall: true, onTap: () => setState(() => _currentIndex = 1)),
                   _miniReportCard("Checked-Out", "$checkedOut", brandPurple, Icons.door_back_door, isSmall: true, onTap: () => setState(() { _currentIndex = 2; filterStatus = "Checked Out"; })),
                   _miniReportCard("Cancelled", "$cancelled", Colors.red, Icons.cancel, isSmall: true, onTap: () => setState(() { _currentIndex = 2; filterStatus = "Cancelled"; })),
                ],
              ),
              const SizedBox(height: 25),
              Center(
                child: ElevatedButton.icon(
                  onPressed: bookings.isEmpty ? null : () => ReportService.generateCustomerReport(bookings),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("GENERATE CUSTOMER REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text("Includes all pre-bookings and confirmed bookings",
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  Widget settingsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        _settingsTile(
          "Staff Profile", 
          Icons.person_outline, 
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const StaffProfileScreen())
          ),
        ),
        const Divider(),
        _settingsTile(
          "Help & Support", 
          Icons.help_outline, 
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const HelpSupportScreen())
          ),
        ),
        _settingsTile(
          "Privacy Policy", 
          Icons.privacy_tip_outlined, 
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen())
          ),
        ),
        const Divider(),
        _settingsTile("Logout", Icons.logout, isRed: true, onTap: _logout),
      ],
    );
  }

  /// ================= UI HELPERS =================

  Widget _homeActionCard(String t, IconData i, Color c, VoidCallback onTap, {int? count}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.3))),
        child: Stack(
          children: [
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, size: 35, color: c), 
                const SizedBox(height: 8), 
                Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 13))
              ]),
            ),
            if (count != null && count > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: brandPink, shape: BoxShape.circle),
                  child: Text("$count", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniReportCard(String t, String count, Color c, IconData i, {bool isSmall = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmall ? 10 : 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withOpacity(0.2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: c, size: isSmall ? 18 : 24),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count, style: TextStyle(fontSize: isSmall ? 16 : 22, fontWeight: FontWeight.bold, color: c), overflow: TextOverflow.ellipsis),
              Text(t, style: TextStyle(fontSize: isSmall ? 10 : 12, color: Colors.black54), overflow: TextOverflow.ellipsis),
            ]),
          )
        ]),
      ),
    );
  }

  Widget _settingsTile(String t, IconData i, {bool isRed = false, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(i, color: isRed ? Colors.red : brandPurple),
      title: Text(t, style: TextStyle(color: isRed ? Colors.red : Colors.black)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _sectionHeader(String t, IconData i) {
    return Row(children: [Icon(i, size: 20, color: brandPurple), const SizedBox(width: 8), Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      homePage(), 
      bookingsPage(), 
      historyPage(), 
      settingsPage(),
      arrivalsPage(), // Index 4
      checkOutsPage(), // Index 5
      reportsPage(), // Index 6
      activeCheckInsPage(), // Index 7
    ];
    
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: const Text("SHIVAM RESORT", style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        backgroundColor: brandPurple, 
        foregroundColor: Colors.white,
        leading: (_currentIndex >= 4 && _currentIndex <= 7) ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _currentIndex = 0),
        ) : null,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex > 3 ? 0 : _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: brandPink,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: "Bookings"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}
