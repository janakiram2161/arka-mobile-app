import 'package:flutter/material.dart';

/// Central settings for the ARKA Schmuck app.
class AppConfig {
  static const String siteUrl = 'https://arkaschmuck.de';

  /// WooCommerce Store API (public, read-only product data – no keys needed).
  static const String apiBase = '$siteUrl/wp-json/wc/store/v1';

  static const String cartPath = '/cart/';
  static const String checkoutPath = '/checkout/';
  static const String accountPath = '/my-account/';
  static const String orderTrackingPath = '/order-tracking/';

  static const String shippingPath = '/versand-and-zahlung/';
  static const String withdrawalPath = '/widerrufsbelehrung/';
  static const String termsPath = '/agb/';
  static const String privacyPath = '/datenschutzerklarung/';
  static const String imprintPath = '/impressum/';

  /// Categories that should never be shown in the app.
  static const Set<String> hiddenCategorySlugs = {'uncategorized'};

  static String url(String path) => '$siteUrl$path';

  /// Legal and service pages shown inside the app (text loaded live from the
  /// WordPress page with this ID, so it is always the same as on the website).
  static const List<LegalPage> legalPages = [
    LegalPage(1786, 'Versand & Zahlung', '/versand-and-zahlung/'),
    LegalPage(1792, 'Widerrufsbelehrung', '/widerrufsbelehrung/'),
    LegalPage(1765, 'AGB', '/agb/'),
    LegalPage(2193, 'Datenschutzerklärung', '/datenschutzerklarung/'),
    LegalPage(1776, 'Impressum', '/impressum/'),
  ];

  static LegalPage legal(String path) => legalPages.firstWhere((p) => p.path == path);

  /// Finds the in-app legal page for a website link, e.g.
  /// http://www.arkaschmuck.de/widerrufsbelehrung/ → Widerrufsbelehrung.
  static LegalPage? legalForUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !isShopHost(uri.host)) return null;
    var path = uri.path;
    if (!path.endsWith('/')) path = '$path/';
    for (final p in legalPages) {
      if (p.path == path) return p;
    }
    return null;
  }

  static bool isShopHost(String host) => host == 'arkaschmuck.de' || host == 'www.arkaschmuck.de';

  /// The four banners at the top of the start page (images from the website).
  static const List<HomeSlide> slides = [
    HomeSlide(
      image: '$siteUrl/wp-content/uploads/2026/02/Gemini_Generated_Image_9anlw09anlw09anl.webp',
      title: 'Neu eingetroffen',
      alignment: Alignment(0.85, 0),
    ),
    HomeSlide(
      image: '$siteUrl/wp-content/uploads/2026/02/Rings.png',
      title: 'Ringe',
      categoryId: 84,
    ),
    HomeSlide(
      image: '$siteUrl/wp-content/uploads/2026/02/Necklace.png',
      title: 'Ketten',
      categoryId: 88,
    ),
    HomeSlide(
      image: '$siteUrl/wp-content/uploads/2026/02/Earrings.png',
      title: 'Ohrringe',
      categoryId: 87,
    ),
  ];
}

class LegalPage {
  const LegalPage(this.id, this.title, this.path);
  final int id;
  final String title;
  final String path;
}

class HomeSlide {
  const HomeSlide({required this.image, required this.title, this.categoryId, this.alignment = Alignment.center});
  final String image;

  /// Title of the product list the slide opens.
  final String title;

  /// Category opened when the slide is tapped (null = all products, newest first).
  final int? categoryId;
  final Alignment alignment;
}

class ArkaColors {
  static const Color ink = Color(0xFF1C1B19);
  static const Color gold = Color(0xFFB08D57);
  static const Color goldSoft = Color(0x2EB08D57);
  static const Color cream = Color(0xFFFAF7F2);
  static const Color sand = Color(0xFFEFEAE2);
  static const Color muted = Color(0xFF7A746B);
  static const Color sale = Color(0xFFB3261E);
  static const Color white = Color(0xFFFFFFFF);
}

ThemeData buildArkaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ArkaColors.gold,
    brightness: Brightness.light,
    primary: ArkaColors.ink,
    onPrimary: ArkaColors.white,
    secondary: ArkaColors.gold,
    onSecondary: ArkaColors.white,
    surface: ArkaColors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ArkaColors.cream,
  );
}

/// Shared app bar style (kept here instead of ThemeData component themes so the
/// code stays compatible across Flutter versions).
PreferredSizeWidget arkaAppBar(
  BuildContext context, {
  Widget? title,
  List<Widget>? actions,
  bool wordmark = false,
}) {
  return AppBar(
    backgroundColor: ArkaColors.cream,
    foregroundColor: ArkaColors.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    title: wordmark ? const ArkaWordmark() : title,
    actions: actions,
  );
}

/// The ARKA logo (from the brand artwork). [light] is the white version for
/// dark backgrounds.
class ArkaWordmark extends StatelessWidget {
  const ArkaWordmark({super.key, this.light = false, this.height = 34});
  final bool light;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      light ? 'assets/images/arka_logo_light.png' : 'assets/images/arka_logo_dark.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'ARKA',
    );
  }
}
