import 'package:flutter/material.dart';

import '../api/store_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../widgets/common.dart';

class SortOption {
  const SortOption(this.label, this.orderBy, this.order);
  final String label;
  final String orderBy;
  final String order;
}

const List<SortOption> sortOptions = [
  SortOption('Neueste zuerst', 'date', 'desc'),
  SortOption('Beliebteste', 'popularity', 'desc'),
  SortOption('Preis aufsteigend', 'price', 'asc'),
  SortOption('Preis absteigend', 'price', 'desc'),
];

void openProductList(BuildContext context, {required String title, String? category, bool onSale = false}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProductListScreen(title: title, category: category, onSale: onSale),
    ),
  );
}

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key, required this.title, this.category, this.onSale = false});
  final String title;
  final String? category;
  final bool onSale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: arkaAppBar(context, title: Text(title, style: const TextStyle(fontSize: 18))),
      body: PagedProductGrid(category: category, onSale: onSale),
    );
  }
}

/// Infinite-scrolling product grid with sorting and pull-to-refresh.
class PagedProductGrid extends StatefulWidget {
  const PagedProductGrid({super.key, this.category, this.search, this.onSale = false, this.showSort = true});
  final String? category;
  final String? search;
  final bool onSale;
  final bool showSort;

  @override
  State<PagedProductGrid> createState() => _PagedProductGridState();
}

class _PagedProductGridState extends State<PagedProductGrid> {
  final List<Product> _items = [];
  final ScrollController _scroll = ScrollController();
  SortOption _sort = sortOptions.first;
  int _page = 0;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void didUpdateWidget(covariant PagedProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search || oldWidget.category != widget.category) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _requestId++;
    setState(() {
      _items.clear();
      _page = 0;
      _totalPages = 1;
      _total = 0;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _totalPages) return;
    final request = _requestId;
    setState(() => _loading = true);
    try {
      final result = await StoreApi.instance.products(
        page: _page + 1,
        perPage: 20,
        category: widget.category,
        search: widget.search,
        onSale: widget.onSale,
        orderBy: _sort.orderBy,
        order: _sort.order,
      );
      if (!mounted || request != _requestId) return;
      setState(() {
        _page++;
        _totalPages = result.totalPages;
        _total = result.total;
        _items.addAll(result.products);
      });
    } catch (e) {
      if (!mounted || request != _requestId) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _items.isEmpty) {
      return ErrorView(message: _error!, onRetry: _reload);
    }
    if (_items.isEmpty && (_loading || _page == 0)) {
      return const Center(child: CircularProgressIndicator(color: ArkaColors.gold));
    }
    if (!_loading && _items.isEmpty && _page > 0) {
      return EmptyView(
        icon: Icons.search_off,
        title: 'Keine Produkte gefunden',
        text: widget.search != null ? 'Versuche einen anderen Suchbegriff.' : null,
      );
    }
    return RefreshIndicator(
      color: ArkaColors.gold,
      onRefresh: _reload,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.showSort)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _page == 0 ? '' : '$_total Produkte',
                        style: const TextStyle(color: ArkaColors.muted),
                      ),
                    ),
                    PopupMenuButton<SortOption>(
                      initialValue: _sort,
                      onSelected: (s) {
                        _sort = s;
                        _reload();
                      },
                      itemBuilder: (context) => sortOptions
                          .map((s) => PopupMenuItem<SortOption>(value: s, child: Text(s.label)))
                          .toList(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 18),
                            const SizedBox(width: 6),
                            Text(_sort.label),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: SliverGrid(
              gridDelegate: productGridDelegate(context),
              delegate: SliverChildBuilderDelegate(
                (context, i) => ProductCard(product: _items[i]),
                childCount: _items.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator(color: ArkaColors.gold)
                    : (_error != null
                        ? TextButton(onPressed: _loadMore, child: const Text('Mehr laden'))
                        : const SizedBox.shrink()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
