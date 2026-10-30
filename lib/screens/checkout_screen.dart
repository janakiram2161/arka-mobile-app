import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../state/stores.dart';
import '../utils/html.dart';
import 'web_page_screen.dart';

/// Hands the app cart over to the real shop and opens the shop's own checkout,
/// so every payment method of the website (PayPal, WooPayments …) and the
/// legal checkout texts stay exactly as on arkaschmuck.de.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

enum _Stage { transferring, checkout, done, failed }

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final WebViewController _controller;
  _Stage _stage = _Stage.transferring;
  bool _injected = false;
  String _error = '';
  double _progress = 0;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ArkaColors.white)
      ..addJavaScriptChannel('ArkaApp', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageFinished: _onPageFinished,
          onNavigationRequest: handleWebNavigation,
        ),
      );
    _start(initial: true);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  void _start({bool initial = false}) {
    _injected = false;
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 40), () {
      if (mounted && _stage == _Stage.transferring) {
        _fail('Die Verbindung zum Shop dauert zu lange.');
      }
    });
    _stage = _Stage.transferring;
    _error = '';
    if (!initial) setState(() {});
    _controller.loadRequest(Uri.parse(AppConfig.url(AppConfig.cartPath)));
  }

  String _script() {
    final items = jsonEncode(CartStore.instance.items.map((i) => i.toStoreApiItem()).toList());
    return '''
(async function () {
  try {
    const items = $items;
    const base = '/wp-json/wc/store/v1';
    let nonce = '';
    const pick = (res) => { const n = res.headers.get('Nonce') || res.headers.get('X-WC-Store-API-Nonce'); if (n) { nonce = n; } };
    const headers = () => ({ 'Content-Type': 'application/json', 'Accept': 'application/json', 'Nonce': nonce });
    const first = await fetch(base + '/cart', { credentials: 'same-origin', headers: { 'Accept': 'application/json' } });
    pick(first);
    const cleared = await fetch(base + '/cart/items', { method: 'DELETE', credentials: 'same-origin', headers: headers() });
    pick(cleared);
    for (const item of items) {
      const res = await fetch(base + '/cart/add-item', { method: 'POST', credentials: 'same-origin', headers: headers(), body: JSON.stringify(item) });
      pick(res);
      if (!res.ok) {
        let msg = 'HTTP ' + res.status;
        try { const j = await res.json(); if (j && j.message) { msg = j.message; } } catch (e) {}
        ArkaApp.postMessage('error:' + msg);
        return;
      }
    }
    ArkaApp.postMessage('ok');
    window.location.href = '${AppConfig.checkoutPath}';
  } catch (e) {
    ArkaApp.postMessage('error:' + e);
  }
})();
''';
  }

  void _onPageFinished(String url) {
    if (!mounted) return;
    if (url.contains('order-received')) {
      CartStore.instance.clear();
      setState(() => _stage = _Stage.done);
      return;
    }
    if (_stage == _Stage.transferring && !_injected) {
      _injected = true;
      _controller.runJavaScript(_script());
      return;
    }
    if (_stage == _Stage.transferring && url.contains(AppConfig.checkoutPath)) {
      _timeout?.cancel();
      setState(() => _stage = _Stage.checkout);
    }
  }

  void _onMessage(JavaScriptMessage message) {
    if (!mounted) return;
    final text = message.message;
    if (text.startsWith('error:')) {
      _fail(htmlToText(text.substring(6)));
    }
  }

  void _fail(String message) {
    _timeout?.cancel();
    setState(() {
      _stage = _Stage.failed;
      _error = message;
    });
  }

  Future<void> _back() async {
    if (_stage == _Stage.checkout && await _controller.canGoBack()) {
      final url = await _controller.currentUrl() ?? '';
      if (!url.contains(AppConfig.checkoutPath)) {
        await _controller.goBack();
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArkaColors.cream,
        foregroundColor: ArkaColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: const Text('Kasse', style: TextStyle(fontSize: 17)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _progress < 1 && _stage != _Stage.failed
              ? LinearProgressIndicator(value: _progress, minHeight: 2, color: ArkaColors.gold, backgroundColor: ArkaColors.sand)
              : const SizedBox(height: 2),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_stage == _Stage.transferring)
            const _Overlay(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: ArkaColors.gold),
                  SizedBox(height: 18),
                  Text('Dein Warenkorb wird an den Shop übergeben …', textAlign: TextAlign.center),
                ],
              ),
            ),
          if (_stage == _Stage.failed)
            _Overlay(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: ArkaColors.sale, size: 40),
                  const SizedBox(height: 12),
                  const Text('Der Warenkorb konnte nicht übertragen werden.',
                      textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600)),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: ArkaColors.muted)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: ArkaColors.ink),
                    onPressed: _start,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
          if (_stage == _Stage.done)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: ArkaColors.ink, minimumSize: const Size.fromHeight(50)),
                  onPressed: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    rootTab.value = 0;
                  },
                  child: const Text('Zurück zum Shop'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: ArkaColors.cream,
        child: Center(child: Padding(padding: const EdgeInsets.all(32), child: child)),
      ),
    );
  }
}
