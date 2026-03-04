import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUpStaff({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
  }) async {
    FirebaseApp? tempApp;
    try {
      // Create a secondary Firebase app instance to avoid signing out the current admin
      tempApp = await Firebase.initializeApp(
        name: 'StaffCreationApp_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      // Create user in the secondary app
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store staff data in Firestore using the main app's instance
      // (The admin is still logged in here)
      if (userCredential.user != null) {
        // Main user record
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'role': 'staff',
        });

        // Legacy/Detailed record
        await _firestore.collection('staff').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during staff registration: $e';
    } finally {
      await tempApp?.delete();
    }
  }

  Future<UserCredential> signUpAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store admin data in Firestore
      if (userCredential.user != null) {
        // Main user record
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': email,
          'role': 'admin',
        });

        // Legacy/Detailed record
        await _firestore.collection('admins').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'name': name,
          'email': email,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during registration: $e';
    }
  }

  Future<UserCredential> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Optional: Check if the user exists in the 'admins' collection
      final adminDoc = await _firestore.collection('admins').doc(userCredential.user!.uid).get();
      if (!adminDoc.exists) {
        await _auth.signOut();
        throw 'Unauthorized: You are not registered as an admin.';
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during login: $e';
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // 1. Check if user is Admin
      final adminDoc = await _firestore.collection('admins').doc(uid).get();
      if (adminDoc.exists) {
        return {
          'user': userCredential.user,
          'role': 'admin',
          'data': adminDoc.data(),
        };
      }

      // 2. Check if user is Staff
      final staffDoc = await _firestore.collection('staff').doc(uid).get();
      if (staffDoc.exists) {
        return {
          'user': userCredential.user,
          'role': 'staff',
          'data': staffDoc.data(),
          'fullRole': staffDoc.data()?['role'] ?? 'Staff',
        };
      }

      // 3. Fallback
      await _auth.signOut();
      throw 'Unauthorized: Account not found in management records.';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during login: $e';
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      
      // Fallback to legacy check if users collection is empty
      final adminDoc = await _firestore.collection('admins').doc(uid).get();
      if (adminDoc.exists) return 'admin';
      
      final staffDoc = await _firestore.collection('staff').doc(uid).get();
      if (staffDoc.exists) return 'staff';

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<UserCredential> signInStaff({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if the user exists in the 'staff' collection
      final staffDoc = await _firestore.collection('staff').doc(userCredential.user!.uid).get();
      if (!staffDoc.exists) {
        await _auth.signOut();
        throw 'Unauthorized: You are not registered as staff.';
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during staff login: $e';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateAdminProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    try {
      await _firestore.collection('admins').doc(uid).update({
        'name': name,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  Future<void> updateStaffProfile({
    required String uid,
    required String name,
    required String phone,
    required String role,
    String? newEmail,
    String? newPassword,
  }) async {
    try {
      // Update Firestore data
      await _firestore.collection('staff').doc(uid).update({
        'name': name,
        'phone': phone,
        'role': role,
        if (newEmail != null) 'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Note: Changing Email/Password in Auth usually requires the user to be signed in.
      // For Admin-led changes, this typically requires a backend/Cloud Function.
    } catch (e) {
      throw 'Failed to update staff: $e';
    }
  }

  Future<void> deleteStaff(String uid) async {
    try {
      // Delete from Firestore
      await _firestore.collection('staff').doc(uid).delete();
      
      // Note: Auth deletion from client for another user is not directly possible without Admin SDK.
    } catch (e) {
      throw 'Failed to delete staff: $e';
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return e.message ?? 'An unknown authentication error occurred.';
    }
  }
}
