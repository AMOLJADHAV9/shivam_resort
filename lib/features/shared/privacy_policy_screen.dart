import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final Color brandPurple = const Color(0xFF673AB7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Privacy Policy", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Privacy Policy for Shivam Resorts",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 16),
            Text(
              "Last Updated: March 2026",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            SizedBox(height: 32),
            _SectionHeader("1. Information We Collect"),
            _SectionBody(
              "We collect personal information such as Guest Names, Phone Numbers, and Email Addresses when you create a booking or account in our system. This is required for managing reservations and providing resort services."
            ),
            _SectionHeader("2. How We Use Information"),
            _SectionBody(
              "The data we collect is used to:\n• Process and manage resort bookings.\n• Communicate booking updates and notifications.\n• Maintain staff accountability and resort security.\n• Improve our services through usage analysis."
            ),
            _SectionHeader("3. Data Storage (Firebase)"),
            _SectionBody(
              "Our application uses Google Firebase (Firestore and Authentication) to securely store your data. Firebase utilizes industry-standard encryption to protect your information both in transit and at rest."
            ),
            _SectionHeader("4. Third-Party Sharing"),
            _SectionBody(
              "We do not sell, trade, or otherwise transfer your personal information to third parties. Data is only accessible to authorized resort administration and staff members."
            ),
            _SectionHeader("5. Your Rights"),
            _SectionBody(
              "You have the right to request access to the data we hold about you or request its deletion. Please contact management for data-related inquiries."
            ),
            SizedBox(height: 40),
            Center(
              child: Text(
                "© 2026 Shivam Resorts. All rights reserved.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF673AB7)),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String body;
  const _SectionBody(this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        body,
        style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.6),
      ),
    );
  }
}
