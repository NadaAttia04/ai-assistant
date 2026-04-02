import 'medicine.dart';

class CartItem {
  final Medicine medicine;
  int quantity;

  CartItem({required this.medicine, this.quantity = 1});

  double get subtotal => medicine.price * quantity;
}
