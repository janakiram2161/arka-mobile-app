import 'package:flutter/material.dart';

import '../api/store_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../state/stores.dart';
import '../widgets/common.dart';
import '../widgets/home_slider.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';

class HomeData {
  HomeData(this.categories, this.newest, this.sale);
  final List<Category> categories;
  final List<Product> newest;
  final List<Product> sale;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<HomeData> _load({bool refresh = false}) async {
    final api = StoreApi.instance;
    if (refresh) api.clearCache();
    final results = await Future.wait<dynamic>([
      api.categories(refresh: refresh),
      api.products(perPage: 10, orderBy: 'date', order: 'desc'),
      api.products(perPage: 10, onSale: true, orderBy: 'date', order: 'desc'),
    ]);
    return HomeData(
      results[0] as List<Category>,
      (results[1] as ProductPage).products,
      (results[2] as ProductPage).products,
    );
  }

  Future<void> _refresh() async {
    final f = _load(refresh: true);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: arkaAppBar(
        context,
        wordmark: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: FutureBuilder<HomeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: ArkaColors.gold));
          }
          if (snap.hasError && !snap.hasData) {
            return ErrorView(message: snap.error.toString(), onRetry: () => setState(() => _future = _load(refresh: true)));
          }
          final data = snap.data!;
          return RefreshIndicator(
            color: ArkaColors.gold,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: HomeSlider()),
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 16), child: UspRow())),
                if (data.categories.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader(title: 'Kategorien')),
                  SliverToBoxAdapter(child: _CategoryStrip(categories: data.categories)),
                ],
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Neu eingetroffen',
                    onMore: () => openProductList(context, title: 'Neu eingetroffen'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: productGridDelegate(context),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ProductCard(product: data.newest[i]),
                      childCount: data.newest.length,
                    ),
                  ),
                ),
                if (data.sale.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Im Angebot',
                      onMore: () => openProductList(context, title: 'Im Angebot', onSale: true),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 290,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: data.sale.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, i) => SizedBox(width: 160, child: ProductCard(product: data.sale[i])),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ArkaColors.ink,
                        side: const BorderSide(color: ArkaColors.ink),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => rootTab.value = 1,
                      child: const Text('Alle Kategorien entdecken'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.categories});
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = categories[i];
          return InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => openProductList(context, title: c.name, category: '${c.id}'),
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  ClipOval(
                    child: SizedBox(width: 72, height: 72, child: CategoryImage(category: c)),
                  ),
                  const SizedBox(height: 8),
                  Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Category picture: the category image from the shop, or else the picture
/// of the newest product in that category.
class CategoryImage extends StatefulWidget {
  const CategoryImage({super.key, required this.category});
  final Category category;

  @override
  State<CategoryImage> createState() => _CategoryImageState();
}

class _CategoryImageState extends State<CategoryImage> {
  static final Map<int, String> _cache = {};
  String? _url;

  @override
  void initState() {
    super.initState();
    final img = widget.category.image;
    if (img != null) {
      _url = img.thumbnail;
    } else if (_cache.containsKey(widget.category.id)) {
      _url = _cache[widget.category.id];
    } else {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    try {
      final page = await StoreApi.instance.products(perPage: 1, category: '${widget.category.id}');
      final url = page.products.isEmpty ? '' : page.products.first.thumbnailUrl;
      _cache[widget.category.id] = url;
      if (mounted) setState(() => _url = url);
    } catch (_) {
      if (mounted) setState(() => _url = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) return Container(color: ArkaColors.sand);
    return NetImage(_url!);
  }
}
