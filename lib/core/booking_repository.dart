import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of active bookings to track unit statuses
  Stream<List<Map<String, dynamic>>> watchActiveBookings() {
    return _firestore
        .collection('bookings')
        .where('status', whereIn: ['pre-booked', 'occupied'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
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
        .where('status', whereIn: ['pre-booked', 'occupied'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> saveBooking({
    required String customerName,
    required String phone,
    required String idProof,
    required String category,
    required String capacity,
    required dynamic unitNumber,
    required DateTime reportingDate,
    required DateTime checkOutDate,
    required double advancePayment,
    required String status, // 'pre-booked' or 'occupied'
    String chargingMode = '24h',
    int totalPeople = 1,
    String? idImageUrl,
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
        'status': status,
        'chargingMode': chargingMode,
        'totalPeople': totalPeople,
        'wasPrebooked': status == 'pre-booked',
        'createdAt': FieldValue.serverTimestamp(),
        'idImageUrl': idImageUrl,
        if (status == 'occupied') 'checkInAt': reportingTs,
        if (status == 'occupied') 'totalPayment': advancePayment,
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

  Future<void> confirmCheckIn(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'occupied',
        'checkInAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to confirm check-in: $e';
    }
  }

  Future<void> checkOut({
    required String bookingId,
    required double totalPayment,
    required String paymentMode, // 'Cash', 'Online', etc.
  }) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'checked-out',
        'totalPayment': totalPayment,
        'paymentMode': paymentMode,
        'checkOutAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to check-out: $e';
    }
  }

  Future<void> addFoodItem(String bookingId, String itemName, double price) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'foodBills': FieldValue.arrayUnion([{
          'name': itemName,
          'price': price,
          'timestamp': Timestamp.now(),
        }])
      });
    } catch (e) {
      throw 'Failed to add food item: $e';
    }
  }
}
