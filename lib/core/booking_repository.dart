import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of active bookings to track unit statuses (plus cleaning buffer)
  Stream<List<Map<String, dynamic>>> watchActiveBookings() {
    return _firestore
        .collection('bookings')
        .where('status', whereIn: ['pre-booked', 'occupied', 'cleaning'])
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          
          return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).where((b) {
            final status = b['status'];
            if (status == 'cleaning') {
              final cleaningUntil = (b['cleaningUntil'] as Timestamp?)?.toDate();
              // Only keep if cleaning is still ongoing
              return cleaningUntil != null && cleaningUntil.isAfter(now);
            }
            return true; // Keep all pre-booked and occupied
          }).toList();
        });
  }

  // Stream of all bookings for history
  Stream<List<Map<String, dynamic>>> watchAllBookings() {
    return _firestore
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  // Stream of all non-cancelled bookings for a specific unit (for calendar)
  Stream<List<Map<String, dynamic>>> watchUnitBookings({
    required String category,
    required String capacity,
    required dynamic unitNumber,
  }) {
    return _firestore
        .collection('bookings')
        .where('category', isEqualTo: category)
        .where('capacity', isEqualTo: capacity)
        .where('unitNumber', isEqualTo: unitNumber)
        .where('status', whereIn: ['pre-booked', 'occupied', 'cleaning'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> saveBooking({
    required String customerName,
    required String phone,
    String idProof = '',
    required String category,
    required String capacity,
    required dynamic unitNumber,
    required DateTime reportingDate,
    required DateTime checkOutDate,
    double advancePayment = 0.0,
    double gstPercent = 0.0,
    double gstAmount = 0.0,
    required String status, // 'pre-booked' or 'occupied'
    double remainingRent = 0.0,
    double roomRent = 0.0,
    String chargingMode = '24h',
    int totalPeople = 1,
    String? idImageUrl,
    String? idImageBackUrl,
    String? guestPhotoUrl,
    String? packageName,
    List<String>? packageInclusions,
  }) async {
    try {
      // Basic validation for dates
      if (reportingDate == null || checkOutDate == null) {
        throw 'Invalid dates provided for booking.';
      }

      final reportingTs = Timestamp.fromDate(reportingDate);
      final checkOutTs = Timestamp.fromDate(checkOutDate);

      await _firestore.collection('bookings').add({
        'customerName': customerName,
        'phone': phone,
        'idProof': idProof,
        'category': category,
        'capacity': capacity,
        'unitNumber': unitNumber,
        'reportingDate': reportingTs,
        'checkOutDate': checkOutTs,
        'advancePayment': advancePayment,
        'gstPercent': gstPercent,
        'gstAmount': gstAmount,
        'remainingRent': remainingRent,
        'roomRent': roomRent,
        'status': status,
        'chargingMode': chargingMode,
        'totalPeople': totalPeople,
        'wasPrebooked': status == 'pre-booked',
        'createdAt': FieldValue.serverTimestamp(),
        'idImageUrl': idImageUrl,
        'idImageBackUrl': idImageBackUrl,
        if (guestPhotoUrl != null) 'guestPhotoUrl': guestPhotoUrl,
        if (packageName != null) 'packageName': packageName,
        if (packageInclusions != null) 'packageInclusions': packageInclusions,
        if (status == 'occupied') 'checkInAt': reportingTs,
        if (status == 'occupied') 'totalPayment': roomRent,
      });
    } catch (e) {
      throw 'Failed to save booking: $e';
    }
  }

  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        if (reason != null) 'cancelReason': reason,
      });
    } catch (e) {
      throw 'Failed to cancel booking: $e';
    }
  }

  Future<void> confirmCheckIn(String bookingId, {String? idProof, String? idImageUrl, String? idImageBackUrl, String? guestPhotoUrl}) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'occupied',
        'checkInAt': FieldValue.serverTimestamp(),
        if (idProof != null) 'idProof': idProof,
        if (idImageUrl != null) 'idImageUrl': idImageUrl,
        if (idImageBackUrl != null) 'idImageBackUrl': idImageBackUrl,
        if (guestPhotoUrl != null) 'guestPhotoUrl': guestPhotoUrl,
      });
    } catch (e) {
      throw 'Failed to confirm check-in: $e';
    }
  }

  Future<void> checkOut({
    required String bookingId,
    required double totalPayment,
    required String paymentMode,
    double? gstAmount,
    double? gstPercent,
  }) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'checked-out',
        'totalPayment': totalPayment,
        'paymentMode': paymentMode,
        'checkOutAt': FieldValue.serverTimestamp(),
        if (gstAmount != null) 'gstAmount': gstAmount,
        if (gstPercent != null) 'gstPercent': gstPercent,
      });
    } catch (e) {
      throw 'Failed to check-out: $e';
    }
  }

  Future<void> addFoodItem(String bookingId, String itemName, double price, [String? imageUrl]) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'foodBills': FieldValue.arrayUnion([{
          'name': itemName,
          'price': price,
          'timestamp': Timestamp.now(),
          if (imageUrl != null) 'imageUrl': imageUrl,
        }])
      });
    } catch (e) {
      throw 'Failed to add food item: $e';
    }
  }

  Future<void> setFoodBills(String bookingId, List<Map<String, dynamic>> items) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'foodBills': items
      });
    } catch (e) {
      throw 'Failed to update food bills: $e';
    }
  }

  Future<void> startCleaning(String bookingId, {int hours = 2}) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'cleaning',
        'cleaningStartedAt': FieldValue.serverTimestamp(),
        'cleaningUntil': Timestamp.fromDate(DateTime.now().add(Duration(hours: hours))),
      });
    } catch (e) {
      throw 'Failed to start cleaning: $e';
    }
  }

  Future<void> setAvailable(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'checked-out', // This effectively makes it available in the active stream
      });
    } catch (e) {
      throw 'Failed to mark unit as available: $e';
    }
  }
}
