import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/receipt_service.dart';
import '../../core/format_utils.dart';

class BookingDetailDialog {
  static void show(BuildContext context, Map<String, dynamic> b) {
    const Color brandPurple = Color(0xFF673AB7);
    const Color brandGreen = Color(0xFF4CAF50);
    
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final checkIn = (b['checkInAt'] as Timestamp?)?.toDate();
    final checkOut = (b['checkOutAt'] as Timestamp?)?.toDate();
    final reporting = (b['reportingDate'] as Timestamp?)?.toDate();
    
    final foodItems = (b['foodBills'] as List?) ?? [];
    final foodTotal = foodItems.fold(0.0, (sum, item) => sum + (item['price'] ?? 0).toDouble());
    
    final advance = (b['advancePayment'] as num?)?.toDouble() ?? 0.0;
    final totalStay = (b['totalPayment'] as num?)?.toDouble() ?? 0.0;
    final totalBill = totalStay + foodTotal;
    final balance = totalBill - advance;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b['customerName'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("${FormatUtils.formatUnit(b['category'], b['unitNumber'])} - ${b['category']}", style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(brandPurple, Icons.phone, "Phone", b['phone'] ?? 'N/A'),
                _detailRow(brandPurple, Icons.badge, "ID Proof", b['idProof'] ?? 'N/A'),
                if (b['idImageUrl'] != null && b['idImageUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      b['idImageUrl'].toString(),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text("ID Photo unavailable", style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                  ),
                ],
                const Divider(),
                _detailRow(brandPurple, Icons.event, "Reporting", reporting != null ? dateFormat.format(reporting) : "N/A"),
                _detailRow(brandPurple, Icons.login, "Check-In", checkIn != null ? dateFormat.format(checkIn) : "Not yet"),
                _detailRow(brandPurple, Icons.logout, "Check-Out", checkOut != null ? dateFormat.format(checkOut) : (b['status'] == 'occupied' ? "Active" : "N/A")),
                const Divider(),
                if (foodItems.isNotEmpty) ...[
                  const Text("Food & Extra Charges", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: brandPurple)),
                  const SizedBox(height: 5),
                  ...foodItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['name'] ?? 'Item', style: const TextStyle(fontSize: 13)),
                        Text("₹${item['price']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                  const Divider(),
                ],
                _detailRow(brandPurple, Icons.payments, "Paid at Booking", "₹$advance"),
                if (totalBill > 0) ...[
                  if (totalStay > 0) _detailRow(brandPurple, Icons.hotel, "Stay Charges", "₹$totalStay"),
                  if (foodTotal > 0) _detailRow(brandPurple, Icons.restaurant, "Food Charges", "₹$foodTotal"),
                  _detailRow(brandPurple, Icons.receipt_long, "Total Bill", "₹$totalBill"),
                  _detailRow(brandPurple, Icons.account_balance_wallet, "Final Balance", "₹${balance.toStringAsFixed(0)}", isBold: true),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (b['status'] ?? '').toString().contains('booked') ? Colors.orange.withOpacity(0.1) : brandGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Status: ${(b['status'] ?? 'UNKNOWN').toString().toUpperCase()}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (b['status'] ?? '').toString().contains('booked') ? Colors.orange : brandGreen,
                    ),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
          if (b['status'] == 'checked-out')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ReceiptService.showPrintOptions(context, b);
              },
              style: ElevatedButton.styleFrom(backgroundColor: brandPurple, foregroundColor: Colors.white),
              child: const Text("REPRINT RECEIPT"),
            ),
        ],
      ),
    );
  }

  static Widget _detailRow(Color brandPurple, IconData icon, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: brandPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value, style: TextStyle(
                  fontSize: 14, 
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isBold ? brandPurple : Colors.black,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
