import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'format_utils.dart';

class ReportService {
  // Modified to group same date + same customer bookings into single row
  static Future<void> generateCustomerReport(List<Map<String, dynamic>> bookings) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('hh:mm a');

    // Sort bookings by reporting date (newest first), then by customer name
    bookings.sort((a, b) {
      final dateA = (a['reportingDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      final dateB = (b['reportingDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      final dateCompare = dateB.compareTo(dateA);
      if (dateCompare != 0) return dateCompare;
      
      // If same date, sort by customer name
      final nameA = (a['customerName'] ?? '').toString().toLowerCase();
      final nameB = (b['customerName'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    // Group bookings by date and customer name
    final groupedMap = <String, List<Map<String, dynamic>>>{};
    for (var booking in bookings) {
      final reportingDate = (booking['reportingDate'] as Timestamp?)?.toDate();
      if (reportingDate == null) continue;
      
      final dateKey = DateFormat('yyyy-MM-dd').format(reportingDate);
      final customerName = (booking['customerName'] ?? 'Unknown').toString();
      final groupKey = '$dateKey|$customerName';
      
      if (!groupedMap.containsKey(groupKey)) {
        groupedMap[groupKey] = [];
      }
      groupedMap[groupKey]!.add(booking);
    }

    // Convert map to sorted list
    final groupedBookings = groupedMap.entries.toList();
    groupedBookings.sort((a, b) {
      final [dateA, nameA] = a.key.split('|');
      final [dateB, nameB] = b.key.split('|');
      
      final dateCompare = dateB.compareTo(dateA); // Newest first
      if (dateCompare != 0) return dateCompare;
      
      return nameA.compareTo(nameB);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // Changed to portrait
        margin: const pw.EdgeInsets.all(16), // Smaller margins
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Shivam Resort - Customer Booking Report",
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.8), // Date
                1: const pw.FlexColumnWidth(2.5), // Check-In/Out
                2: const pw.FlexColumnWidth(2.5), // Name
                3: const pw.FlexColumnWidth(4.5), // Category/Units (wider for multiple units)
                4: const pw.FlexColumnWidth(1.2), // Total People
                5: const pw.FlexColumnWidth(1.8), // Duration (Time)
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableHeader("Date"),
                    _tableHeader("Check-In / Out"),
                    _tableHeader("Customer Name"),
                    _tableHeader("Category & Units"),
                    _tableHeader("People"),
                    _tableHeader("Time"),
                  ],
                ),
                // Data Rows - Grouped by date and customer
                ...groupedBookings.map((entry) {
                  final groupBookings = entry.value;
                  if (groupBookings.isEmpty) return pw.TableRow(children: []);
                  
                  // Get common date and customer name from first booking
                  final firstBooking = groupBookings.first;
                  final reportingDate = (firstBooking['reportingDate'] as Timestamp?)?.toDate();
                  final customerName = firstBooking['customerName'] ?? 'Unknown';
                  final phone = firstBooking['phone'] ?? '';
                  
                  // Build units list (all units booked by this customer on this date)
                  final unitLines = <String>[];
                  int totalPeople = 0;
                  DateTime? earliestCheckIn;
                  DateTime? latestCheckOut;
                  
                  for (var b in groupBookings) {
                    final category = b['category'] ?? '';
                    final unitNumber = b['unitNumber']?.toString() ?? '';
                    final capacity = b['capacity'] ?? '';
                    final people = b['totalPeople'] as int? ?? 1;
                    totalPeople += people;
                    
                    // Format: "Category - UnitNumber (Capacity)"
                    var unitText = FormatUtils.formatUnit(category, unitNumber);
                    if (capacity.isNotEmpty && capacity != '0') {
                      unitText += ' ($capacity)';
                    }
                    unitLines.add(unitText);
                    
                    // Track earliest check-in and latest check-out
                    final checkIn = (b['checkInAt'] as Timestamp?)?.toDate() ?? reportingDate;
                    final checkOut = (b['checkOutAt'] as Timestamp?)?.toDate() ?? (b['checkOutDate'] as Timestamp?)?.toDate();
                    
                    if (earliestCheckIn == null || (checkIn != null && checkIn.isBefore(earliestCheckIn))) {
                      earliestCheckIn = checkIn;
                    }
                    if (latestCheckOut == null || (checkOut != null && checkOut.isAfter(latestCheckOut))) {
                      latestCheckOut = checkOut;
                    }
                  }
                  
                  return pw.TableRow(
                    children: [
                      _tableCell(reportingDate != null ? dateFormat.format(reportingDate) : "N/A"),
                      _tableCell("${earliestCheckIn != null ? dateFormat.format(earliestCheckIn) : "N/A"}\n to ${latestCheckOut != null ? dateFormat.format(latestCheckOut) : "N/A"}"),
                      _tableCell("$customerName\n$phone"),
                      _multiLineCell(unitLines), // Show all units
                      _tableCell(totalPeople.toString(), align: pw.TextAlign.center),
                      _tableCell("${earliestCheckIn != null ? timeFormat.format(earliestCheckIn) : "N/A"}\n to ${latestCheckOut != null ? timeFormat.format(latestCheckOut) : "N/A"}"),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(text, 
        style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _centeredHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: pw.Text(
        text, 
        style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5), textAlign: align),
    );
  }

  static pw.Widget _multiLineCell(List<String> lines) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines
            .map((line) => pw.Text(line, style: const pw.TextStyle(fontSize: 7.5)))
            .toList(),
      ),
    );
  }
}
