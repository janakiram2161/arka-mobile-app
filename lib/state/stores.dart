import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Which bottom tab is visible (0 Start, 1 Shop, 2 Merkliste, 3 Warenkorb, 4 Mehr).
final ValueNotifier<int> rootTab = ValueNotifier<int>(0);

class CartItem {
  CartItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.money,
    required this.quantity,
    required this.maxQuantity,
    this.variationId,
    this.variationLabel = '',
    this.variationAttributes = const [],
  });

  final int productId;
  final int? variationId;
  final String name;
  final String variationLabel;
  final String imageUrl;
  final int unitPrice;
  final Money money;
  int quantity;
  final int maxQuantity;

  /// [{attribute: 'pa_farbe', value: 'gold'}] – sent to the shop cart.
  final List<Map<String, String>> variationAttributes;

  int get cartId => variationId ?? productId;
  int get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'variationId': variationId,
        'name': name,
        'variationLabel': variationLabel,
        'imageUrl': imageUrl,
        'unitPrice': unitPrice,
        'money': money.toJson(),
        'quantity': quantity,
        'maxQuantity': maxQuantity,
        'variationAttributes': variationAttributes,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        productId: (j['productId'] as num).toInt(),
        variationId: (j['variationId'] as num?)?.toInt(),
        name: (j['name'] ?? '').toString(),
        variationLabel: (j['variationLabel'] ?? '').toString(),
        imageUrl: (j['imageUrl'] ?? '').toString(),
        unitPrice: (j['unitPrice'] as num? ?? 0).toInt(),
        money: Money.fromJson(Map<String, dynamic>.from(j['money'] as Map? ?? const {})),
        quantity: (j['quantity'] as num? ?? 1).toInt(),
        maxQuantity: (j['maxQuantity'] as num? ?? 99).toInt(),
        variationAttributes: ((j['variationAttributes'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList(),
      );

  /// Payload for POST /wc/store/v1/cart/add-item.
  Map<String, dynamic> toStoreApiItem() => {
        'id': cartId,
        'quantity': quantity,
        if (variationAttributes.isNotEmpty) 'variation': variationAttributes,
      };
}

class CartStore extends ChangeNotifier {
  CartStore._();
  static final CartStore instance = CartStore._();
  static const _key = 'arka_cart_v1';

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);
  int get count => _items.fold(0, (sum, i) => sum + i.quantity);
  int get subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);
  Money get money => _items.isEmpty ? const Money() : _items.first.money;
  bool get isEmpty => _items.isEmpty;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _items
        ..clear()
        ..addAll(list.whereType<Map>().map((m) => CartItem.fromJson(Map<String, dynamic>.from(m))));
      notifyListeners();
    } catch (_) {
      // A broken saved cart is simply discarded.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.map((i) => i.toJson()).toList()));
  }

  void add(CartItem item) {
    final existing = _items.where((i) => i.cartId == item.cartId).toList();
    if (existing.isNotEmpty) {
      final e = existing.first;
      e.quantity = (e.quantity + item.quantity).clamp(1, e.maxQuantity);
    } else {
      _items.add(item);
    }
    notifyListeners();
    _save();
  }

  void setQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      remove(item);
      return;
    }
    item.quantity = quantity.clamp(1, item.maxQuantity);
    notifyListeners();
    _save();
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
    _save();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _save();
  }
}

class WishItem {
  const WishItem({required this.id, required this.name, required this.imageUrl, required this.priceText});
  final int id;
  final String name;
  final String imageUrl;
  final String priceText;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'imageUrl': imageUrl, 'priceText': priceText};

  factory WishItem.fromJson(Map<String, dynamic> j) => WishItem(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        imageUrl: (j['imageUrl'] ?? '').toString(),
        priceText: (j['priceText'] ?? '').toString(),
      );
}

class WishlistStore extends ChangeNotifier {
  WishlistStore._();
  static final WishlistStore instance = WishlistStore._();
  static const _key = 'arka_wishlist_v1';

  final Map<int, WishItem> _items = {};
  List<WishItem> get items => _items.values.toList().reversed.toList();
  bool contains(int id) => _items.containsKey(id);
  int get count => _items.length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = jsonDecode(raw) as List;
      _items.clear();
      for (final m in list.whereType<Map>()) {
        final w = WishItem.fromJson(Map<String, dynamic>.from(m));
        _items[w.id] = w;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_items.values.map((w) => w.toJson()).toList()));
  }

  void toggle(Product p) {
    if (_items.containsKey(p.id)) {
      _items.remove(p.id);
    } else {
      _items[p.id] = WishItem(
        id: p.id,
        name: p.name,
        imageUrl: p.thumbnailUrl,
        priceText: priceLabel(p.prices),
      );
    }
    notifyListeners();
    _save();
  }

  void removeId(int id) {
    _items.remove(id);
    notifyListeners();
    _save();
  }
}

String priceLabel(Prices p) {
  if (p.isRange) return 'ab ${p.money.format(p.rangeMin!)}';
  return p.money.format(p.price);
}
