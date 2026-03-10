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
import 'package:window_manager/window_manager.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

final messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    // Initialize window manager for desktop
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "Shivam Resorts Management",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
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

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    // Listen to Firebase auth state changes directly
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          debugPrint('AuthWrapper: Auth state changed - ${user != null ? 'User logged in: ${user.uid}' : 'User logged out'}');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading state - initial load
    if (_currentUser == null && FirebaseAuth.instance.currentUser == null) {
      // Check if we're still initializing
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('AuthWrapper: No current user, showing login');
        return const LoginScreen();
      }
      _currentUser = firebaseUser;
    }
    
    // 2. User exists -> Check Role and redirect
    if (_currentUser != null) {
      debugPrint('AuthWrapper: User logged in with UID: ${_currentUser!.uid}');
      return RoleChecker(uid: _currentUser!.uid);
    }
    
    // 3. No User -> Show Login screen
    debugPrint('AuthWrapper: No user logged in, showing login screen');
    return const LoginScreen();
  }
}

class RoleChecker extends ConsumerWidget {
  final String uid;
  const RoleChecker({required this.uid, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('RoleChecker: Checking role for UID: $uid');
    
    return FutureBuilder<String?>(
      future: ref.read(authRepositoryProvider).getUserRole(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('RoleChecker: Still checking role...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          debugPrint('RoleChecker: Error or no role found. Error: ${snapshot.error}');
          // Log out if role is invalid/not found to avoid stuck state
          FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        final role = snapshot.data;
        debugPrint('RoleChecker: Role found - "$role"');
        
        if (role == 'admin') {
          debugPrint('RoleChecker: Redirecting to Admin Dashboard');
          return const AdminMainWrapper();
        } else if (role == 'staff') {
          debugPrint('RoleChecker: Redirecting to Staff Dashboard');
          return const StaffDashboard();
        }

        // Default fallback
        debugPrint('RoleChecker: Unknown role, signing out');
        FirebaseAuth.instance.signOut();
        return const LoginScreen();
      },
    );
  }
}