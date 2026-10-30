import 'package:arka_schmuck/config.dart';
import 'package:arka_schmuck/models/models.dart';
import 'package:arka_schmuck/screens/legal_page_screen.dart';
import 'package:arka_schmuck/screens/web_page_screen.dart';
import 'package:arka_schmuck/utils/html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes WooCommerce entities', () {
    expect(decodeEntities('Ring &#8211; Gold &amp; Silber'), 'Ring – Gold & Silber');
    expect(htmlToText('<p>Wasserfest<br>Nickelfrei</p>'), 'Wasserfest\nNickelfrei');
  });

  test('formats euro prices from minor units', () {
    const money = Money(suffix: ' €', decimalSeparator: ',', thousandSeparator: '.');
    expect(money.format(1999), '19,99 €');
    expect(money.format(123456), '1.234,56 €');
  });

  test('parses a Store API product', () {
    final p = Product.fromJson({
      'id': 3219,
      'name': 'Elegant Butterfly Gold Ring',
      'type': 'simple',
      'permalink': 'https://arkaschmuck.de/product/x/',
      'short_description': '<p>Wasserfest</p>',
      'description': '',
      'on_sale': true,
      'prices': {
        'price': '1499',
        'regular_price': '1999',
        'sale_price': '1499',
        'currency_code': 'EUR',
        'currency_minor_unit': 2,
        'currency_prefix': '',
        'currency_suffix': ' €',
        'currency_decimal_separator': ',',
        'currency_thousand_separator': '.',
        'price_range': null,
      },
      'images': [
        {'src': 'https://arkaschmuck.de/a.webp', 'thumbnail': 'https://arkaschmuck.de/a-325.webp', 'alt': ''}
      ],
      'categories': [
        {'id': 84, 'name': 'Ringe', 'slug': 'ringe'}
      ],
      'attributes': [],
      'variations': [],
      'is_purchasable': true,
      'is_in_stock': true,
      'add_to_cart': {'maximum': 9999},
    });
    expect(p.prices.isReduced, isTrue);
    expect(p.thumbnailUrl, 'https://arkaschmuck.de/a-325.webp');
    expect(p.canBuyInApp, isTrue);
    expect(p.maxQuantity, 99);
  });

  test('website links open the right place in the app', () {
    expect(AppConfig.legalForUrl('http://www.arkaschmuck.de/widerrufsbelehrung/')?.id, 1792);
    expect(AppConfig.legalForUrl('https://arkaschmuck.de/agb')?.id, 1765);
    expect(AppConfig.legalForUrl('https://example.com/agb/'), isNull);
    const allowed = ['/checkout/'];
    expect(classifyShopLink('https://arkaschmuck.de/checkout/', allowed), ShopLinkTarget.stay);
    expect(classifyShopLink('https://arkaschmuck.de/checkout/order-received/123/?key=x', allowed), ShopLinkTarget.stay);
    expect(classifyShopLink('https://arkaschmuck.de/cart/', allowed), ShopLinkTarget.cart);
    expect(classifyShopLink('https://arkaschmuck.de/datenschutzerklarung/', allowed), ShopLinkTarget.legal);
    expect(classifyShopLink('https://arkaschmuck.de/shop/', allowed), ShopLinkTarget.blocked);
    expect(classifyShopLink('https://www.paypal.com/checkoutnow?token=1', allowed), ShopLinkTarget.stay);
    expect(classifyShopLink('mailto:info@arkaschmuck.de', allowed), ShopLinkTarget.external);
    expect(classifyShopLink('https://arkaschmuck.de/?wc-ajax=update_order_review', allowed), ShopLinkTarget.stay);
  });

  test('page HTML is cleaned but keeps the text', () {
    final html = cleanPageHtml(
        '<div class="elementor" data-id="1"><h1><b>Impressum</b></h1><p><span style="font-weight: 400;">Sandhofer Straße</span></p><h2 data-start="1"><br /><br /></h2></div>');
    expect(html.contains('style='), isFalse);
    expect(html.contains('class='), isFalse);
    expect(html.contains('Sandhofer Straße'), isTrue);
    expect(html.contains('<h2>'), isFalse);
  });
}
