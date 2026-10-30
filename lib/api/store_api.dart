import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads products and categories live from the shop. Because every screen
/// loads from here, a product published on arkaschmuck.de shows up in the app
/// the next time the list is opened or refreshed.
class StoreApi {
  StoreApi._();
  static final StoreApi instance = StoreApi._();

  final http.Client _client = http.Client();
  final Map<int, Product> _productCache = {};
  List<Category>? _categoryCache;

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('${AppConfig.apiBase}$path').replace(queryParameters: query);
    final http.Response res;
    try {
      res = await _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw ApiException('Keine Verbindung zum Shop. Bitte Internetverbindung prüfen.');
    }
    if (res.statusCode != 200) {
      throw ApiException('Der Shop antwortet gerade nicht (Fehler ${res.statusCode}).');
    }
    return _Decoded(jsonDecode(utf8.decode(res.bodyBytes)), res.headers);
  }

  Future<ProductPage> products({
    int page = 1,
    int perPage = 20,
    String? category,
    String? search,
    String orderBy = 'date',
    String order = 'desc',
    bool onSale = false,
    List<int>? exclude,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      'orderby': orderBy,
      'order': order,
    };
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (onSale) query['on_sale'] = 'true';
    if (exclude != null && exclude.isNotEmpty) query['exclude'] = exclude.join(',');

    final decoded = await _get('/products', query) as _Decoded;
    final body = decoded.body;
    final list = body is List ? body : const [];
    final products = list
        .whereType<Map>()
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    for (final p in products) {
      _productCache[p.id] = p;
    }
    return ProductPage(
      products: products,
      totalPages: int.tryParse(decoded.headers['x-wp-totalpages'] ?? '') ?? 1,
      total: int.tryParse(decoded.headers['x-wp-total'] ?? '') ?? products.length,
    );
  }

  Future<Product> product(int id, {bool refresh = false}) async {
    if (!refresh && _productCache.containsKey(id)) return _productCache[id]!;
    final decoded = await _get('/products/$id') as _Decoded;
    final body = decoded.body;
    if (body is! Map) throw ApiException('Produkt nicht gefunden.');
    final p = Product.fromJson(Map<String, dynamic>.from(body));
    _productCache[id] = p;
    return p;
  }

  Future<List<Category>> categories({bool refresh = false}) async {
    if (!refresh && _categoryCache != null) return _categoryCache!;
    final decoded = await _get('/products/categories', const {'per_page': '100'}) as _Decoded;
    final body = decoded.body;
    final list = body is List ? body : const [];
    final cats = list
        .whereType<Map>()
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.count > 0 && !AppConfig.hiddenCategorySlugs.contains(c.slug))
        .toList();
    _categoryCache = cats;
    return cats;
  }

  void clearCache() {
    _productCache.clear();
    _categoryCache = null;
  }
}

class _Decoded {
  _Decoded(this.body, this.headers);
  final dynamic body;
  final Map<String, String> headers;
}
