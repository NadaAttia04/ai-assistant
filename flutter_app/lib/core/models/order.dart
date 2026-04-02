import 'package:flutter/material.dart';

class OrderItem {
  final String medicineId;
  final String name;
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.medicineId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        medicineId: j['medicineId'] as String,
        name: j['name'] as String,
        quantity: (j['quantity'] as num).toInt(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
      );
}

class PharmacyOrder {
  final String id;
  final List<OrderItem> items;
  final double totalPrice;
  String status; // pending | confirmed | out_for_delivery | delivered | cancelled | failed
  final String deliveryAddress;
  final double? lat;
  final double? lng;
  final String paymentMethod; // cash | card
  final DateTime createdAt;

  PharmacyOrder({
    required this.id,
    required this.items,
    required this.totalPrice,
    this.status = 'pending',
    required this.deliveryAddress,
    this.lat,
    this.lng,
    required this.paymentMethod,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF0891B2);
      case 'out_for_delivery':
        return const Color(0xFF7C3AED);
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'failed':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  int get totalItems => items.fold(0, (s, i) => s + i.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'totalPrice': totalPrice,
        'status': status,
        'deliveryAddress': deliveryAddress,
        'lat': lat,
        'lng': lng,
        'paymentMethod': paymentMethod,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PharmacyOrder.fromJson(Map<String, dynamic> j) => PharmacyOrder(
        id: j['id'] as String,
        items: (j['items'] as List)
            .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        totalPrice: (j['totalPrice'] as num).toDouble(),
        status: j['status'] as String? ?? 'pending',
        deliveryAddress: j['deliveryAddress'] as String? ?? '',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        paymentMethod: j['paymentMethod'] as String? ?? 'cash',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
