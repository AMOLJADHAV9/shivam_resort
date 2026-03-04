import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  final Color brandPurple = const Color(0xFF673AB7);
  final Color brandPink = const Color(0xFFE91E63);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: brandPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactCard(),
            const SizedBox(height: 32),
            const Text(
              "Frequently Asked Questions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildFAQTile("How do I cancel a booking?", "Go to the Bookings tab, select the booking, and tap the 'Cancel' button. Note that overdue pre-bookings can be 'Auto-Cancelled'."),
            _buildFAQTile("Can I change my profile info?", "Yes, go to Settings > Staff Profile (or Profile Settings for Admin) to update your name and phone number."),
            _buildFAQTile("What are the lodging categories?", "We have Lodging Deluxe (LD), Dormitory (D), Banquet (B), Lawn (L), Function Hall (F), Meeting Hall (M), and Sapapadi (S)."),
            _buildFAQTile("How do I add new staff?", "Admins can add staff members through the 'Staff' tab in the navigation bar."),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [brandPurple, brandPink]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.support_agent, size: 60, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            "Contact Shivam Resorts Support",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildContactRow(Icons.email, "support@shivamresorts.com"),
          const SizedBox(height: 12),
          _buildContactRow(Icons.phone, "+91 98765 43210"),
          const SizedBox(height: 12),
          _buildContactRow(Icons.location_on, "Shivam Resorts, Near Main Road, City"),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text, 
            style: const TextStyle(color: Colors.white, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(answer, style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
