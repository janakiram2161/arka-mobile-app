import 'package:flutter/material.dart';

import '../api/store_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../state/stores.dart';
import '../widgets/common.dart';
import 'web_page_screen.dart';

void openProduct(BuildContext context, int id, {Product? product}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ProductScreen(productId: id, initial: product)),
  );
}

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.productId, this.initial});
  final int productId;
  final Product? initial;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Product? _product;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _product = widget.initial;
    if (_product == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await StoreApi.instance.product(widget.productId, refresh: true);
      if (!mounted) return;
      setState(() => _product = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    return Scaffold(
      appBar: arkaAppBar(context, wordmark: true),
      body: p != null
          ? _ProductBody(product: p)
          : _loading
              ? const Center(child: CircularProgressIndicator(color: ArkaColors.gold))
              : ErrorView(message: _error ?? 'Produkt nicht gefunden.', onRetry: _load),
    );
  }
}

class _ProductBody extends StatefulWidget {
  const _ProductBody({required this.product});
  final Product product;

  @override
  State<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends State<_ProductBody> {
  final PageController _pages = PageController();
  int _page = 0;
  int _qty = 1;
  final Map<String, AttributeTerm> _selected = {};
  Variation? _variation;
  Product? _variationProduct;
  bool _loadingVariation = false;
  late Future<ProductPage> _related;

  Product get p => widget.product;

  @override
  void initState() {
    super.initState();
    for (final a in p.variationAttributes) {
      if (a.terms.length == 1) _selected[a.name] = a.terms.first;
    }
    _variation = _findVariation();
    if (_variation != null) {
      final id = _variation!.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadVariation(id);
      });
    }
    _related = StoreApi.instance.products(
      perPage: 10,
      category: p.categories.isEmpty ? null : '${p.categories.first.id}',
      exclude: [p.id],
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _termMatches(String value, AttributeTerm term) {
    if (value.isEmpty) return true; // "any" value
    final v = value.toLowerCase();
    return v == term.slug.toLowerCase() || v == term.name.toLowerCase();
  }

  Variation? _findVariation() {
    if (!p.isVariable) return null;
    final attrs = p.variationAttributes;
    if (attrs.isEmpty || attrs.any((a) => !_selected.containsKey(a.name))) return null;
    for (final v in p.variations) {
      var ok = true;
      for (final a in attrs) {
        final value = v.attributes[a.name.toLowerCase()];
        if (value != null && !_termMatches(value, _selected[a.name]!)) {
          ok = false;
          break;
        }
      }
      if (ok) return v;
    }
    return null;
  }

  void _matchVariation() {
    if (!p.isVariable) return;
    final found = _findVariation();
    setState(() {
      _variation = found;
      _variationProduct = null;
    });
    if (found != null) _loadVariation(found.id);
  }

  Future<void> _loadVariation(int id) async {
    setState(() => _loadingVariation = true);
    try {
      final vp = await StoreApi.instance.product(id);
      if (!mounted || _variation?.id != id) return;
      setState(() => _variationProduct = vp);
      if (vp.images.isNotEmpty) {
        final idx = p.images.indexWhere((i) => i.src == vp.images.first.src);
        if (idx >= 0 && _pages.hasClients) {
          _pages.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      }
    } catch (_) {
      // Price of the parent product stays visible.
    } finally {
      if (mounted) setState(() => _loadingVariation = false);
    }
  }

  bool get _inStock => _variationProduct?.isInStock ?? p.isInStock;
  int get _maxQty => _variationProduct?.maxQuantity ?? p.maxQuantity;

  void _addToCart() {
    if (p.isVariable && _variation == null) {
      showArkaSnack(context, 'Bitte wähle zuerst eine Variante aus.');
      return;
    }
    final vp = _variationProduct;
    final prices = vp?.prices ?? p.prices;
    final label = p.variationAttributes.map((a) => '${a.name}: ${_selected[a.name]?.name ?? ''}').join(', ');
    CartStore.instance.add(
      CartItem(
        productId: p.id,
        variationId: _variation?.id,
        name: p.name,
        variationLabel: p.isVariable ? label : '',
        imageUrl: (vp != null && vp.images.isNotEmpty) ? vp.images.first.thumbnail : p.thumbnailUrl,
        unitPrice: prices.price,
        money: prices.money,
        quantity: _qty,
        maxQuantity: _maxQty,
        variationAttributes: p.isVariable
            ? p.variationAttributes
                .map((a) => {'attribute': a.cartKey, 'value': _selected[a.name]?.slug ?? ''})
                .toList()
            : const [],
      ),
    );
    showArkaSnack(
      context,
      '„${p.name}“ liegt im Warenkorb.',
      actionLabel: 'Warenkorb',
      onAction: () {
        Navigator.of(context).popUntil((r) => r.isFirst);
        rootTab.value = 3;
      },
    );
  }

  void _openImage(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ImageViewer(images: p.images, initial: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = p.images;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pages,
                      itemCount: images.isEmpty ? 1 : images.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: images.isEmpty ? null : () => _openImage(i),
                        child: NetImage(images.isEmpty ? '' : images[i].src),
                      ),
                    ),
                    Positioned(right: 14, top: 14, child: WishButton(product: p, small: false)),
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == _page ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == _page ? ArkaColors.ink : const Color(0x991C1B19),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.categories.isNotEmpty)
                      Text(
                        p.categories.first.name.toUpperCase(),
                        style: const TextStyle(color: ArkaColors.gold, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 6),
                    Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PriceView(p.prices, large: true, overridePrice: _variationProduct?.prices),
                        if (_loadingVariation) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: ArkaColors.gold),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('inkl. MwSt., zzgl. Versand', style: TextStyle(fontSize: 12, color: ArkaColors.muted)),
                    const SizedBox(height: 8),
                    _StockLine(inStock: _inStock, text: _variationProduct?.stockText ?? p.stockText),
                    if (p.shortDescription.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(p.shortDescription, style: const TextStyle(fontSize: 15, height: 1.5)),
                    ],
                    for (final a in p.variationAttributes) ...[
                      const SizedBox(height: 18),
                      Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: a.terms.map((t) {
                          final selected = _selected[a.name]?.slug == t.slug;
                          return ChoiceChip(
                            label: Text(t.name),
                            selected: selected,
                            selectedColor: ArkaColors.goldSoft,
                            side: BorderSide(color: selected ? ArkaColors.gold : const Color(0xFFD9D2C5)),
                            onSelected: (_) {
                              setState(() => _selected[a.name] = t);
                              _matchVariation();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    if (p.isVariable && _variation == null && p.variationAttributes.every((a) => _selected.containsKey(a.name)))
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('Diese Kombination ist leider nicht verfügbar.', style: TextStyle(color: ArkaColors.sale)),
                      ),
                    const SizedBox(height: 18),
                    const UspRow(),
                    if (p.description.isNotEmpty)
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Beschreibung', style: TextStyle(fontWeight: FontWeight.w600)),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(p.description, style: const TextStyle(height: 1.5)),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Versand & Rückgabe', style: TextStyle(fontWeight: FontWeight.w600)),
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Versand und Zahlung'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openWebPage(context, 'Versand & Zahlung', AppConfig.url(AppConfig.shippingPath)),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Widerrufsbelehrung'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openWebPage(context, 'Widerrufsbelehrung', AppConfig.url(AppConfig.withdrawalPath)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder<ProductPage>(
                future: _related,
                builder: (context, snap) {
                  final items = snap.data?.products ?? const <Product>[];
                  if (items.isEmpty) return const SizedBox(height: 24);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Das könnte dir auch gefallen'),
                      SizedBox(
                        height: 290,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, i) => SizedBox(width: 160, child: ProductCard(product: items[i])),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        _BuyBar(
          product: p,
          quantity: _qty,
          maxQuantity: _maxQty,
          inStock: _inStock,
          onQuantity: (q) => setState(() => _qty = q),
          onAdd: _addToCart,
        ),
      ],
    );
  }
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.inStock, required this.text});
  final bool inStock;
  final String text;

  @override
  Widget build(BuildContext context) {
    final label = text.isNotEmpty ? text : (inStock ? 'Auf Lager' : 'Nicht vorrätig');
    return Row(
      children: [
        Icon(inStock ? Icons.check_circle : Icons.remove_circle_outline,
            size: 16, color: inStock ? const Color(0xFF2E7D32) : ArkaColors.sale),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: inStock ? const Color(0xFF2E7D32) : ArkaColors.sale)),
      ],
    );
  }
}

class _BuyBar extends StatelessWidget {
  const _BuyBar({
    required this.product,
    required this.quantity,
    required this.maxQuantity,
    required this.inStock,
    required this.onQuantity,
    required this.onAdd,
  });

  final Product product;
  final int quantity;
  final int maxQuantity;
  final bool inStock;
  final ValueChanged<int> onQuantity;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final Widget action;
    if (!product.canBuyInApp) {
      action = FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: ArkaColors.ink,
          minimumSize: const Size.fromHeight(50),
        ),
        onPressed: () => openWebPage(context, product.name, product.permalink),
        child: const Text('Im Shop ansehen'),
      );
    } else {
      action = Row(
        children: [
          QuantityStepper(value: quantity, max: maxQuantity, onChanged: onQuantity),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ArkaColors.ink,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: inStock ? onAdd : null,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(inStock ? 'In den Warenkorb' : 'Ausverkauft'),
            ),
          ),
        ],
      );
    }
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: action),
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial});
  final List<ProductImage> images;
  final int initial;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _controller = PageController(initialPage: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: NetImage(widget.images[i].src, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
