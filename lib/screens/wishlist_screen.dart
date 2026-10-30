import 'package:flutter/material.dart';

import '../config.dart';
import '../state/stores.dart';
import '../widgets/common.dart';
import 'product_screen.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: arkaAppBar(context, title: const Text('Merkliste', style: TextStyle(fontSize: 18))),
      body: ListenableBuilder(
        listenable: WishlistStore.instance,
        builder: (context, _) {
          final items = WishlistStore.instance.items;
          if (items.isEmpty) {
            return EmptyView(
              icon: Icons.favorite_border,
              title: 'Deine Merkliste ist leer',
              text: 'Tippe auf das Herz bei einem Schmuckstück, um es hier zu speichern.',
              action: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: ArkaColors.ink),
                onPressed: () => rootTab.value = 1,
                child: const Text('Zum Shop'),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: productGridDelegate(context),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final w = items[i];
              return InkWell(
                onTap: () => openProduct(context, w.id),
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
                            NetImage(w.imageUrl),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Material(
                                color: const Color(0xE6FFFFFF),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => WishlistStore.instance.removeId(w.id),
                                  child: const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.favorite, color: ArkaColors.sale, size: 20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(w.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(w.priceText, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
