import 'package:flutter/material.dart';

import '../api/store_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<List<Category>> _future = StoreApi.instance.categories();

  Future<void> _refresh() async {
    final f = StoreApi.instance.categories(refresh: true);
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: arkaAppBar(
        context,
        title: const Text('Shop', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: FutureBuilder<List<Category>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: ArkaColors.gold));
          }
          if (snap.hasError && !snap.hasData) {
            return ErrorView(message: snap.error.toString(), onRetry: _refresh);
          }
          final cats = snap.data ?? const <Category>[];
          return RefreshIndicator(
            color: ArkaColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _CategoryTile(
                  title: 'Alle Produkte',
                  subtitle: 'Die ganze Kollektion',
                  image: const ColoredBox(
                    color: ArkaColors.ink,
                    child: Center(child: ArkaWordmark(light: true)),
                  ),
                  onTap: () => openProductList(context, title: 'Alle Produkte'),
                ),
                for (final c in cats)
                  _CategoryTile(
                    title: c.name,
                    subtitle: '${c.count} ${c.count == 1 ? 'Produkt' : 'Produkte'}',
                    image: CategoryImage(category: c),
                    onTap: () => openProductList(context, title: c.name, category: '${c.id}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.title, required this.subtitle, required this.image, required this.onTap});
  final String title;
  final String subtitle;
  final Widget image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 110,
            child: Row(
              children: [
                SizedBox(width: 110, height: 110, child: image),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: ArkaColors.muted)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.chevron_right, color: ArkaColors.gold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
