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

class ArkaWordmark extends StatelessWidget {
  const ArkaWordmark({super.key, this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? ArkaColors.white : ArkaColors.ink;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ARKA',
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 8,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'SCHMUCK',
          style: TextStyle(
            color: ArkaColors.gold,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
