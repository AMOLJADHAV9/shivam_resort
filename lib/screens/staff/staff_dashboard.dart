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

class StaffDashboard extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const StaffDashboard({super.key, this.isEmbedded = false});

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
  String customerType = "Family";
  DateTime? selectedDate;
  DateTime? expectedCheckOutDate;
  String chargingMode = "24h"; // 24h or flexible

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final paymentController = TextEditingController();
  final idProofController = TextEditingController();
  final totalPeopleController = TextEditingController(text: "1");
  final rentController = TextEditingController();
  final remainingPaymentController = TextEditingController();

  // History State
  final searchController = TextEditingController();
  String searchQuery = "";
  String filterStatus = "All";
  String filterCategory = "All";
  String reportFilterStatus = "All"; // "All", "pre-booked", "occupied", "checked-out"
  int _arrivalsInitialTab = 0; // 0 = Today, 1 = Tomorrow

  // Multi-unit selection state
  Set<dynamic> selectedUnitsCount = {}; 

  bool _isSaving = false;
  File? _idImage;
  File? _idImageBack;
  File? _guestPhoto;

  final Map<String, dynamic> inventory = {
    "Cottages": {
      "Magic Guest House - 2 Bed Cottage": [501, 502, 503, 504, 512, 511, 509, 510],
      "Magic Guest House - 3 Bed Cottage": [505, 506, 507, 508],
    },
    "Lodging Deluxe": {
      "Vishva Residency - 6 Bed Hall": ["009", "010", "109", "110"],
      "Vishva Residency - 2 Bed Room": ["003", "004", "103", "104"],
      "Vishva Residency - 3 Bed Room": ["001", "002", "005", "006", "007", "008", "101", "102", "105", "106", "107", "108", "111"],
    },
    "Dormitory": {
      "Party Hub - 11 Bed Hall": 1,
      "Magic Guest House - 20 Bed Hall": 1,
    },
    "Banquet Hall (AC)": {
      "Central Vistara - 300-400 Capacity": 1,
      "Green Orchid - 100-200 Capacity": 2,
    },
    "Lawn": {
      "Vanila Lawn - 50 People": 1,
      "Bombaya Lawn - 250-300 People": 1,
      "Shivamji Lawn - 2000-2500 People": 1,
    },
    "Function Hall": {
      "Shivam Function - 800-1200 Capacity": 1,
      "Royal Rituals - 300-400 Capacity": 1,
    },
    "Meeting Hall": {
      "Royal Dine - 20 Persons": 1,
    },
    "Saptapadi Hall": {
      "Mango Farm - 150-200 Persons": [1],
    },
    "One Day Stay Package": {
      "Standard Day Package": [1],
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

                // 2. Customer Type Selection
                Wrap(
                  spacing: 12,
                  children: ["Family", "Couple"].map((type) => ChoiceChip(
                    label: Text(type),
                    selected: customerType == type,
                    selectedColor: brandPink,
                    onSelected: (val) => setModalState(() => customerType = type),
                  )).toList(),
                ),
                const SizedBox(height: 10),

                // 2. Input Fields
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Customer Name", prefixIcon: Icon(Icons.person))),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone))),
                if (bookingType == "Confirmed" && customerType == "Family") ...[
                  TextField(controller: idProofController, decoration: const InputDecoration(labelText: "Aadhar / ID Proof", prefixIcon: Icon(Icons.badge))),
                  const Text("ID Proof Images (Front & Back)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildIdSlot(
                          label: "FRONT SIDE",
                          file: _idImage,
                          onTap: () async {
                            final file = await _captureIdImage("ID Proof Front");
                            if (file != null) setModalState(() => _idImage = file);
                          },
                          onClear: () => setModalState(() => _idImage = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildIdSlot(
                          label: "BACK SIDE",
                          file: _idImageBack,
                          onTap: () async {
                            final file = await _captureIdImage("ID Proof Back");
                            if (file != null) setModalState(() => _idImageBack = file);
                          },
                          onClear: () => setModalState(() => _idImageBack = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Guest Photo Row
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
                                title: const Text("Capture Guest Photo"),
                                actions: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final img = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
                                      if (context.mounted) Navigator.pop(context, img);
                                    }, 
                                    icon: const Icon(Icons.camera_front), label: const Text("Selfie/Front")
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final img = await picker.pickImage(source: ImageSource.camera);
                                      if (context.mounted) Navigator.pop(context, img);
                                    }, 
                                    icon: const Icon(Icons.camera_alt), label: const Text("Camera")
                                  ),
                                ],
                              ),
                            );
                            if (image != null) {
                              setModalState(() => _guestPhoto = File(image.path));
                            }
                          },
                          icon: const Icon(Icons.face),
                          label: const Text("Capture Guest Photo"),
                          style: OutlinedButton.styleFrom(foregroundColor: brandPurple),
                        ),
                      ),
                      if (_guestPhoto != null) ...[
                        const SizedBox(width: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_guestPhoto!, width: 50, height: 50, fit: BoxFit.cover),
                        ),
                        IconButton(
                          onPressed: () => setModalState(() => _guestPhoto = null),
                          icon: const Icon(Icons.cancel, color: Colors.red),
                        )
                      ]
                    ],
                  ),
                ],
                
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
                    : "Reporting: ${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year} ${selectedDate!.hour}:${selectedDate!.minute.toString().padLeft(2, '0')}"),
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
                    : "Check-Out: ${DateFormat('dd/MM/yyyy, hh:mm a').format(expectedCheckOutDate!)}"),
                  style: OutlinedButton.styleFrom(foregroundColor: brandPurple),
                ),

                TextField(controller: totalPeopleController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Total People", prefixIcon: Icon(Icons.groups))),

                const SizedBox(height: 10),
                TextField(
                  controller: rentController, 
                  keyboardType: TextInputType.number, 
                  onChanged: (v) {
                    final rent = double.tryParse(v) ?? 0.0;
                    final adv = double.tryParse(paymentController.text) ?? 0.0;
                    remainingPaymentController.text = (rent - adv).toStringAsFixed(0);
                    setModalState(() {});
                  },
                  decoration: const InputDecoration(labelText: "Room Rent (₹)", prefixIcon: Icon(Icons.apartment))
                ),

                const SizedBox(height: 15),
                // Calculation Summary Widget
                if (rentController.text.isNotEmpty) Builder(
                  builder: (context) {
                    final rent = double.tryParse(rentController.text) ?? 0.0;
                    final total = rent;
                    final adv = double.tryParse(paymentController.text) ?? 0.0;
                    final rem = total - adv;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: brandPurple.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: brandPurple.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          _calcRow("Total Rent", "₹${total.toStringAsFixed(0)}", isBold: true),
                          _calcRow("Paid (Advance)", "- ₹${adv.toStringAsFixed(0)}"),
                          _calcRow("Balance Remaining", "₹${rem.toStringAsFixed(0)}", color: brandPink, isBold: true),
                        ],
                      ),
                    );
                  }
                ),

                TextField(
                  controller: paymentController, 
                  keyboardType: TextInputType.number, 
                  onChanged: (v) {
                    final adv = double.tryParse(v) ?? 0.0;
                    final rent = double.tryParse(rentController.text) ?? 0.0;
                    remainingPaymentController.text = (rent - adv).toStringAsFixed(0);
                    setModalState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: bookingType == "Prebook" ? "Advance Payment (₹)" : "Full Payment (₹)", 
                    prefixIcon: const Icon(Icons.payments_outlined)
                  )
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: remainingPaymentController, 
                  keyboardType: TextInputType.number, 
                  onChanged: (v) {
                    final rem = double.tryParse(v) ?? 0.0;
                    final rent = double.tryParse(rentController.text) ?? 0.0;
                    paymentController.text = (rent - rem).toStringAsFixed(0);
                    setModalState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: "Remaining Payment (₹)", 
                    prefixIcon: Icon(Icons.pending_actions)
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
                    
                    if (bookingType == "Confirmed" && customerType == "Family" && idProofController.text.trim().isEmpty) {
                      if (context.mounted) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(content: Text("ID Proof is mandatory for confirmed bookings")),
                        );
                      }
                      return;
                    }
                    
                    setState(() => _isSaving = true);
                    try {
                      String? idImageUrl;
                      String? idImageBackUrl;
                      String? guestPhotoUrl;

                      if (_idImage != null) {
                        idImageUrl = await CloudinaryService.uploadIdProof(_idImage!);
                        if (idImageUrl == null && mounted) {
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(content: Text("Failed to upload ID image. Continuing with database only.")),
                          );
                        }
                      }
                      if (_idImageBack != null) {
                        idImageBackUrl = await CloudinaryService.uploadIdProof(_idImageBack!);
                        if (idImageBackUrl == null && mounted) {
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(content: Text("Failed to upload ID back image. Continuing with database only.")),
                          );
                        }
                      }
                      if (_guestPhoto != null) {
                        guestPhotoUrl = await CloudinaryService.uploadIdProof(_guestPhoto!);
                        if (guestPhotoUrl == null && mounted) {
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(content: Text("Failed to upload guest photo. Continuing with database only.")),
                          );
                        }
                      }

                      final roomRent = double.tryParse(rentController.text.trim()) ?? 0.0;
                      const gstPercent = 0.0;
                      const gstAmount = 0.0;
                      final advance = double.tryParse(paymentController.text.trim()) ?? 0.0;
                      final totalWithGst = roomRent;
                      final remainingRent = totalWithGst - advance;

                      await ref.read(bookingRepositoryProvider).saveBooking(
                        customerName: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        idProof: idProofController.text.trim(),
                        category: selectedCategory!,
                        capacity: selectedCapacity!,
                        unitNumbers: selectedUnitsCount.toList(), // Pass the list of units
                        reportingDate: selectedDate!,
                        checkOutDate: expectedCheckOutDate!,
                        advancePayment: advance,
                        roomRent: roomRent,
                        gstPercent: gstPercent,
                        gstAmount: gstAmount,
                        remainingRent: remainingRent,
                        status: bookingType == "Prebook" ? "pre-booked" : "occupied",
                        chargingMode: chargingMode,
                        totalPeople: int.tryParse(totalPeopleController.text) ?? 1,
                        idImageUrl: idImageUrl,
                        idImageBackUrl: idImageBackUrl,
                        guestPhotoUrl: guestPhotoUrl,
                        customerType: customerType,
                        packageName: selectedCategory == "One Day Stay Package" ? selectedCapacity : null,
                        packageInclusions: selectedCategory == "One Day Stay Package" ? ["Activity", "Food-Breakfast", "Lunch", "High Tea"] : null,
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

                                    final roomRent = double.tryParse(rentController.text.trim()) ?? 0.0;
                                    const gstP = 0.0;
                                    const gstA = 0.0;
                                    final advance = double.tryParse(paymentController.text.trim()) ?? 0.0;
                                    final total = roomRent;

                                    final bookingData = {
                                      'customerName': nameController.text.trim(),
                                      'phone': phoneController.text.trim(),
                                      'idProof': idProofController.text.trim(),
                                      'category': selectedCategory!,
                                      'capacity': selectedCapacity!,
                                      'unitNumbers': selectedUnitsCount.toList(),
                                      'reportingDate': bookingCheckIn != null ? Timestamp.fromDate(bookingCheckIn) : null,
                                      'checkOutDate': bookingCheckOut != null ? Timestamp.fromDate(bookingCheckOut) : null,
                                      'checkInAt': bookingCheckIn != null ? Timestamp.fromDate(bookingCheckIn) : null,
                                      'roomRent': roomRent,
                                      'gstPercent': gstP,
                                      'gstAmount': gstA,
                                      'advancePayment': advance,
                                      'remainingRent': total - advance,
                                      'status': 'occupied',
                                      'chargingMode': chargingMode,
                                      'totalPeople': int.tryParse(totalPeopleController.text) ?? 1,
                                      'idImageUrl': idImageUrl,
                                      'idImageBackUrl': idImageBackUrl,
                                      'guestPhotoUrl': guestPhotoUrl,
                                      'customerType': customerType,
                                      if (selectedCategory == "One Day Stay Package") 'packageName': selectedCapacity,
                                      if (selectedCategory == "One Day Stay Package") 'packageInclusions': ["Activity", "Food-Breakfast", "Lunch", "High Tea"],
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
                          messengerKey.currentState?.showSnackBar(
                            SnackBar(backgroundColor: brandGreen, content: Text("Booking Saved for ${FormatUtils.formatUnit(selectedCategory, selectedUnit)}!")),
                          );
                        }
                        // Clear fields
                        nameController.clear();
                        phoneController.clear();
                        paymentController.clear();
                        rentController.clear();
                        remainingPaymentController.clear();
                        idProofController.clear();
                        totalPeopleController.text = "1";
                        setState(() {
                          customerType = "Family";
                          selectedUnit = null;
                          selectedDate = null;
                          expectedCheckOutDate = null;
                           _idImage = null;
                           _idImageBack = null;
                           _guestPhoto = null;
                           selectedUnitsCount.clear();
                        });
                      }
                    } catch (e) {
                      if (context.mounted) {
                        messengerKey.currentState?.showSnackBar(
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
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: GridView.extent(
                    maxCrossAxisExtent: 220,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12, 
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
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
                ),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader("Category", Icons.category),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: inventory.keys.map((c) => ChoiceChip(
                label: Text(c), selected: selectedCategory == c, selectedColor: brandPink,
                onSelected: (v) => setState(() { 
                  selectedCategory = c; 
                  selectedCapacity = null; 
                  selectedUnit = null; 
                  selectedUnitsCount.clear(); // Reset selection
                }),
              )).toList()),
              
              if (selectedCategory != null) ...[
                const SizedBox(height: 20),
                _sectionHeader("Capacity", Icons.groups),
                Wrap(spacing: 8, children: currentCapacities.keys.map((cap) => ChoiceChip(
                  label: Text(cap), selected: selectedCapacity == cap, selectedColor: brandPurple,
                  onSelected: (v) => setState(() { 
                    selectedCapacity = cap; 
                    selectedUnit = null; 
                    selectedUnitsCount.clear(); // Reset selection
                  }),
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
                    } else if (status == 'cleaning' && booking['cleaningUntil'] != null) {
                        final until = (booking['cleaningUntil'] as Timestamp?)?.toDate();
                        if (until != null && until.isAfter(now)) {
                          final diff = until.difference(now);
                          timeHint = 'Cleaning ${diff.inMinutes}m left';
                        } else {
                          isOverdue = true;
                          timeHint = 'Cleaning Overdue';
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
                    } else if (status == 'cleaning') {
                      chipColor = isOverdue ? Colors.orange[700]! : Colors.blueGrey;
                      textColor = Colors.white;
                      isSolid = true;
                    }

                    // Build date-range sub-label for booked units
                    String dateLabel = '';
                    if (status != 'Available' && booking['reportingDate'] != null && booking['checkOutDate'] != null) {
                      final fmt = (dynamic t) {
                        if (t is! Timestamp) return '??';
                        final d = t.toDate();
                        const months = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                        return '${d.day} ${months[d.month]}';
                      };
                      dateLabel = '${fmt(booking['reportingDate'])} → ${fmt(booking['checkOutDate'])}';
                    }

                    return GestureDetector(
                      onTap: () {
                        if (status == 'Available') {
                          // Toggle multi-selection for available units
                          setState(() {
                            if (selectedUnitsCount.contains(unitNum)) {
                              selectedUnitsCount.remove(unitNum);
                            } else {
                              selectedUnitsCount.add(unitNum);
                            }
                            selectedUnit = selectedUnitsCount.isNotEmpty ? selectedUnitsCount.first : null;
                          });
                          return;
                        }

                        // For already booked/cleaning units, show calendar/management options
                        setState(() { 
                          selectedUnit = unitNum;
                          selectedUnitsCount.clear(); // Reset selection when interacting with a booked unit
                        });
                        
                        showUnitCalendar(
                          context,
                          category: selectedCategory!,
                          capacity: selectedCapacity!,
                          unitNumber: unitNum,
                          chargingMode: chargingMode,
                          currentBooking: (status != 'Available' && status != 'cleaning') ? booking : null,
                          onBookDates: (checkIn, checkOut) {
                            // Pre-fill dates and open the customer form for this single unit
                            setState(() {
                              selectedDate = checkIn;
                              expectedCheckOutDate = checkOut;
                              selectedUnitsCount = {unitNum};
                            });
                            openCustomerForm();
                          },
                          onCheckIn: (b) async {
                             await _confirmCheckInWithValidation(b);
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

                        if (status == 'cleaning') {
                          _showFinishCleaningDialog(booking);
                          return;
                        }
                      },
                      onLongPress: () {
                        // Long press to enter multi-select even if it was not started
                        if (status == 'Available') {
                          setState(() {
                            selectedUnitsCount.add(unitNum);
                            selectedUnit = selectedUnitsCount.first;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedUnitsCount.contains(unitNum) 
                              ? brandPurple.withOpacity(0.8) // Highlight selected units
                              : (isSolid ? chipColor : chipColor.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedUnitsCount.contains(unitNum)
                                ? brandPurple
                                : (isSolid ? chipColor : chipColor.withOpacity(0.5)), 
                            width: selectedUnitsCount.contains(unitNum) ? 2 : 1
                          ),
                          boxShadow: (isSolid || selectedUnitsCount.contains(unitNum)) 
                              ? [BoxShadow(color: (selectedUnitsCount.contains(unitNum) ? brandPurple : chipColor).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] 
                              : null,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      selectedUnitsCount.contains(unitNum) ? Icons.check_circle
                                        : (status == 'Available' ? Icons.check_circle_outline
                                          : status == 'occupied' ? Icons.hotel
                                          : status == 'cleaning' ? Icons.cleaning_services
                                          : Icons.event_seat),
                                      size: 14,
                                      color: selectedUnitsCount.contains(unitNum)
                                          ? Colors.white
                                          : (status == 'Available' ? Colors.blueGrey : (isOverdue ? Colors.red : chipColor)),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        FormatUtils.formatUnit(selectedCategory, unitNum),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 13, 
                                          color: selectedUnitsCount.contains(unitNum) ? Colors.white : textColor
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  selectedUnitsCount.contains(unitNum) ? "SELECTED" : (isOverdue ? "OVERDUE" : (status == 'Available' ? 'Available' : status.toUpperCase())),
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: (isSolid || selectedUnitsCount.contains(unitNum)) ? Colors.white.withOpacity(0.9) : chipColor, 
                                    fontWeight: FontWeight.w900, 
                                    letterSpacing: 0.5
                                  ),
                                ),
                                if (dateLabel.isNotEmpty && !selectedUnitsCount.contains(unitNum))
                                  Text(dateLabel, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                if (timeHint.isNotEmpty && !selectedUnitsCount.contains(unitNum))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(timeHint, style: TextStyle(fontSize: 9, color: isOverdue ? Colors.red[700] : Colors.black87, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
                                  ),
                              ],
                            ),
                            if (selectedUnitsCount.contains(unitNum))
                              const Positioned(
                                top: -12,
                                right: -12,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: brandPurple,
                                  child: Icon(Icons.check, size: 12, color: Colors.white),
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
                const SizedBox(height: 20),
                if (selectedUnitsCount.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: brandPurple.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: brandPurple.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_basket_outlined, color: brandPurple),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${selectedUnitsCount.length} Unit(s) Selected",
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: brandPurple),
                                  ),
                                  Text(
                                    "Selected: ${selectedUnitsCount.join(', ')}",
                                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => selectedUnitsCount.clear()),
                              child: const Text("Clear", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                             if (selectedUnitsCount.isEmpty) return;
                             openCustomerForm();
                          },
                          icon: const Icon(Icons.add_circle),
                          label: const Text("Book Selected Units", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ],
          ),
        ),
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
            if (booking['status'] == 'pre-booked' && booking['reportingDate'] != null)
              Text("Reporting Date: ${(booking['reportingDate'] as Timestamp?)?.toDate().toString().split(' ')[0]}"),
            if (booking['checkOutDate'] != null)
              Text("Expected Check-Out: ${(booking['checkOutDate'] as Timestamp?)?.toDate().toString().split(' ')[0]}"),
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
                Navigator.pop(context);
                await _confirmCheckInWithValidation(booking);
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
  Future<void> _confirmCheckInWithValidation(Map<String, dynamic> b) async {
    final isCouple = b['customerType'] == 'Couple';
    final hasId = b['idProof'] != null && b['idProof'].toString().trim().isNotEmpty;
    
    // For couple bookings, skip ID proof entirely
    if (isCouple || hasId) {
      try {
        await ref.read(bookingRepositoryProvider).confirmCheckIn(b['id']);
        if (mounted) {
           messengerKey.currentState?.showSnackBar(
            SnackBar(backgroundColor: brandGreen, content: Text("Checked-in ${b['customerName']}!")),
          );
        }
      } catch (e) {
        if (mounted) {
          messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
      return;
    }

    // Missing ID (Family booking) - Show specialized dialog
    final idController = TextEditingController();
    File? tempIdImage;
    File? tempIdImageBack;
    File? tempGuestPhoto;
    bool isSavingLocal = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Complete Check-In Details", style: TextStyle(color: brandPurple, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("This was a pre-booking. Please fill in the ID Proof details and Guest Photo to proceed.", style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 15),
              if (b['customerType'] != 'Couple') ...[
                TextField(
                  controller: idController, 
                  decoration: const InputDecoration(labelText: "Aadhar / ID Proof", prefixIcon: Icon(Icons.badge), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                const Text("ID Proof Images (Front & Back)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildIdSlot(
                        label: "FRONT SIDE",
                        file: tempIdImage,
                        onTap: () async {
                          final file = await _captureIdImage("ID Proof Front");
                          if (file != null) setDialogState(() => tempIdImage = file);
                        },
                        onClear: () => setDialogState(() => tempIdImage = null),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildIdSlot(
                        label: "BACK SIDE",
                        file: tempIdImageBack,
                        onTap: () async {
                          final file = await _captureIdImage("ID Proof Back");
                          if (file != null) setDialogState(() => tempIdImageBack = file);
                        },
                        onClear: () => setDialogState(() => tempIdImageBack = null),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 15),
              // Guest Photo row
              Row(
                children: [
                   OutlinedButton.icon(
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await showDialog<XFile?>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Guest Face Photo"),
                            actions: [
                              TextButton.icon(onPressed: () async {
                                final img = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
                                if (context.mounted) Navigator.pop(context, img);
                              }, icon: const Icon(Icons.camera_front), label: const Text("Front Cam")),
                              TextButton.icon(onPressed: () async {
                                final img = await picker.pickImage(source: ImageSource.camera);
                                if (context.mounted) Navigator.pop(context, img);
                              }, icon: const Icon(Icons.camera_alt), label: const Text("Rear Cam")),
                            ],
                          ),
                        );
                        if (image != null) {
                          setDialogState(() => tempGuestPhoto = File(image.path));
                        }
                      },
                      icon: const Icon(Icons.face),
                      label: const Text("Guest Photo"),
                    ),
                    if (tempGuestPhoto != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.check_circle, color: Colors.green),
                      IconButton(onPressed: () => setDialogState(() => tempGuestPhoto = null), icon: const Icon(Icons.cancel, color: Colors.red)),
                    ]
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSavingLocal ? null : () => Navigator.pop(context), 
              child: const Text("CANCEL")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brandPurple, foregroundColor: Colors.white),
              onPressed: isSavingLocal ? null : () async {
                if (b['customerType'] != 'Couple' && idController.text.trim().isEmpty) {
                   messengerKey.currentState?.showSnackBar(const SnackBar(content: Text("ID Proof is required")));
                   return;
                }
                setDialogState(() => isSavingLocal = true);
                try {
                  String? idImageUrl;
                  if (tempIdImage != null) {
                    idImageUrl = await CloudinaryService.uploadIdProof(tempIdImage!);
                  }
                  
                  String? idImageBackUrl;
                  if (tempIdImageBack != null) {
                    idImageBackUrl = await CloudinaryService.uploadIdProof(tempIdImageBack!);
                  }
                  
                  String? guestPhotoUrl;
                  if (tempGuestPhoto != null) {
                    guestPhotoUrl = await CloudinaryService.uploadIdProof(tempGuestPhoto!);
                  }
                  
                  await ref.read(bookingRepositoryProvider).confirmCheckIn(
                    b['id'],
                    idProof: idController.text.trim(),
                    idImageUrl: idImageUrl,
                    idImageBackUrl: idImageBackUrl,
                    guestPhotoUrl: guestPhotoUrl,
                  );
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) {
                    messengerKey.currentState?.showSnackBar(
                      SnackBar(backgroundColor: brandGreen, content: Text("Checked-in ${b['customerName']}!")),
                    );
                  }
                } catch (e) {
                   if (context.mounted) messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  setDialogState(() => isSavingLocal = false);
                }
              },
              child: isSavingLocal ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("CONFIRM CHECK-IN"),
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckOutDialog(Map<String, dynamic> booking) {
    final double advance = (booking['advancePayment'] as num?)?.toDouble() ?? 0.0;
    final double initialRemaining = (booking['remainingRent'] as num?)?.toDouble() ?? 0.0;
    final foodItems = (booking['foodBills'] as List?) ?? [];
    double foodTotal = 0.0;
    for (var item in foodItems) {
      foodTotal += (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
    }

    final remainingController = TextEditingController(text: initialRemaining.toStringAsFixed(0));
    final gstPercentController = TextEditingController(text: "12");
    bool addGst = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double remaining = double.tryParse(remainingController.text) ?? 0.0;
          final double gstPercent = double.tryParse(gstPercentController.text) ?? 0.0;
          final double subTotal = advance + remaining;
          final double gstAmount = addGst ? (subTotal * (gstPercent / 100)) : 0.0;
          final double grandTotal = subTotal + gstAmount;
          final double balance = grandTotal - advance;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Check-Out Confirmation", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Guest: ${booking['customerName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 15),
                    
                    Text("Booking Rent (Advance already paid): ₹${advance.toStringAsFixed(0)}", 
                         style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 8),
                    
                    TextField(
                      controller: remainingController,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: "Remaining Rent to Pay (₹)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixText: "₹ ",
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Rent Sub-Total", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹${subTotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 30),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Fooding Items (For Info Only)", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showAddFoodDialog(booking);
                          },
                          child: const Text("EDIT/ADD", style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    if (foodItems.isEmpty)
                      Text("No food items added", style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic))
                    else
                      ...foodItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("• ${item['name']}", style: const TextStyle(fontSize: 12)),
                            Text("₹${item['price']}", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
                    const Divider(height: 30),
                    
                    CheckboxListTile(
                      value: addGst,
                      onChanged: (v) => setDialogState(() => addGst = v ?? false),
                      title: const Text("Add GST (on Rent)", style: TextStyle(fontWeight: FontWeight.bold)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: brandPurple,
                    ),
                    if (addGst)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextField(
                          controller: gstPercentController,
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: "GST Percentage (%)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            suffixText: "%",
                            hintText: "e.g. 12 or 18",
                          ),
                        ),
                      ),
                    const Divider(height: 30),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Grand Total (Rent + GST)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("₹${grandTotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: brandGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text("RENT BALANCE TO COLLECT", 
                                 style: TextStyle(fontWeight: FontWeight.bold, color: brandGreen, fontSize: 14)),
                          ),
                          Text("₹${balance.toStringAsFixed(0)}", 
                               style: const TextStyle(fontWeight: FontWeight.w900, color: brandGreen, fontSize: 24)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: brandPink))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  try {
                    await ref.read(bookingRepositoryProvider).checkOut(
                      bookingId: booking['id'],
                      totalPayment: subTotal, // Base rent applied
                      paymentMode: "Cash",
                      gstAmount: gstAmount,
                      gstPercent: addGst ? gstPercent : 0,
                    );
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      
                      // Pass updated values to generator
                      final updatedBooking = {
                        ...booking,
                        'remainingRent': remaining,
                        'totalPayment': subTotal,
                        'gstAmount': gstAmount,
                        'gstPercent': addGst ? gstPercent : 0,
                        'paymentMode': 'Cash',
                        'checkOutAt': Timestamp.now(),
                      };
                      // 1. Cleaning Prompt
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: const Text("Unit Cleaning Status"),
                          content: const Text("Is this room already cleaned and ready for the next guest?"),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context); // Close cleaning dialog
                                await ref.read(bookingRepositoryProvider).startCleaning(booking['id']);
                                _showReceiptPrompt(updatedBooking);
                              },
                              child: const Text("CLEANING REQ.", style: TextStyle(color: Colors.orange)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context); // Close cleaning dialog
                                _showReceiptPrompt(updatedBooking);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
                              child: const Text("ALREADY CLEAN"),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                },
                child: const Text("CONFIRM CHECK-OUT"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReceiptPrompt(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Checkout Complete"),
        content: const Text("Would you like to generate a receipt for this customer?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NO, LATER")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ReceiptService.showPrintOptions(context, booking);
            },
            child: const Text("GENERATE RECEIPT"),
          ),
        ],
      ),
    );
  }

  void _showFinishCleaningDialog(Map<String, dynamic> booking) {
    final now = DateTime.now();
    final until = (booking['cleaningUntil'] as Timestamp?)?.toDate();
    final isOverdue = until != null && until.isBefore(now);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cleaning_services, color: isOverdue ? Colors.orange[700] : brandPurple),
            const SizedBox(width: 8),
            const Text("Unit Cleaning"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Unit: ${FormatUtils.formatUnit(booking['category'], booking['unitNumber'])}", 
                 style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            if (isOverdue) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text("CLEANING OVERDUE!", style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],
            Text(isOverdue 
              ? "Cleaning was supposed to finish at ${DateFormat('hh:mm a').format(until!)}. Is it done now?"
              : "Cleaning in progress. Estimated finish at ${DateFormat('hh:mm a').format(until!)}. Has it been finished early?"),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showExtendCleaningDialog(booking);
            },
            child: Text(isOverdue ? "EXTEND TIME" : "NEEDS MORE TIME", style: const TextStyle(color: Colors.orange)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("NOT YET", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookingRepositoryProvider).setAvailable(booking['id']);
              if (mounted) {
                messengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Unit marked as available!")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: brandGreen, foregroundColor: Colors.white),
            child: const Text("YES, IT'S READY"),
          ),
        ],
      ),
    );
  }

  void _showExtendCleaningDialog(Map<String, dynamic> booking) {
    int selectedMinutes = 30;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Extend Cleaning Time"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How much more time is required?"),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: [30, 60, 120].map((m) => ChoiceChip(
                  label: Text(m >= 60 ? "${m ~/ 60}h" : "${m}m"),
                  selected: selectedMinutes == m,
                  selectedColor: brandPurple.withOpacity(0.2),
                  onSelected: (val) {
                    if (val) setDialogState(() => selectedMinutes = m);
                  },
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref.read(bookingRepositoryProvider).extendCleaning(booking['id'], selectedMinutes);
                  if (mounted) {
                    messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Cleaning time extended by ${selectedMinutes}m")));
                  }
                } catch (e) {
                  if (mounted) {
                    messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: brandPurple, foregroundColor: Colors.white),
              child: const Text("CONFIRM EXTENSION"),
            ),
          ],
        ),
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

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
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

                // Grouped Content - Now showing all history in one list
                Expanded(
                  child: _historyListGrouped(filteredList, "all"),
                ),
              ],
            ),
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
      if (type == "all") return true; // Show all filtered items
      final createdAt = b['createdAt'] as Timestamp?;
      if (createdAt == null) return false;
      final date = createdAt.toDate();
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
        final inDate = (b['checkInAt'] as Timestamp?)?.toDate() ?? (b['reportingDate'] as Timestamp?)?.toDate();
        final outDate = (b['checkOutAt'] as Timestamp?)?.toDate() ?? (b['expectedCheckOutDate'] as Timestamp?)?.toDate();
        final df = DateFormat('dd/MM/yyyy');

        final status = b['status']?.toString().toUpperCase() ?? 'UNKNOWN';
        Color color = Colors.grey;
        if (status == 'PRE-BOOKED') color = Colors.orange;
        if (status == 'OCCUPIED') color = brandGreen;
        if (status == 'CHECKED-OUT' || status == 'CLEANING') color = brandPurple;

        final displayStatus = status == 'CLEANING' ? 'CHECKED-OUT' : status;

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
            title: Text(b['customerName'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${b['category']} | Unit ${b['unitNumber']}\nIn: ${inDate != null ? df.format(inDate) : '—'} | Out: ${outDate != null ? df.format(outDate) : '—'}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPhaseString(b),
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (displayStatus == 'CHECKED-OUT')
                  IconButton(
                    icon: const Icon(Icons.print, color: brandPurple, size: 20),
                    onPressed: () => ReceiptService.showPrintOptions(context, b),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${b['advancePayment'] + (b['totalPayment'] ?? 0)}", style: TextStyle(color: brandPurple, fontWeight: FontWeight.bold)),
                    Text(displayStatus, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                  ],
                ),
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
    if (status == 'checked-out' || status == 'cleaning') {
      return wasPrebooked ? "Pre-booked -> In -> Out" : "In -> Checked-out";
    }
    if (status == 'cancelled') {
      return wasPrebooked ? "Pre-booked -> Cancelled" : "Cancelled";
    }
    return status.toUpperCase();
  }

  Widget _calcRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
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
                  Tab(text: "Today · ${DateFormat('dd/MM').format(now)}"),
                  Tab(text: "Tomorrow · ${DateFormat('dd/MM').format(tomorrow)}"),
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
              "No arrivals for ${DateFormat('dd/MM/yyyy').format(target)}",
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: cardColor.withOpacity(0.15),
                                        child: Icon(Icons.person, size: 16, color: cardColor),
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
                                        _infoChip(Icons.logout, 'Out: ${DateFormat('dd/MM').format(checkOutDate)}', Colors.blueGrey),
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
                                                await _confirmCheckInWithValidation(b);
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
        ),
      ),
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
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView.builder(
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
                    leading: const CircleAvatar(radius: 18, backgroundColor: brandGreen, child: Icon(Icons.hotel, color: Colors.white, size: 18)),
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
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  void _showAddFoodDialog(Map<String, dynamic> b) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    
    // Local state for the session
    List<Map<String, dynamic>> localItems = List<Map<String, dynamic>>.from(b['foodBills'] ?? []);
    File? stagedPhoto;
    int? editingIndex;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.restaurant_menu, color: brandPurple),
                const SizedBox(width: 10),
                Expanded(child: Text("Food Expenses: ${b['customerName']}", style: const TextStyle(fontSize: 18))),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Input Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: brandPurple.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: "Description (e.g. Dinner)", prefixIcon: Icon(Icons.edit_note)),
                            textCapitalization: TextCapitalization.words,
                          ),
                          TextField(
                            controller: priceController,
                            decoration: const InputDecoration(labelText: "Amount (₹)", prefixIcon: Icon(Icons.currency_rupee)),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 10),
                          // Receipt photo row: camera + gallery buttons + preview
                          Row(
                            children: [
                              // Camera button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picker = ImagePicker();
                                    final img = await picker.pickImage(source: ImageSource.camera);
                                    if (img != null) setDialogState(() => stagedPhoto = File(img.path));
                                  },
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text("Camera", style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Gallery button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picker = ImagePicker();
                                    final img = await picker.pickImage(source: ImageSource.gallery);
                                    if (img != null) setDialogState(() => stagedPhoto = File(img.path));
                                  },
                                  icon: const Icon(Icons.photo_library, size: 18),
                                  label: Text(
                                    stagedPhoto != null ? "Change Photo" : "Gallery",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    foregroundColor: brandPurple,
                                    side: const BorderSide(color: brandPurple),
                                  ),
                                ),
                              ),
                              // Photo preview thumbnail
                              if (stagedPhoto != null) ...[
                                const SizedBox(width: 8),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(stagedPhoto!, width: 44, height: 44, fit: BoxFit.cover),
                                    ),
                                    Positioned(
                                      right: -8, top: -8,
                                      child: GestureDetector(
                                        onTap: () => setDialogState(() => stagedPhoto = null),
                                        child: Container(
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: brandPink, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40)),
                            onPressed: () {
                              final name = nameController.text.trim();
                              final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                              if (name.isEmpty || price <= 0) return;

                              setDialogState(() {
                                final newItem = {
                                  'name': name,
                                  'price': price,
                                  'timestamp': Timestamp.now(),
                                  'localPhoto': stagedPhoto, // Temporarily store File
                                  'imageUrl': editingIndex != null ? localItems[editingIndex!]['imageUrl'] : null,
                                };

                                if (editingIndex != null) {
                                  localItems[editingIndex!] = newItem;
                                  editingIndex = null;
                                } else {
                                  localItems.add(newItem);
                                }

                                nameController.clear();
                                priceController.clear();
                                stagedPhoto = null;
                              });
                            },
                            icon: Icon(editingIndex != null ? Icons.check : Icons.add),
                            label: Text(editingIndex != null ? "UPDATE ITEM" : "ADD NEXT BILL"),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    const Divider(),
                    const Text("ITEMIZED BILL LIST", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    
                    if (localItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("No items added yet", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                      )
                    else
                      ...List.generate(localItems.length, (index) {
                        final item = localItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: brandPurple.withOpacity(0.1),
                              child: Text("${index + 1}", style: const TextStyle(color: brandPurple, fontSize: 12)),
                            ),
                            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text("₹${item['price']}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      editingIndex = index;
                                      nameController.text = item['name'];
                                      priceController.text = item['price'].toString();
                                      stagedPhoto = item['localPhoto'] as File?;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => setDialogState(() => localItems.removeAt(index)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandPurple, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: isUploading ? null : () async {
                  setDialogState(() => isUploading = true);
                  try {
                    List<Map<String, dynamic>> finalItems = [];
                    for (var item in localItems) {
                      String? url = item['imageUrl'];
                      if (item['localPhoto'] != null) {
                        url = await CloudinaryService.uploadIdProof(item['localPhoto'] as File);
                      }
                      
                      finalItems.add({
                        'name': item['name'],
                        'price': item['price'],
                        'timestamp': item['timestamp'],
                        if (url != null) 'imageUrl': url,
                      });
                    }

                    await ref.read(bookingRepositoryProvider).setFoodBills(b['id'], finalItems);
                    if (context.mounted) {
                      Navigator.pop(context);
                      messengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Food bills updated successfully!")));
                    }
                  } catch (e) {
                    if (context.mounted) messengerKey.currentState?.showSnackBar(SnackBar(content: Text("Error: $e")));
                  } finally {
                    setDialogState(() => isUploading = false);
                  }
                },
                child: isUploading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("SAVE ALL CHANGES"),
              ),
            ],
          );
        },
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

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
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
                            radius: 18,
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          title: Text(b['customerName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Unit ${b['unitNumber']} | ${b['category']}\nOut at: ${DateFormat('hh:mm a').format((b['checkOutAt'] as Timestamp?)?.toDate() ?? DateTime.now())}"),
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
            ),
          ),
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
          if (status == 'checked-out' || status == 'cleaning') checkedOut++;
        }

        // Filter bookings for the PDF report
        final filteredBookings = bookings.where((b) {
          if (reportFilterStatus == "All") return b['status'] != 'cancelled';
          if (reportFilterStatus == "checked-out") return b['status'] == 'checked-out' || b['status'] == 'cleaning';
          return b['status'] == reportFilterStatus;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
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
                    childAspectRatio: 1.8,
                    children: [
                       _miniReportCard("Pre-booked", "$prebooked", Colors.orange, Icons.history_edu, isSmall: true, onTap: () => setState(() => _currentIndex = 4)),
                       _miniReportCard("Confirmed", "$occupied", brandGreen, Icons.check_circle, isSmall: true, onTap: () => setState(() => _currentIndex = 1)),
                       _miniReportCard("Checked-Out", "$checkedOut", brandPurple, Icons.door_back_door, isSmall: true, onTap: () => setState(() { _currentIndex = 2; filterStatus = "Checked Out"; })),
                       _miniReportCard("Cancelled", "$cancelled", Colors.red, Icons.cancel, isSmall: true, onTap: () => setState(() { _currentIndex = 2; filterStatus = "Cancelled"; })),
                    ],
                  ),
                  const SizedBox(height: 30),
                  
                  _sectionHeader("Generate Report", Icons.summarize),
                  const SizedBox(height: 10),
                  const Text("Filter the categories you want to include in the report:", style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text("All"),
                        selected: reportFilterStatus == "All",
                        onSelected: (v) => setState(() => reportFilterStatus = "All"),
                        selectedColor: brandPurple.withOpacity(0.2),
                        checkmarkColor: brandPurple,
                      ),
                      FilterChip(
                        label: const Text("Pre-booked"),
                        selected: reportFilterStatus == "pre-booked",
                        onSelected: (v) => setState(() => reportFilterStatus = "pre-booked"),
                        selectedColor: Colors.orange.withOpacity(0.2),
                        checkmarkColor: Colors.orange,
                      ),
                      FilterChip(
                        label: const Text("Occupied (In)"),
                        selected: reportFilterStatus == "occupied",
                        onSelected: (v) => setState(() => reportFilterStatus = "occupied"),
                        selectedColor: brandGreen.withOpacity(0.2),
                        checkmarkColor: brandGreen,
                      ),
                      FilterChip(
                        label: const Text("Checked-Out"),
                        selected: reportFilterStatus == "checked-out",
                        onSelected: (v) => setState(() => reportFilterStatus = "checked-out"),
                        selectedColor: brandPurple.withOpacity(0.2),
                        checkmarkColor: brandPurple,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 25),
                  Center(
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: filteredBookings.isEmpty ? null : () => ReportService.generateCustomerReport(filteredBookings),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: Text("GENERATE ${reportFilterStatus.toUpperCase()} REPORT", style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            minimumSize: const Size(300, 50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          reportFilterStatus == "All" 
                            ? "Includes all active and completed bookings (${filteredBookings.length} total)"
                            : "Includes only $reportFilterStatus bookings (${filteredBookings.length} found)",
                          style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                Icon(i, size: 28, color: c), 
                const SizedBox(height: 6), 
                Text(t, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 11))
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

  Widget _buildIdSlot({
    required String label,
    File? file,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: file != null ? Colors.green : Colors.grey[300]!, width: 2),
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image.file(file, width: double.infinity, height: 100, fit: BoxFit.cover),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: onClear,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.red, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                      const SizedBox(height: 4),
                      Text("Tap to capture", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ],
    );
  }

  Future<File?> _captureIdImage(String title) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showDialog<XFile?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.camera);
              if (context.mounted) Navigator.pop(context, img);
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text("Camera"),
          ),
          TextButton.icon(
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.gallery);
              if (context.mounted) Navigator.pop(context, img);
            },
            icon: const Icon(Icons.photo_library),
            label: const Text("Gallery"),
          ),
        ],
      ),
    );
    return image != null ? File(image.path) : null;
  }
}
