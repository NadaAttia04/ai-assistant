import 'package:flutter/material.dart';

class Booking {
  final String id;
  final String doctorId;
  final String doctorName;
  final String specialty;
  final String hospital;
  final String date; // formatted, e.g. "2026-04-05"
  final String time; // e.g. "9:00 AM"
  final double fee;
  String status; // pending | confirmed | cancelled | completed | rescheduled
  final String? notes;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.specialty,
    required this.hospital,
    required this.date,
    required this.time,
    required this.fee,
    this.status = 'pending',
    this.notes,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      case 'rescheduled':
        return 'Rescheduled';
      default:
        return 'Pending';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'completed':
        return const Color(0xFF6B7280);
      case 'rescheduled':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFFD97706);
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'specialty': specialty,
        'hospital': hospital,
        'date': date,
        'time': time,
        'fee': fee,
        'status': status,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        doctorId: j['doctorId'] as String,
        doctorName: j['doctorName'] as String,
        specialty: j['specialty'] as String,
        hospital: j['hospital'] as String? ?? '',
        date: j['date'] as String,
        time: j['time'] as String,
        fee: (j['fee'] as num).toDouble(),
        status: j['status'] as String? ?? 'pending',
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
