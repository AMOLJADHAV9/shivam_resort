import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/format_utils.dart';
import '../../core/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point: call this to open the calendar for any unit
// ─────────────────────────────────────────────────────────────────────────────
void showUnitCalendar(
  BuildContext context, {
  required String category,
  required String capacity,
  required dynamic unitNumber,
  /// If the unit is currently booked, pass the active booking map
  Map<String, dynamic>? currentBooking,
  /// Callback to open the new-booking form with pre-filled dates
  required void Function(DateTime checkIn, DateTime checkOut) onBookDates,
  /// Callback to confirm check-in from pre-booked
  required void Function(Map<String, dynamic> booking) onCheckIn,
  /// Callback to start check-out flow
  required void Function(Map<String, dynamic> booking) onCheckOut,
  /// Callback to cancel booking
  required void Function(Map<String, dynamic> booking, {String? reason}) onCancel,
  String chargingMode = '24h',
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UnitCalendarSheet(
      category: category,
      capacity: capacity,
      unitNumber: unitNumber,
      currentBooking: currentBooking,
      onBookDates: onBookDates,
      onCheckIn: onCheckIn,
      onCheckOut: onCheckOut,
      onCancel: onCancel,
      chargingMode: chargingMode,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────
class UnitCalendarSheet extends ConsumerStatefulWidget {
  final String category;
  final String capacity;
  final dynamic unitNumber;
  final Map<String, dynamic>? currentBooking;
  final void Function(DateTime, DateTime) onBookDates;
  final void Function(Map<String, dynamic>) onCheckIn;
  final void Function(Map<String, dynamic>) onCheckOut;
  final void Function(Map<String, dynamic>, {String? reason}) onCancel;
  final String chargingMode;

  const UnitCalendarSheet({
    super.key,
    required this.category,
    required this.capacity,
    required this.unitNumber,
    this.currentBooking,
    required this.onBookDates,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onCancel,
    this.chargingMode = '24h',
  });

  @override
  ConsumerState<UnitCalendarSheet> createState() => _UnitCalendarSheetState();
}

class _UnitCalendarSheetState extends ConsumerState<UnitCalendarSheet> {
  static const Color _brandPurple = Color(0xFF673AB7);
  static const Color _brandPink = Color(0xFFE91E63);
  static const Color _brandGreen = Color(0xFF4CAF50);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  TimeOfDay _checkInTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _checkOutTime = const TimeOfDay(hour: 11, minute: 0);

  Future<void> _selectTime(bool isCheckIn) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn ? _checkInTime : _checkOutTime,
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  // ── Build a set of every individual day that is occupied ──────────────────
  Map<DateTime, String> _buildBookedDayMap(List<Map<String, dynamic>> bookings) {
    final map = <DateTime, String>{};
    for (final b in bookings) {
      if (b['reportingDate'] == null || b['checkOutDate'] == null) continue;
      final start = (b['reportingDate'] as Timestamp?)?.toDate();
      final end   = (b['checkOutDate']  as Timestamp?)?.toDate();
      if (start == null || end == null) continue;
      DateTime cursor = DateTime(start.year, start.month, start.day);
      final endDay    = DateTime(end.year,   end.month,   end.day);
      while (!cursor.isAfter(endDay)) {
        map[cursor] = b['status'] ?? 'occupied';
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return map;
  }

  bool _isBooked(DateTime day, Map<DateTime, String> bookedMap) {
    return bookedMap.containsKey(DateTime(day.year, day.month, day.day));
  }

  /// Returns the first free date strictly after all current bookings end
  DateTime _nextFreeDate(List<Map<String, dynamic>> bookings) {
    DateTime latest = DateTime.now();
    for (final b in bookings) {
      final endTs = b['checkOutDate'] as Timestamp?;
      if (endTs == null) continue;
      final end = endTs.toDate();
      if (end.isAfter(latest)) latest = end;
    }
    return latest.isAfter(DateTime.now()) ? latest.add(const Duration(days: 1)) : DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final key = UnitKey(widget.category, widget.capacity, widget.unitNumber);
    final bookingsAsync = ref.watch(unitBookingsProvider(key));
    final allBookingsAsync = ref.watch(allBookingsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: bookingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (bookings) {
            final bookedMap = _buildBookedDayMap(bookings);
            final nextFree = _nextFreeDate(bookings);

            return CustomScrollView(
              controller: scrollCtrl,
              slivers: [
                // ── Drag handle + title ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _brandPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                FormatUtils.formatUnit(widget.category, widget.unitNumber),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brandPurple),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.capacity,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          widget.category,
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ),
                      const Divider(height: 20),
                    ],
                  ),
                ),

                // ── Current occupant card ─────────────────────────────────
                if (widget.currentBooking != null)
                  SliverToBoxAdapter(
                    child: _CurrentBookingCard(
                      booking: widget.currentBooking!,
                      onCheckIn: () => widget.onCheckIn(widget.currentBooking!),
                      onCheckOut: () => widget.onCheckOut(widget.currentBooking!),
                      onCancel: (reason) => widget.onCancel(widget.currentBooking!, reason: reason),
                    ),
                  ),

                // ── Next free date banner ─────────────────────────────────
                if (bookings.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _brandGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _brandGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available, color: _brandGreen),
                            const SizedBox(width: 10),
                            Text(
                              'Next available: ${DateFormat('dd MMM yyyy').format(nextFree)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: _brandGreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Calendar ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TableCalendar(
                      firstDay: DateTime.now().subtract(const Duration(days: 30)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      rangeStartDay: _rangeStart,
                      rangeEndDay: _rangeEnd,
                      rangeSelectionMode: RangeSelectionMode.toggledOn,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: _brandPurple.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        rangeStartDecoration: const BoxDecoration(color: _brandGreen, shape: BoxShape.circle),
                        rangeEndDecoration: const BoxDecoration(color: _brandGreen, shape: BoxShape.circle),
                        rangeHighlightColor: _brandGreen.withOpacity(0.15),
                        outsideDaysVisible: false,
                      ),
                      enabledDayPredicate: (day) {
                        // Disable past days and already-booked days
                        if (day.isBefore(DateTime.now().subtract(const Duration(days: 1)))) return false;
                        return !_isBooked(day, bookedMap);
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (ctx, day, focusedDay) {
                          final normalDay = DateTime(day.year, day.month, day.day);
                          if (bookedMap.containsKey(normalDay)) {
                            final status = bookedMap[normalDay]!;
                            final color = status == 'pre-booked'
                                ? Colors.orange
                                : const Color(0xFFE91E63);
                            return Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.85),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                        todayBuilder: (ctx, day, _) {
                          final isB = _isBooked(day, bookedMap);
                          return Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isB ? _brandPink.withOpacity(0.85) : _brandPurple.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: isB ? Colors.white : _brandPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                          _rangeStart = null; // Clear range when picking specific day for info
                          _rangeEnd = null;
                        });
                      },
                      onRangeSelected: (start, end, focused) {
                        setState(() {
                          _selectedDay = start ?? focused;
                          _rangeStart = start;
                          _rangeEnd = end;
                          _focusedDay = focused;
                        });
                      },
                      onPageChanged: (focused) => setState(() => _focusedDay = focused),
                    ),
                  ),
                ),

                // ── Legend ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _legend(_brandPink, 'Occupied'),
                        const SizedBox(width: 16),
                        _legend(Colors.orange, 'Pre-booked'),
                        const SizedBox(width: 16),
                        _legend(_brandGreen, 'Selected'),
                      ],
                    ),
                  ),
                ),
                
                // ── Daily Bookings List ──────────────────────────────────
                SliverToBoxAdapter(
                  child: allBookingsAsync.when(
                    data: (data) => _buildDailyBookingsList(data),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                // ── Book selected range button ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      children: [
                        if (_rangeStart != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: _brandGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('Check-in', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(DateFormat('dd MMM yyyy').format(_rangeStart!),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis),
                                  ]),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.arrow_forward, color: _brandGreen, size: 16),
                                ),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    const Text('Check-out', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text(
                                      _rangeEnd != null
                                          ? DateFormat('dd MMM yyyy').format(_rangeEnd!)
                                          : 'Select end date',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _rangeEnd != null ? Colors.black : Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                          if (_rangeStart != null && _rangeEnd != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _selectTime(true),
                                      icon: const Icon(Icons.access_time, size: 18),
                                      label: Text('In: ${_checkInTime.format(context)}'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _brandPurple,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _selectTime(false),
                                      icon: const Icon(Icons.access_time, size: 18),
                                      label: Text('Out: ${_checkOutTime.format(context)}'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _brandPurple,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandPurple,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                          label: Text(
                            _rangeStart != null && _rangeEnd != null
                                ? () {
                                    final inDT = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day, _checkInTime.hour, _checkInTime.minute);
                                    final outDT = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day, _checkOutTime.hour, _checkOutTime.minute);
                                    final diff = outDT.difference(inDT);
                                    
                                    if (widget.chargingMode == 'flexible') {
                                      // Calendar day diff
                                      final days = DateTime(outDT.year, outDT.month, outDT.day)
                                          .difference(DateTime(inDT.year, inDT.month, inDT.day))
                                          .inDays;
                                      return 'Book ${days == 0 ? 1 : days} Day(s)';
                                    } else {
                                      // 22-hour strict
                                      final days = (diff.inMinutes / 1320.0).ceil();
                                      return 'Book ${days == 0 ? 1 : days} Day(s)';
                                    }
                                  }()
                                : 'Select dates to book',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          onPressed: (_rangeStart != null && _rangeEnd != null)
                              ? () {
                                  final inDT = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day, _checkInTime.hour, _checkInTime.minute);
                                  final outDT = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day, _checkOutTime.hour, _checkOutTime.minute);
                                  Navigator.pop(context);
                                  widget.onBookDates(inDT, outDT);
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDailyBookingsList(List<Map<String, dynamic>> allBookings) {
    final filtered = allBookings.where((b) {
      final status = b['status'];
      if (status == 'cancelled') return false;
      
      final start = (b['reportingDate'] as Timestamp?)?.toDate();
      final end = (b['checkOutDate'] as Timestamp?)?.toDate() ?? (b['reportingDate'] as Timestamp?)?.toDate();
      
      if (start == null) return false;
      
      // Normalize dates for comparison
      final startD = DateTime(start.year, start.month, start.day);
      final endD = DateTime(end!.year, end.month, end.day);
      final targetD = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      
      return (targetD.isAtSameMomentAs(startD) || targetD.isAfter(startD)) && 
             (targetD.isAtSameMomentAs(endD) || targetD.isBefore(endD));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Bookings for ${DateFormat('dd MMM').format(_selectedDay)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _brandPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text("${filtered.length} Booked", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brandPurple)),
              ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text("Everything is available on this date.", style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
          )
        else
          SizedBox(
            height: 90,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final b = filtered[index];
                final color = b['status'] == 'pre-booked' ? Colors.orange : _brandPink;
                
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        b['customerName'] ?? 'Guest',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.hotel, size: 10, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              FormatUtils.formatUnit(b['category'], b['unitNumber']),
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            b['status'].toString().toUpperCase(),
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(children: [
      Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Current booking info card
// ─────────────────────────────────────────────────────────────────────────────
class _CurrentBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final void Function(String? reason) onCancel;

  const _CurrentBookingCard({
    required this.booking,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] ?? '';
    final isPrebooked = status == 'pre-booked';
    final isOccupied = status == 'occupied';

    final checkIn = (booking['checkInAt'] as Timestamp?)?.toDate();
    final checkOut = (booking['checkOutAt'] as Timestamp?)?.toDate();
    final reportingTs = booking['reportingDate'] as Timestamp?;
    final reporting = reportingTs?.toDate();

    final checkInStr = checkIn != null ? DateFormat('dd MMM yyyy').format(checkIn) : '—';
    final checkOutStr = checkOut != null ? DateFormat('dd MMM yyyy').format(checkOut) : '—';

    bool isOverdue = false;
    if (isPrebooked && booking['reportingDate'] != null) {
      final reportingDate = (booking['reportingDate'] as Timestamp?)?.toDate();
      if (reportingDate != null && reportingDate.isBefore(DateTime.now().subtract(const Duration(hours: 2)))) {
        isOverdue = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF673AB7).withOpacity(0.1), const Color(0xFFE91E63).withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF673AB7).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person, size: 16, color: Color(0xFF673AB7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(booking['customerName'] ?? 'Guest',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isOccupied
                      ? const Color(0xFF4CAF50).withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOccupied ? const Color(0xFF4CAF50) : Colors.orange[700],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Row(children: [
                  const Icon(Icons.login, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(child: Text('Check-in: $checkInStr', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.logout, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(child: Text('Check-out: $checkOutStr', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.timeline, size: 14, color: isOccupied ? const Color(0xFF4CAF50) : Colors.orange[700]),
              const SizedBox(width: 4),
              Text(
                'Phase: ${booking['wasPrebooked'] == true ? (isOccupied ? "Pre-booked -> In" : "Pre-booked -> Next: In") : "Direct Check-in"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOccupied ? const Color(0xFF4CAF50) : Colors.orange[700],
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(child: Text(booking['phone'] ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
            ]),
            const Divider(height: 20),
            // Actions
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPrebooked)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onCheckIn,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('CONFIRM CHECK-IN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                if (isPrebooked) ...[
                  if (isOverdue)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => onCancel('No-Show (Auto-Cancel)'),
                      icon: const Icon(Icons.auto_delete, size: 16),
                      label: const Text('AUTO-CANCEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => onCancel(null),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('CANCEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
                if (isOccupied)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onCheckOut,
                    icon: const Icon(Icons.exit_to_app, size: 16),
                    label: const Text('CHECK-OUT NOW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
