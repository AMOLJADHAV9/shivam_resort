import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'format_utils.dart';
import '../main.dart';

class ReceiptService {
  static const String resortName = "Shivam Resorts";
  static const String resortAddress = "123 Resort Lane, Eco Valley, Green City";
  static const String resortContact = "+91 98765 43210";
  static const String resortEmail = "contact@shivamresorts.com";
  static const String resortGST = "27BClPP1218GIZP";

  static Future<void> generateAndPrintReceipt(Map<String, dynamic> booking, {bool withGST = false}) async {
    final pdf = pw.Document();

    final customerName = booking['customerName'] ?? 'Guest';
    final phone = booking['phone'] ?? 'N/A';
    final idProof = booking['idProof'] ?? 'N/A';
    final unitNumber = booking['unitNumber']?.toString() ?? 'N/A';
    final category = booking['category'] ?? 'N/A';
    final bookingId = booking['id']?.toString() ?? booking['bookingId']?.toString() ?? 'N/A';
    
    // Dates
    final reportingDate = (booking['reportingDate'] as Timestamp?)?.toDate();
    final checkInAt = (booking['checkInAt'] as Timestamp?)?.toDate();
    final checkOutAt = (booking['checkOutAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    
    // Stay Duration Calculation
    final chargingMode = booking['chargingMode'] ?? '24h';
    int stayDays = 1;
    if (checkInAt != null) {
      if (chargingMode == 'flexible') {
        // Calendar Day Difference
        stayDays = DateTime(checkOutAt.year, checkOutAt.month, checkOutAt.day)
            .difference(DateTime(checkInAt.year, checkInAt.month, checkInAt.day))
            .inDays;
      } else {
        // 22-Hour Strict (e.g., 22h 1m = 2 days)
        final diffMinutes = checkOutAt.difference(checkInAt).inMinutes;
        stayDays = (diffMinutes / 1320.0).ceil();
      }
      if (stayDays == 0) stayDays = 1; // Minimum 1 day charge
    }

    // Food Bills
    final foodItems = (booking['foodBills'] as List?) ?? [];
    double foodTotal = 0.0;
    for (var item in foodItems) {
      foodTotal += (item['price'] as num?)?.toDouble() ?? 0.0;
    }

    // Payments
    final advance = (booking['advancePayment'] as num?)?.toDouble() ?? 0.0;
    final stayTotal = (booking['totalPayment'] as num?)?.toDouble() ?? 0.0;
    final totalBill = stayTotal + foodTotal;
    final balance = totalBill - advance;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(resortName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                        pw.SizedBox(height: 5),
                        pw.Text(resortAddress),
                        pw.Text("Contact: $resortContact | Email: $resortEmail"),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("RECEIPT", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}"),
                        if (withGST) pw.Text("GST: $resortGST", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),

                // Customer Details Table
                pw.Text("Customer Details", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow("Customer Name", customerName),
                    _buildTableRow("Contact Number", phone),
                    _buildTableRow("ID Proof", idProof),
                    _buildTableRow("Stay Duration", "$stayDays Day(s)"),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Stay Details Table
                pw.Text("Stay & Unit Details", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _buildTableRow("Unit Number", FormatUtils.formatUnit(category, booking['unitNumber'])),
                    _buildTableRow("Category", category),
                    _buildTableRow("Check-In Date", checkInAt != null ? dateFormat.format(checkInAt) : "N/A"),
                    _buildTableRow("Check-Out Date", dateFormat.format(checkOutAt)),
                  ],
                ),

                // Food Charges Table (if any)
                if (foodItems.isNotEmpty) ...[
                  pw.SizedBox(height: 20),
                  pw.Text("Food & Extra Charges", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColors.grey100),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Item Name", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Price (INR)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        ],
                      ),
                      ...foodItems.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item['name'] ?? 'Item')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("${(item['price'] as num?)?.toDouble() ?? 0.0}", textAlign: pw.TextAlign.right)),
                        ],
                      )).toList(),
                    ],
                  ),
                ],

                pw.SizedBox(height: 30),

                // Payment Summary Section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 250,
                      child: pw.Column(
                        children: [
                          if (stayTotal > 0) _buildAmountRow("Stay Charges", stayTotal),
                          if (foodTotal > 0) _buildAmountRow("Food Charges", foodTotal),
                          pw.Divider(),
                          _buildAmountRow("Total Bill Amount", totalBill, isBold: true),
                          _buildAmountRow("Paid at Booking", advance),
                          pw.Divider(),
                          _buildAmountRow("Balance Paid", balance, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.Spacer(),
                
                // Footer Section
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Signature: ____________________", style: pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 10),
                        pw.Text("Thank you for staying with us!", style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
                        pw.SizedBox(height: 5),
                        pw.Text("This is a computer-generated receipt.", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                      ],
                    ),
                    pw.Text("Booking ID: $bookingId", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<void> showPrintOptions(BuildContext context, Map<String, dynamic> booking) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Print Receipt", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Select the receipt format you wish to generate."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF673AB7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              generateAndPrintReceipt(booking, withGST: false);
            },
            child: const Text("WITHOUT GST"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              generateAndPrintReceipt(booking, withGST: true);
            },
            child: const Text("WITH GST"),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value),
        ),
      ],
    );
  }

  static pw.Widget _buildAmountRow(String label, double amount, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text("INR ${amount.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
