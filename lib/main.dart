import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/auth_provider.dart';
import 'core/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/admin/admin_main_wrapper.dart';
import 'screens/staff/staff_dashboard.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shivam Resorts',
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: messengerKey,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Connection Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. User exists -> Check Role
        if (snapshot.hasData && snapshot.data != null) {
          return RoleChecker(uid: snapshot.data!.uid);
        }

        // 3. No User -> Show Login
        return const LoginScreen();
      },
    );
  }
}

class RoleChecker extends ConsumerWidget {
  final String uid;
  const RoleChecker({required this.uid, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(authRepositoryProvider).getUserRole(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // Log out if role is invalid/not found to avoid stuck state
          FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        final role = snapshot.data;
        if (role == 'admin') {
          return const AdminMainWrapper();
        } else if (role == 'staff') {
          return const StaffDashboard();
        }

        // Default fallback
        FirebaseAuth.instance.signOut();
        return const LoginScreen();
      },
    );
  }
}