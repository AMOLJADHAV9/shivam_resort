import 'package:flutter/material.dart';
import '../features/splash/splash_screen.dart';
import '../main.dart';
import 'app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: messengerKey,
      home: const SplashScreen(),
    );
  }
}