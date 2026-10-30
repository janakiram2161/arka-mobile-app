import '../utils/html.dart';

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String _str(dynamic v) => v == null ? '' : v.toString();

List<Map<String, dynamic>> _list(dynamic v) {
  if (v is List) {
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

/// Currency settings delivered with every Store API price object.
class Money {
  const Money({
    this.code = 'EUR',
    this.minorUnit = 2,
    this.prefix = '',
    this.suffix = ' €',
    this.decimalSeparator = ',',
    this.thousandSeparator = '.',
  });

  final String code;
  final int minorUnit;
  final String prefix;
  final String suffix;
  final String decimalSeparator;
  final String thousandSeparator;

  factory Money.fromJson(Map<String, dynamic> j) {
    final prefix = _str(j['currency_prefix']);
    var suffix = _str(j['currency_suffix']);
    if (prefix.isEmpty && suffix.isEmpty) {
      suffix = ' ${_str(j['currency_symbol']).isEmpty ? '€' : _str(j['currency_symbol'])}';
    }
    return Money(
      code: _str(j['currency_code']).isEmpty ? 'EUR' : _str(j['currency_code']),
      minorUnit: _int(j['currency_minor_unit'], 2),
      prefix: prefix,
      suffix: suffix,
      decimalSeparator: _str(j['currency_decimal_separator']).isEmpty ? ',' : _str(j['currency_decimal_separator']),
      thousandSeparator: _str(j['currency_thousand_separator']),
    );
  }

  Map<String, dynamic> toJson() => {
        'currency_code': code,
        'currency_minor_unit': minorUnit,
        'currency_prefix': prefix,
        'currency_suffix': suffix,
        'currency_decimal_separator': decimalSeparator,
        'currency_thousand_separator': thousandSeparator,
      };

  String format(int amount) {
    final negative = amount < 0;
    final abs = amount.abs();
    var divisor = 1;
    for (var i = 0; i < minorUnit; i++) {
      divisor *= 10;
    }
    final whole = (abs ~/ divisor).toString();
    final frac = abs % divisor;
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final fromEnd = whole.length - i;
      grouped.write(whole[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) grouped.write(thousandSeparator);
    }
    final fraction = minorUnit > 0 ? '$decimalSeparator${frac.toString().padLeft(minorUnit, '0')}' : '';
    return '${negative ? '-' : ''}$prefix$grouped$fraction$suffix';
  }
}

class Prices {
  const Prices({
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.money,
    this.rangeMin,
    this.rangeMax,
  });

  final int price;
  final int regularPrice;
  final int salePrice;
  final Money money;
  final int? rangeMin;
  final int? rangeMax;

  bool get isRange => rangeMin != null && rangeMax != null && rangeMin != rangeMax;
  bool get isReduced => regularPrice > price && price > 0;

  factory Prices.fromJson(Map<String, dynamic> j) {
    final range = j['price_range'];
    int? min;
    int? max;
    if (range is Map) {
      min = _int(range['min_amount']);
      max = _int(range['max_amount']);
    }
    return Prices(
      price: _int(j['price']),
      regularPrice: _int(j['regular_price']),
      salePrice: _int(j['sale_price']),
      money: Money.fromJson(j),
      rangeMin: min,
      rangeMax: max,
    );
  }

  static const empty = Prices(price: 0, regularPrice: 0, salePrice: 0, money: Money());
}

class ProductImage {
  const ProductImage({required this.src, required this.thumbnail, this.alt = ''});
  final String src;
  final String thumbnail;
  final String alt;

  factory ProductImage.fromJson(Map<String, dynamic> j) {
    final src = _str(j['src']);
    final thumb = _str(j['thumbnail']);
    return ProductImage(src: src, thumbnail: thumb.isEmpty ? src : thumb, alt: _str(j['alt']));
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.parent,
    required this.count,
    this.image,
  });

  final int id;
  final String name;
  final String slug;
  final int parent;
  final int count;
  final ProductImage? image;

  factory Category.fromJson(Map<String, dynamic> j) {
    final img = j['image'];
    return Category(
      id: _int(j['id']),
      name: decodeEntities(_str(j['name'])),
      slug: _str(j['slug']),
      parent: _int(j['parent']),
      count: _int(j['count']),
      image: img is Map && _str(img['src']).isNotEmpty ? ProductImage.fromJson(Map<String, dynamic>.from(img)) : null,
    );
  }
}

class AttributeTerm {
  const AttributeTerm({required this.name, required this.slug});
  final String name;
  final String slug;
}

class ProductAttribute {
  const ProductAttribute({
    required this.name,
    required this.taxonomy,
    required this.hasVariations,
    required this.terms,
  });

  final String name;
  final String taxonomy;
  final bool hasVariations;
  final List<AttributeTerm> terms;

  /// Key used when sending the attribute to the Store API cart.
  String get cartKey => taxonomy.isNotEmpty ? taxonomy : name;

  factory ProductAttribute.fromJson(Map<String, dynamic> j) {
    return ProductAttribute(
      name: decodeEntities(_str(j['name'])),
      taxonomy: _str(j['taxonomy']),
      hasVariations: j['has_variations'] == true,
      terms: _list(j['terms'])
          .map((t) => AttributeTerm(name: decodeEntities(_str(t['name'])), slug: _str(t['slug'])))
          .toList(),
    );
  }
}

class Variation {
  const Variation({required this.id, required this.attributes});
  final int id;

  /// attribute name (lower case) -> value (term slug, or empty for "any").
  final Map<String, String> attributes;

  factory Variation.fromJson(Map<String, dynamic> j) {
    final attrs = <String, String>{};
    for (final a in _list(j['attributes'])) {
      attrs[decodeEntities(_str(a['name'])).toLowerCase()] = _str(a['value']);
    }
    return Variation(id: _int(j['id']), attributes: attrs);
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.type,
    required this.permalink,
    required this.shortDescription,
    required this.description,
    required this.onSale,
    required this.prices,
    required this.images,
    required this.categories,
    required this.attributes,
    required this.variations,
    required this.isPurchasable,
    required this.isInStock,
    required this.stockText,
    required this.maxQuantity,
  });

  final int id;
  final String name;
  final String type;
  final String permalink;
  final String shortDescription;
  final String description;
  final bool onSale;
  final Prices prices;
  final List<ProductImage> images;
  final List<Category> categories;
  final List<ProductAttribute> attributes;
  final List<Variation> variations;
  final bool isPurchasable;
  final bool isInStock;
  final String stockText;
  final int maxQuantity;

  bool get isVariable => type == 'variable';
  bool get isSimple => type == 'simple';
  bool get canBuyInApp => (isSimple || isVariable) && isPurchasable;
  List<ProductAttribute> get variationAttributes => attributes.where((a) => a.hasVariations).toList();

  String get imageUrl => images.isEmpty ? '' : images.first.src;
  String get thumbnailUrl => images.isEmpty ? '' : images.first.thumbnail;

  factory Product.fromJson(Map<String, dynamic> j) {
    final pricesJson = j['prices'];
    final stock = j['stock_availability'];
    final addToCart = j['add_to_cart'];
    var max = 99;
    if (addToCart is Map) {
      final m = _int(addToCart['maximum'], 99);
      if (m > 0 && m < max) max = m;
    }
    return Product(
      id: _int(j['id']),
      name: decodeEntities(_str(j['name'])),
      type: _str(j['type']),
      permalink: _str(j['permalink']),
      shortDescription: htmlToText(_str(j['short_description'])),
      description: htmlToText(_str(j['description'])),
      onSale: j['on_sale'] == true,
      prices: pricesJson is Map ? Prices.fromJson(Map<String, dynamic>.from(pricesJson)) : Prices.empty,
      images: _list(j['images']).map(ProductImage.fromJson).where((i) => i.src.isNotEmpty).toList(),
      categories: _list(j['categories']).map(Category.fromJson).toList(),
      attributes: _list(j['attributes']).map(ProductAttribute.fromJson).toList(),
      variations: _list(j['variations']).map(Variation.fromJson).toList(),
      isPurchasable: j['is_purchasable'] != false,
      isInStock: j['is_in_stock'] != false,
      stockText: stock is Map ? htmlToText(_str(stock['text'])) : '',
      maxQuantity: max,
    );
  }
}

class ProductPage {
  const ProductPage({required this.products, required this.totalPages, required this.total});
  final List<Product> products;
  final int totalPages;
  final int total;
}
