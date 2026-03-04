import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'format_utils.dart';

class ReportService {
  static Future<void> generateCustomerReport(List<Map<String, dynamic>> bookings) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    // Group bookings by customer and reporting date to handle multi-unit bookings better
    // Or just list them linearly if that's preferred. The user asked for "in front of name".
    // Let's sort them by date and customer name.
    bookings.sort((a, b) {
      final dateA = (a['reportingDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      final dateB = (b['reportingDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      return dateB.compareTo(dateA); // Newest first
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Landscape for more columns
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Shivam Resort - Customer Booking Report",
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Date
                1: const pw.FlexColumnWidth(3), // Check-In/Out
                2: const pw.FlexColumnWidth(3), // Name
                3: const pw.FlexColumnWidth(4), // Category/Unit
                4: const pw.FlexColumnWidth(1.5), // Total People
                5: const pw.FlexColumnWidth(1.5), // Capacity
                6: const pw.FlexColumnWidth(3), // Duration (Time)
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableHeader("Date"),
                    _tableHeader("Check-In/Out"),
                    _tableHeader("Customer Name"),
                    _tableHeader("Category & Units"),
                    _tableHeader("People"),
                    _tableHeader("Capacity"),
                    _tableHeader("Time Status"),
                  ],
                ),
                // Data Rows
                ...bookings.map((b) {
                  final reporting = (b['reportingDate'] as Timestamp?)?.toDate();
                  final checkIn = (b['checkInAt'] as Timestamp?)?.toDate() ?? reporting;
                  final checkOut = (b['checkOutAt'] as Timestamp?)?.toDate() ?? (b['checkOutDate'] as Timestamp?)?.toDate();
                  
                  final name = b['customerName'] ?? 'N/A';
                  final phone = b['phone'] ?? '';
                  final category = b['category'] ?? 'N/A';
                  final unit = b['unitNumber']?.toString() ?? 'N/A';
                  final people = b['totalPeople']?.toString() ?? '1';
                  final capacity = b['capacity'] ?? 'N/A';
                  final status = b['status'] ?? 'N/A';

                  return pw.TableRow(
                    children: [
                      _tableCell(reporting != null ? dateFormat.format(reporting) : "N/A"),
                      _tableCell("${checkIn != null ? dateFormat.format(checkIn) : "N/A"}\n-> ${checkOut != null ? dateFormat.format(checkOut) : "N/A"}"),
                      _tableCell("$name\n$phone"),
                      _tableCell("${FormatUtils.formatUnit(category, unit)}\n($status)"),
                      _tableCell(people, align: pw.TextAlign.center),
                      _tableCell(capacity, align: pw.TextAlign.center),
                      _tableCell("${checkIn != null ? timeFormat.format(checkIn) : "N/A"}\n-> ${checkOut != null ? timeFormat.format(checkOut) : "N/A"}"),
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
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  static pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9), textAlign: align),
    );
  }
}
