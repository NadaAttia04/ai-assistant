import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
import '../models/order.dart';

/// Persists all booking + order activity locally via SharedPreferences.
class ActivityService {
  static const _bookingsKey = 'activity_bookings';
  static const _ordersKey = 'activity_orders';

  // ── Bookings ─────────────────────────────────────────────────────────────────

  static Future<List<Booking>> getBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookingsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => Booking.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> addBooking(Booking booking) async {
    final bookings = await getBookings();
    bookings.insert(0, booking);
    await _saveBookings(bookings);
  }

  static Future<void> updateBookingStatus(String id, String status) async {
    final bookings = await getBookings();
    for (final b in bookings) {
      if (b.id == id) b.status = status;
    }
    await _saveBookings(bookings);
  }

  static Future<void> rescheduleBooking(
      String id, String newDate, String newTime) async {
    final bookings = await getBookings();
    for (final b in bookings) {
      if (b.id == id) {
        // Replace with updated booking — rebuild since fields are final
        final idx = bookings.indexOf(b);
        bookings[idx] = Booking(
          id: b.id,
          doctorId: b.doctorId,
          doctorName: b.doctorName,
          specialty: b.specialty,
          hospital: b.hospital,
          date: newDate,
          time: newTime,
          fee: b.fee,
          status: 'rescheduled',
          notes: b.notes,
          createdAt: b.createdAt,
        );
        break;
      }
    }
    await _saveBookings(bookings);
  }

  static Future<void> _saveBookings(List<Booking> bookings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _bookingsKey, jsonEncode(bookings.map((b) => b.toJson()).toList()));
  }

  // ── Orders ───────────────────────────────────────────────────────────────────

  static Future<List<PharmacyOrder>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ordersKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => PharmacyOrder.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  static Future<void> addOrder(PharmacyOrder order) async {
    final orders = await getOrders();
    orders.insert(0, order);
    await _saveOrders(orders);
  }

  static Future<void> updateOrderStatus(String id, String status) async {
    final orders = await getOrders();
    for (final o in orders) {
      if (o.id == id) o.status = status;
    }
    await _saveOrders(orders);
  }

  static Future<void> _saveOrders(List<PharmacyOrder> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _ordersKey, jsonEncode(orders.map((o) => o.toJson()).toList()));
  }
}
