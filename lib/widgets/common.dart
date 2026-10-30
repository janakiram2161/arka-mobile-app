import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/models.dart';
import '../screens/product_screen.dart';
import '../state/stores.dart';

class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.center});
  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: ArkaColors.sand,
        alignment: Alignment.center,
        child: const Icon(Icons.diamond_outlined, color: ArkaColors.gold),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      alignment: alignment,
      placeholder: (context, _) => Container(color: ArkaColors.sand),
      errorWidget: (context, _, __) => Container(
        color: ArkaColors.sand,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: ArkaColors.muted),
      ),
    );
  }
}

class PriceView extends StatelessWidget {
  const PriceView(this.prices, {super.key, this.large = false, this.overridePrice});
  final Prices prices;
  final bool large;

  /// Used for a selected variation.
  final Prices? overridePrice;

  @override
  Widget build(BuildContext context) {
    final p = overridePrice ?? prices;
    final size = large ? 22.0 : 14.0;
    final money = p.money;
    if (overridePrice == null && p.isRange) {
      return Text(
        'ab ${money.format(p.rangeMin!)}',
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: ArkaColors.ink),
      );
    }
    if (p.isReduced) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(
            money.format(p.price),
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: ArkaColors.sale),
          ),
          Text(
            money.format(p.regularPrice),
            style: TextStyle(
              fontSize: size - 3,
              color: ArkaColors.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }
    return Text(
      money.format(p.price),
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: ArkaColors.ink),
    );
  }
}

class WishButton extends StatelessWidget {
  const WishButton({super.key, required this.product, this.small = true});
  final Product product;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WishlistStore.instance,
      builder: (context, _) {
        final saved = WishlistStore.instance.contains(product.id);
        final icon = Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: saved ? ArkaColors.sale : ArkaColors.ink,
          size: small ? 20 : 26,
        );
        return Material(
          color: const Color(0xE6FFFFFF),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => WishlistStore.instance.toggle(product),
            child: Padding(padding: EdgeInsets.all(small ? 6 : 10), child: icon),
          ),
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openProduct(context, product.id, product: product),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(product.thumbnailUrl),
                  if (product.prices.isReduced)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: ArkaColors.sale, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Sale', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (!product.isInStock)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xCC1C1B19), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Ausverkauft', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  Positioned(right: 6, top: 6, child: WishButton(product: product)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.25, color: ArkaColors.ink),
          ),
          const SizedBox(height: 4),
          PriceView(product.prices),
        ],
      ),
    );
  }
}

SliverGridDelegate productGridDelegate(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final columns = width > 900 ? 4 : (width > 600 ? 3 : 2);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: 18,
    crossAxisSpacing: 14,
    childAspectRatio: 0.58,
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: ArkaColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ArkaColors.ink)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.text, this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: ArkaColors.gold),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text!, textAlign: TextAlign.center, style: const TextStyle(color: ArkaColors.muted)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onMore});
  final String title;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: ArkaColors.ink),
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(foregroundColor: ArkaColors.gold),
              child: const Text('Alle ansehen'),
            ),
        ],
      ),
    );
  }
}

class UspRow extends StatelessWidget {
  const UspRow({super.key, this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: ArkaColors.gold, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: light ? ArkaColors.white : ArkaColors.ink)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          item(Icons.water_drop_outlined, 'Wasserfest'),
          item(Icons.spa_outlined, 'Antiallergen'),
          item(Icons.verified_outlined, 'Nickelfrei'),
        ],
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.max = 99, this.min = 1});
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9D2C5)),
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

void showArkaSnack(BuildContext context, String text, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: ArkaColors.ink,
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, textColor: ArkaColors.gold, onPressed: onAction ?? () {}),
    ),
  );
}
