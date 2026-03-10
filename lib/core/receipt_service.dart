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
  static const String resortAddress =
      "Shirol Janapur, road, Kaulkhed, Udgir, Maharashtra 413517";
  static const String resortContact = "+91 9022617734";
  static const String resortEmail = "shivamresort8000@gmail.com";
  static const String resortGST = "27BCIPP1218G1ZP";

  static Future<void> generateAndPrintReceipt(
    Map<String, dynamic> booking, {
    bool withGST = false,
  }) async {
    final pdf = pw.Document();

    final customerName = booking['customerName'] ?? 'Guest';
    final phone = booking['phone'] ?? 'N/A';
    final idProof = booking['idProof'] ?? 'N/A';
    final unitNumber = booking['unitNumber']?.toString() ?? 'N/A';
    final category = booking['category'] ?? 'N/A';
    
    // Receipt Number logic: Use the new structured ID if present, else fallback
    final rawBookingId = booking['id']?.toString() ?? booking['bookingId']?.toString() ?? 'N/A';
    final customReceiptNumber = booking['receiptNumber']?.toString();
    final displayReceiptNumber = customReceiptNumber ?? 
        'RE-${rawBookingId.length > 6 ? rawBookingId.substring(rawBookingId.length - 6).toUpperCase() : rawBookingId.toUpperCase()}';

    // Dates — pick the best available timestamps
    final reportingDate = (booking['reportingDate'] as Timestamp?)?.toDate();
    final rawCheckInAt = (booking['checkInAt'] as Timestamp?)?.toDate();
    final rawCheckOutAt = (booking['checkOutAt'] as Timestamp?)?.toDate();

    // Determine actual check-in: prefer checkInAt, fallback to reportingDate
    DateTime? resolvedCheckIn = rawCheckInAt ?? reportingDate;
    // Determine actual check-out: prefer checkOutAt, fallback to now
    DateTime resolvedCheckOut = rawCheckOutAt ?? DateTime.now();

    // Guard: if check-in is after check-out (data entry mistake), swap them
    if (resolvedCheckIn != null && resolvedCheckIn.isAfter(resolvedCheckOut)) {
      final tmp = resolvedCheckIn;
      resolvedCheckIn = resolvedCheckOut;
      resolvedCheckOut = tmp;
    }

    final checkInAt = resolvedCheckIn;
    final checkOutAt = resolvedCheckOut;

    final dateFormat = DateFormat('dd/MM/yyyy, hh:mm a');

    // Stay Duration Calculation
    final chargingMode = booking['chargingMode'] ?? '24h';
    int stayDays = 1;
    if (checkInAt != null) {
      if (chargingMode == 'flexible') {
        stayDays = DateTime(checkOutAt.year, checkOutAt.month, checkOutAt.day)
            .difference(
              DateTime(checkInAt.year, checkInAt.month, checkInAt.day),
            )
            .inDays;
      } else {
        final diffMinutes = checkOutAt.difference(checkInAt).inMinutes;
        stayDays = (diffMinutes / 1320.0).ceil();
      }
      if (stayDays < 1) stayDays = 1;
    }

    // Food Bills
    final foodItems = (booking['foodBills'] as List?) ?? [];
    double foodTotal = 0.0;
    for (var item in foodItems) {
      foodTotal += (item['price'] as num?)?.toDouble() ?? 0.0;
    }

    final isCheckedOut =
        booking['status'] == 'checked-out' || booking['status'] == 'cleaning';
    final isConfirmed = booking['status'] == 'occupied' || isCheckedOut;

    // Payments
    final advance = (booking['advancePayment'] as num?)?.toDouble() ?? 0.0;
    final remainingRent = (booking['remainingRent'] as num?)?.toDouble() ?? 0.0;
    final advanceMethod = booking['paymentMethod'] ?? 'CASH';
    final checkoutMode = booking['paymentMode'] ?? (isCheckedOut ? (booking['paymentMethod'] ?? 'CASH') : 'N/A');
    final bookingItems = (booking['bookingItems'] as List?) ?? [];

    // Calculate room rent total from items if available
    double calculatedRoomRent = 0.0;
    double calculatedOtherServices = 0.0;
    double calculatedGst = 0.0;
    double calculatedDiscount = 0.0;
    if (bookingItems.isNotEmpty) {
      for (var item in bookingItems) {
        if (item['category'] == 'Other Service' || item['category'] == 'Extra Bed') {
          calculatedOtherServices += (item['package'] as num?)?.toDouble() ?? 0.0;
          calculatedGst += (item['gst'] as num?)?.toDouble() ?? 0.0;
        } else {
          calculatedRoomRent += (item['package'] as num?)?.toDouble() ?? 0.0;
          calculatedGst += (item['gst'] as num?)?.toDouble() ?? 0.0;
          calculatedDiscount += (item['discount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    final roomRent = bookingItems.isNotEmpty
        ? calculatedRoomRent
        : ((booking['roomRent'] as num?)?.toDouble() ??
              (advance + remainingRent));
    final otherServicesTotal = calculatedOtherServices;
    final gstAmount = bookingItems.isNotEmpty
        ? calculatedGst
        : ((booking['gstAmount'] as num?)?.toDouble() ?? 0.0);
    final discountAmount = bookingItems.isNotEmpty
        ? calculatedDiscount
        : ((booking['discountAmount'] as num?)?.toDouble() ?? 0.0);
    final gstPercent = (booking['gstPercent'] as num?)?.toDouble() ?? 0.0;

    final baseTotal = roomRent;
    final grandTotal =
        (booking['grandTotal'] as num?)?.toDouble() ??
        (baseTotal - discountAmount + gstAmount + foodTotal);
    final balancePaidAtCheckout = grandTotal - advance;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Business Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        resortName,
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.deepPurple900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        resortAddress,
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        "Contact: $resortContact | Email: $resortEmail",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      if (withGST)
                        pw.Text(
                          "GSTIN: $resortGST",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.deepPurple,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          "INVOICE",
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        "Receipt #: $displayReceiptNumber",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 20),

              // 2. Guest & Stay Information Grid
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Guest Details
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "GUEST INFORMATION",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          customerName,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          "Phone: $phone",
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        if (booking['idProof'] != null)
                          pw.Text(
                            "ID Proof: ${booking['idProof']}",
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        if (booking['customerGst'] != null &&
                            booking['customerGst'].toString().isNotEmpty)
                          pw.Text(
                            "GST: ${booking['customerGst']}",
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Stay Details
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "STAY INFORMATION",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        if (bookingItems.isEmpty)
                          pw.Text(
                            "${FormatUtils.formatUnit(category, booking['unitNumber'])} ($category)",
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          )
                        else
                          pw.Text(
                            "Multi-Category Booking",
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),

                        pw.Text(
                          "Check-In: ${checkInAt != null ? dateFormat.format(checkInAt) : 'N/A'}",
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          "Check-Out: ${dateFormat.format(checkOutAt)}",
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          "Duration: $stayDays Day(s)",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // 3. Itemized Billing Table
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: PdfColors.grey200,
                    width: 0.5,
                  ),
                  bottom: pw.BorderSide(color: PdfColors.grey900, width: 1),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      _pCell("Category / Item", isHeader: true),
                      _pCell(
                        "Unit No.",
                        isHeader: true,
                        align: pw.TextAlign.center,
                      ),
                      _pCell("GST", isHeader: true, align: pw.TextAlign.right),
                      _pCell("Disc", isHeader: true, align: pw.TextAlign.right),
                      _pCell(
                        "Package",
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),

                  // Multi Booking Items
                  if (bookingItems.isNotEmpty)
                    ...bookingItems.map((item) {
                      final isOther =
                          item['category'] == 'Other Service' ||
                          item['category'] == 'Extra Bed';
                      final categoryDisplay = isOther
                          ? item['units'].join(", ")
                          : "${item['category']} (${item['capacity']})";
                      final unitsDisplay = isOther
                          ? "1"
                          : (item['units'] as List).join(", ");

                      return pw.TableRow(
                        children: [
                          _pCell(categoryDisplay),
                          _pCell(unitsDisplay, align: pw.TextAlign.center),
                          _pCell("₹${item['gst']}", align: pw.TextAlign.right),
                          _pCell(
                            "₹${item['discount'] ?? 0}",
                            align: pw.TextAlign.right,
                          ),
                          _pCell(
                            "₹${item['package']}",
                            align: pw.TextAlign.right,
                          ),
                        ],
                      );
                    }).toList()
                  else ...[
                    // Legacy single booking
                    pw.TableRow(
                      children: [
                        _pCell("$category ($unitNumber)"),
                        _pCell("1", align: pw.TextAlign.center),
                        _pCell(
                          gstAmount.toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                        _pCell(
                          discountAmount.toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                        _pCell(
                          roomRent.toStringAsFixed(2),
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                  ],

                  // Package Injection (One Day Stay)
                  if (booking['packageName'] != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                "PACKAGE: ${booking['packageName']}",
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              if (booking['packageInclusions'] != null)
                                ...((booking['packageInclusions'] as List).map(
                                  (inc) => pw.Text(
                                    "- $inc",
                                    style: const pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                )),
                            ],
                          ),
                        ),
                        _pCell("-", align: pw.TextAlign.center),
                        _pCell("-", align: pw.TextAlign.right),
                        _pCell("Included", align: pw.TextAlign.right),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 20),

              // 4. Summary & Food Section
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Food Expenses section
                  pw.Expanded(
                    flex: 1,
                    child: foodTotal > 0
                        ? pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                "FOODING & OTHER SERVICES",
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blueGrey,
                                ),
                              ),
                              pw.Text(
                                "(No GST on food charges)",
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontStyle: pw.FontStyle.italic,
                                  color: PdfColors.grey600,
                                ),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Table(
                                border: const pw.TableBorder(
                                  bottom: pw.BorderSide(
                                    color: PdfColors.grey300,
                                    width: 0.5,
                                  ),
                                ),
                                children: foodItems
                                    .map(
                                      (item) => pw.TableRow(
                                        children: [
                                          pw.Text(
                                            "- ${item['name']}",
                                            style: const pw.TextStyle(
                                              fontSize: 9,
                                            ),
                                          ),
                                          pw.Text(
                                            "INR ${((item['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}",
                                            style: const pw.TextStyle(
                                              fontSize: 9,
                                            ),
                                            textAlign: pw.TextAlign.right,
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                              pw.SizedBox(height: 5),
                              pw.Text(
                                "Food Total: INR ${foodTotal.toStringAsFixed(2)}",
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blueGrey700,
                                ),
                              ),
                            ],
                          )
                        : pw.SizedBox(),
                  ),
                  pw.SizedBox(width: 40),
                  // Financial Summary
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow("TOTAL PACKAGE", roomRent),
                        if (discountAmount > 0)
                          _buildSummaryRow(
                            "Discount",
                            "-Rs ${discountAmount.toStringAsFixed(2)}",
                            customColor: PdfColors.red,
                          ),
                        if (gstAmount > 0)
                          _buildSummaryRow("Total GST", gstAmount),
                        _buildSummaryRow(
                          "ADVANCE PAYMENT (${advanceMethod.toUpperCase()})",
                          advance,
                        ),
                        if (isCheckedOut)
                          _buildSummaryRow(
                            "REMAINING PAYMENT (${checkoutMode.toUpperCase()})",
                            remainingRent,
                          ),
                        if (!isCheckedOut)
                          _buildSummaryRow("BALANCE REMAINING", remainingRent),
                        if (foodTotal > 0)
                          _buildSummaryRow("FOOD EXPENSE", foodTotal),
                        if (otherServicesTotal > 0)
                          _buildSummaryRow("OTHER SERVICES", otherServicesTotal),
                        pw.Divider(color: PdfColors.grey300),
                        _buildSummaryRow(
                          "GRAND TOTAL",
                          grandTotal,
                          isBold: true,
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: isConfirmed
                                ? PdfColors.green50
                                : PdfColors.orange50,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              isConfirmed
                                  ? "PAYMENT STATUS: PAID"
                                  : "PAYMENT STATUS: DUE",
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: isConfirmed
                                    ? PdfColors.green900
                                    : PdfColors.orange900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // 5. Footer & Terms
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Terms & Conditions:",
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "1. This is a computer-generated invoice.",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        "2. Goods once sold/services rendered are not refundable.",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                      pw.SizedBox(height: 15),
                      pw.Text(
                        "Customer Signature: ____________________",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Authorized Signatory",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Text(
                        "for $resortName",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  "--- Thank you for staying with us! ---",
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.deepPurple,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _pCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    dynamic value, {
    bool isBold = false,
    PdfColor? customColor,
  }) {
    String valStr = value is double
        ? "INR ${value.toStringAsFixed(2)}"
        : value.toString();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: customColor,
            ),
          ),
          pw.Text(
            valStr,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: customColor,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showPrintOptions(
    BuildContext context,
    Map<String, dynamic> booking,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Print Receipt",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            child: const Text("STANDARD"),
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
            child: const Text("GST INVOICE"),
          ),
        ],
      ),
    );
  }
}
