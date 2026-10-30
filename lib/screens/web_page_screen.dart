import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../state/stores.dart';
import 'legal_page_screen.dart';

void openWebPage(BuildContext context, String title, String url) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => WebPageScreen(title: title, url: url)),
  );
}

Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// CSS added to every shop page shown inside the app: hides the website's own
/// promo bar, header, menus, footer and cookie banner so only the content
/// (checkout form, account page …) is visible.
const String appWebCss = '''
.pls-promo-bar, #header, .pls-site-header, #footer, .pls-site-footer, .pls-mobile-navbar, .pls-back-to-top,
.pls-mobile-menu, .pls-search-popup, .pls-minicart-slide, .pls-mask-overaly, #wpconsent-root,
.pls-page-title, #page-title, .woocommerce-breadcrumb, .gt_float_switcher, .gtranslate_wrapper,
.elementor-location-header, .elementor-location-footer { display: none !important; }
html, body { margin-top: 0 !important; padding-top: 0 !important; padding-bottom: 0 !important; }
#page { padding-top: 0 !important; margin-top: 0 !important; }
#main-content { padding-top: 12px !important; margin-top: 0 !important; }
''';

/// JavaScript that installs [appWebCss] as early and as often as needed.
String appWebCssScript() {
  final css = appWebCss.replaceAll('\\', '\\\\').replaceAll('`', '\\`').replaceAll('\n', ' ');
  return '''
(function () {
  function add() {
    if (document.getElementById('arka-app-css')) return;
    var s = document.createElement('style');
    s.id = 'arka-app-css';
    s.textContent = `$css`;
    (document.head || document.documentElement).appendChild(s);
  }
  add();
  document.addEventListener('DOMContentLoaded', add);
})();
''';
}

enum ShopLinkTarget { stay, legal, cart, external, blocked }

/// Decides what happens when a page inside the app tries to open [url].
/// [allowedPaths] are the shop paths that may be shown in this web view.
ShopLinkTarget classifyShopLink(String url, List<String> allowedPaths) {
  final uri = Uri.tryParse(url);
  if (uri == null) return ShopLinkTarget.blocked;
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    if (uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob' || uri.scheme == 'javascript') {
      return ShopLinkTarget.stay;
    }
    return ShopLinkTarget.external;
  }
  if (!AppConfig.isShopHost(uri.host)) {
    // Payment providers (PayPal, Klarna, card 3-D Secure …) stay in the app.
    return ShopLinkTarget.stay;
  }
  if (AppConfig.legalForUrl(url) != null) return ShopLinkTarget.legal;
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  if (path == AppConfig.cartPath) return ShopLinkTarget.cart;
  if (uri.queryParameters.containsKey('wc-ajax') ||
      path.startsWith('/wp-json/') ||
      path.startsWith('/wc-api/') ||
      path.startsWith('/wp-admin/admin-ajax.php')) {
    return ShopLinkTarget.stay;
  }
  for (final p in allowedPaths) {
    if (path.startsWith(p)) return ShopLinkTarget.stay;
  }
  return ShopLinkTarget.blocked;
}

/// Account, order tracking and similar shop pages, shown in the app without
/// the website's header and footer.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.title, required this.url});
  final String title;
  final String url;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _ready = false;

  List<String> get _allowedPaths {
    final own = Uri.tryParse(widget.url)?.path ?? '/';
    return [own, AppConfig.accountPath, AppConfig.orderTrackingPath, '/product/', AppConfig.checkoutPath];
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ArkaColors.cream)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageStarted: (_) => _controller.runJavaScript(appWebCssScript()).catchError((_) {}),
          onPageFinished: (_) async {
            await _controller.runJavaScript(appWebCssScript()).catchError((_) {});
            if (mounted) setState(() => _ready = true);
          },
          onNavigationRequest: _onNavigation,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    if (!request.isMainFrame) return NavigationDecision.navigate;
    switch (classifyShopLink(request.url, _allowedPaths)) {
      case ShopLinkTarget.stay:
        return NavigationDecision.navigate;
      case ShopLinkTarget.legal:
        openLegalPage(context, AppConfig.legalForUrl(request.url)!);
        return NavigationDecision.prevent;
      case ShopLinkTarget.cart:
        Navigator.of(context).popUntil((r) => r.isFirst);
        rootTab.value = 3;
        return NavigationDecision.prevent;
      case ShopLinkTarget.external:
        openExternal(request.url);
        return NavigationDecision.prevent;
      case ShopLinkTarget.blocked:
        final path = Uri.tryParse(request.url)?.path ?? '/';
        if (path == '/' || path.isEmpty) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          rootTab.value = 0;
        }
        return NavigationDecision.prevent;
    }
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArkaColors.cream,
        foregroundColor: ArkaColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Schließen',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 1
              ? LinearProgressIndicator(value: _progress, minHeight: 2, color: ArkaColors.gold, backgroundColor: ArkaColors.sand)
              : const SizedBox(height: 2),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (!_ready)
            const Positioned.fill(
              child: ColoredBox(
                color: ArkaColors.cream,
                child: Center(child: CircularProgressIndicator(color: ArkaColors.gold)),
              ),
            ),
        ],
      ),
    );
  }
}
