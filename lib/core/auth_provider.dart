import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_repository.dart';
import 'booking_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final adminProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  
  return FirebaseFirestore.instance
      .collection('admins')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

final staffProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  
  return FirebaseFirestore.instance
      .collection('staff')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

final staffListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('staff')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

final activeBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(bookingRepositoryProvider).watchActiveBookings();
});

final allBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(bookingRepositoryProvider).watchAllBookings();
});

// Family provider: streams all active bookings for a single unit (for calendar)
class UnitKey {
  final String category;
  final String capacity;
  final dynamic unitNumber;
  const UnitKey(this.category, this.capacity, this.unitNumber);
  @override bool operator ==(Object o) => o is UnitKey && o.category == category && o.capacity == capacity && o.unitNumber == unitNumber;
  @override int get hashCode => Object.hash(category, capacity, unitNumber);
}

final unitBookingsProvider = StreamProvider.family<List<Map<String, dynamic>>, UnitKey>((ref, key) {
  return ref.watch(bookingRepositoryProvider).watchUnitBookings(
    category: key.category,
    capacity: key.capacity,
    unitNumber: key.unitNumber,
  );
});
