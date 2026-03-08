import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/receipt_service.dart';
import '../../core/format_utils.dart';

class BookingDetailDialog {
  static void show(BuildContext context, Map<String, dynamic> b) {
    const Color brandPurple = Color(0xFF673AB7);
    const Color brandGreen = Color(0xFF4CAF50);
    
    final dateFormat = DateFormat('dd/MM/yyyy, hh:mm a');
    final checkIn = (b['checkInAt'] as Timestamp?)?.toDate();
    final checkOut = (b['checkOutAt'] as Timestamp?)?.toDate();
    final reporting = (b['reportingDate'] as Timestamp?)?.toDate();
    
    final foodItems = (b['foodBills'] as List?) ?? [];
    final foodTotal = foodItems.fold(0.0, (sum, item) => sum + (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0));
    
    final advance = (b['advancePayment'] as num?)?.toDouble() ?? 0.0;
    final remainingRent = (b['remainingRent'] as num?)?.toDouble() ?? 0.0;
    final roomRent = (b['roomRent'] as num?)?.toDouble() ?? (advance + remainingRent);
    final gstAmount = (b['gstAmount'] as num?)?.toDouble() ?? 0.0;
    final gstPercent = (b['gstPercent'] as num?)?.toDouble() ?? 0.0;
    
    final totalStay = advance + remainingRent; 
    final grandTotal = roomRent + gstAmount + foodTotal;  // food included, GST only on rent
    final balance = (b['status'] == 'checked-out') ? 0.0 : (remainingRent + foodTotal);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b['customerName'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
            Builder(
              builder: (context) {
                final unitsList = b['unitNumbers'] as List? ?? (b['unitNumber'] != null ? [b['unitNumber']] : []);
                final unitsStr = unitsList.join(', ');
                return Text("Unit(s): $unitsStr - ${b['category']}", style: const TextStyle(fontSize: 14, color: Colors.black54));
              }
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SizedBox(
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
                  const Text("ID Proof - Front:", style: TextStyle(fontSize: 12, color: brandPurple, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
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
                        child: Text("Front ID Photo unavailable", style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                  ),
                ],
                if (b['idImageBackUrl'] != null && b['idImageBackUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 15),
                  const Text("ID Proof - Back:", style: TextStyle(fontSize: 12, color: brandPurple, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      b['idImageBackUrl'].toString(),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text("Back ID Photo unavailable", style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ),
                  ),
                ],
                if (b['guestPhotoUrl'] != null && b['guestPhotoUrl'].toString().isNotEmpty) ...[
                  const SizedBox(height: 15),
                  const Text("Guest Photo:", style: TextStyle(fontSize: 12, color: brandPurple, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      b['guestPhotoUrl'].toString(),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text("Guest Photo unavailable", style: TextStyle(color: Colors.red, fontSize: 12)),
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
                        Flexible(child: Text("- ${item['name']}", style: const TextStyle(fontSize: 13, overflow: TextOverflow.ellipsis))),
                        if (item['imageUrl'] != null)
                          IconButton(
                            icon: const Icon(Icons.image_outlined, size: 18, color: Color(0xFF673AB7)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Stack(
                                    children: [
                                      Image.network(item['imageUrl']),
                                      Positioned(
                                        top: 10, right: 10,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black54,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        Text("₹${item['price']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )).toList(),
                  const Divider(),
                ],
                if (b['packageName'] != null) ...[
                  Text("Package: ${b['packageName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: brandPurple)),
                  const SizedBox(height: 5),
                  if (b['packageInclusions'] != null)
                    ...((b['packageInclusions'] as List).map((inc) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: brandGreen),
                          const SizedBox(width: 8),
                          Expanded(child: Text(inc, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ))).toList(),
                  const Divider(),
                ],

                _detailRow(brandPurple, Icons.payments, "Advance Paid", "₹$advance"),
                _detailRow(brandPurple, Icons.apartment, "Base Room Rent", "₹$roomRent"),
                if (gstAmount > 0) _detailRow(brandPurple, Icons.percent, "GST ($gstPercent% on Rent only)", "₹$gstAmount"),
                _detailRow(brandPurple, Icons.pending_actions, "Remaining Rent", "₹$remainingRent"),
                if (foodTotal > 0) _detailRow(const Color(0xFF2196F3), Icons.restaurant, "Food & Services", "₹${foodTotal.toStringAsFixed(0)}"),
                const Divider(),
                _detailRow(brandPurple, Icons.receipt_long,
                  gstAmount > 0 ? "Grand Total (Rent+GST+Food)" : "Grand Total (Rent+Food)",
                  "₹${grandTotal.toStringAsFixed(0)}",
                  isBold: true,
                ),
                const SizedBox(height: 10),
                if (b['status'] != 'checked-out')
                  _detailRow(brandGreen, Icons.account_balance_wallet, "Due at Checkout", "₹${balance.toStringAsFixed(0)}", isBold: true),
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
                      color: (b['status'] ?? '').toString().contains('booked') ? Colors.orange 
                            : (b['status'] == 'cleaning') ? Colors.blueGrey : brandGreen,
                    ),
                  ),
                ),
                const Divider(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
        actions: [
          // DELETE button (admin action — permanent, requires confirmation)
          if (b['id'] != null)
            TextButton.icon(
              onPressed: () => _confirmAndDelete(context, b),
              icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18),
              label: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          const Spacer(),
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

  static Future<void> _confirmAndDelete(BuildContext context, Map<String, dynamic> b) async {
    final bookingId = b['id']?.toString();
    if (bookingId == null) return;

    final customerName = b['customerName'] ?? 'this booking';
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text("Permanent Delete", style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  children: [
                    const TextSpan(text: "You are about to permanently delete the booking for "),
                    TextSpan(text: customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ".\n\nThis action "),
                    const TextSpan(text: "CANNOT be undone", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    const TextSpan(text: ". Type "),
                    const TextSpan(text: "DELETE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.red)),
                    const TextSpan(text: " to confirm:"),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: "Type DELETE here",
                  filled: true,
                  fillColor: Colors.red.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: confirmController.text.trim() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text("CONFIRM DELETE"),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).delete();
      if (context.mounted) {
        Navigator.pop(context); // close the detail dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking for $customerName deleted permanently."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
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
