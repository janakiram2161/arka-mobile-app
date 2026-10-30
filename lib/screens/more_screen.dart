import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/common.dart';
import 'legal_page_screen.dart';
import 'web_page_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String path) => ListTile(
          leading: Icon(icon, color: ArkaColors.gold),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openWebPage(context, title, AppConfig.url(path)),
        );

    Widget legal(IconData icon, String path) {
      final page = AppConfig.legal(path);
      return ListTile(
        leading: Icon(icon, color: ArkaColors.gold),
        title: Text(page.title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openLegalPage(context, page),
      );
    }

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Text(title.toUpperCase(),
                    style: const TextStyle(fontSize: 12, letterSpacing: 2, color: ArkaColors.muted, fontWeight: FontWeight.w600)),
              ),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Column(children: children),
              ),
            ],
          ),
        );

    return Scaffold(
      appBar: arkaAppBar(context, title: const Text('Mehr', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _BrandCard(),
          ),
          group('Mein ARKA', [
            tile(Icons.person_outline, 'Mein Konto', AppConfig.accountPath),
            tile(Icons.local_shipping_outlined, 'Bestellung verfolgen', AppConfig.orderTrackingPath),
          ]),
          group('Service', [
            legal(Icons.payments_outlined, AppConfig.shippingPath),
            legal(Icons.assignment_return_outlined, AppConfig.withdrawalPath),
          ]),
          group('Rechtliches', [
            legal(Icons.description_outlined, AppConfig.termsPath),
            legal(Icons.privacy_tip_outlined, AppConfig.privacyPath),
            legal(Icons.info_outline, AppConfig.imprintPath),
          ]),
          group('Website', [
            ListTile(
              leading: const Icon(Icons.open_in_new, color: ArkaColors.gold),
              title: const Text('arkaschmuck.de im Browser öffnen'),
              onTap: () => openExternal(AppConfig.siteUrl),
            ),
          ]),
          const SizedBox(height: 16),
          const Center(
            child: Text('ARKA Schmuck App · Version 1.0', style: TextStyle(color: ArkaColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: ArkaColors.ink, borderRadius: BorderRadius.circular(18)),
      child: const Column(
        children: [
          ArkaWordmark(light: true),
          SizedBox(height: 14),
          Text(
            'Modeschmuck, der den Alltag mitmacht – wasserfest, antiallergen und nickelfrei.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xE6FFFFFF), height: 1.4),
          ),
          SizedBox(height: 14),
          UspRow(light: true),
        ],
      ),
    );
  }
}
