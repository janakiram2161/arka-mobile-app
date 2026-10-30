import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';

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

/// Links that are not http(s) (mailto:, tel:, intent:, paypal app links …)
/// are handed to the phone; everything else stays inside the app.
NavigationDecision handleWebNavigation(NavigationRequest request) {
  final uri = Uri.tryParse(request.url);
  if (uri == null) return NavigationDecision.prevent;
  if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
    return NavigationDecision.navigate;
  }
  openExternal(request.url);
  return NavigationDecision.prevent;
}

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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ArkaColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onNavigationRequest: handleWebNavigation,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
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
      body: WebViewWidget(controller: _controller),
    );
  }
}
