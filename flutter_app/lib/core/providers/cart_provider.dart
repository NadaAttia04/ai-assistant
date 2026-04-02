import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/medicine.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get total => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  bool contains(String medicineId) =>
      _items.any((i) => i.medicine.id == medicineId);

  int quantityOf(String medicineId) {
    final idx = _items.indexWhere((i) => i.medicine.id == medicineId);
    return idx == -1 ? 0 : _items[idx].quantity;
  }

  void add(Medicine medicine) {
    final idx = _items.indexWhere((i) => i.medicine.id == medicine.id);
    if (idx == -1) {
      _items.add(CartItem(medicine: medicine));
    } else {
      _items[idx].quantity++;
    }
    notifyListeners();
  }

  void decrement(String medicineId) {
    final idx = _items.indexWhere((i) => i.medicine.id == medicineId);
    if (idx == -1) return;
    if (_items[idx].quantity <= 1) {
      _items.removeAt(idx);
    } else {
      _items[idx].quantity--;
    }
    notifyListeners();
  }

  void remove(String medicineId) {
    _items.removeWhere((i) => i.medicine.id == medicineId);
    notifyListeners();
  }

  void setQuantity(String medicineId, int qty) {
    if (qty <= 0) {
      remove(medicineId);
      return;
    }
    final idx = _items.indexWhere((i) => i.medicine.id == medicineId);
    if (idx != -1) {
      _items[idx].quantity = qty;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
