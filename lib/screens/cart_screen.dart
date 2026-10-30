import 'package:flutter/material.dart';

import '../config.dart';
import '../state/stores.dart';
import '../widgets/common.dart';
import 'checkout_screen.dart';
import 'product_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: arkaAppBar(context, title: const Text('Warenkorb', style: TextStyle(fontSize: 18))),
      body: ListenableBuilder(
        listenable: CartStore.instance,
        builder: (context, _) {
          final cart = CartStore.instance;
          if (cart.isEmpty) {
            return EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: 'Dein Warenkorb ist leer',
              text: 'Entdecke wasserfesten, nickelfreien Schmuck von ARKA.',
              action: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ArkaColors.ink),
                onPressed: () => rootTab.value = 1,
                child: const Text('Weiter einkaufen'),
              ),
            );
          }
          final items = cart.items;
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _CartRow(item: items[i]),
                ),
              ),
              Material(
                color: Colors.white,
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Zwischensumme', style: TextStyle(fontSize: 16)),
                            ),
                            Text(
                              cart.money.format(cart.subtotal),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Kein Ausweis der USt. gem. § 19 UStG, zzgl. Versand. Gutscheine und Endbetrag an der Kasse.',
                            style: TextStyle(fontSize: 12, color: ArkaColors.muted),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: ArkaColors.ink,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Zur Kasse'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = CartStore.instance;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openProduct(context, item.productId),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 84, height: 105, child: NetImage(item.imageUrl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        InkWell(
                          onTap: () => cart.remove(item),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 18, color: ArkaColors.muted),
                          ),
                        ),
                      ],
                    ),
                    if (item.variationLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.variationLabel, style: const TextStyle(fontSize: 12, color: ArkaColors.muted)),
                    ],
                    const SizedBox(height: 4),
                    Text(item.money.format(item.unitPrice), style: const TextStyle(color: ArkaColors.muted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        QuantityStepper(
                          value: item.quantity,
                          max: item.maxQuantity,
                          onChanged: (q) => cart.setQuantity(item, q),
                        ),
                        const Spacer(),
                        Text(item.money.format(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
