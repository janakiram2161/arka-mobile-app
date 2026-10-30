import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../widgets/common.dart';
import 'web_page_screen.dart';

void openLegalPage(BuildContext context, LegalPage page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LegalPageScreen(page: page)));
}

/// Opens a website link the right way: legal pages in the app, everything
/// else in the phone's browser / mail / WhatsApp app.
Future<bool> handleContentLink(BuildContext context, String url) async {
  final legal = AppConfig.legalForUrl(url);
  if (legal != null) {
    openLegalPage(context, legal);
    return true;
  }
  await openExternal(url);
  return true;
}

class _LegalContent {
  _LegalContent(this.html, this.modified);
  final String html;
  final String modified;
}

/// AGB, Datenschutz, Impressum etc. shown natively in the app. The text is
/// loaded live from the same WordPress page that the website shows, so it is
/// always identical; the last copy is kept on the phone for offline use.
class LegalPageScreen extends StatefulWidget {
  const LegalPageScreen({super.key, required this.page});
  final LegalPage page;

  @override
  State<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends State<LegalPageScreen> {
  _LegalContent? _content;
  String? _error;
  bool _loading = true;

  String get _cacheKey => 'legal_page_${widget.page.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null && _content == null && mounted) {
      try {
        final j = jsonDecode(cached) as Map<String, dynamic>;
        setState(() => _content = _LegalContent(j['html'] as String, (j['modified'] ?? '') as String));
      } catch (_) {}
    }
    try {
      final uri = Uri.parse('${AppConfig.siteUrl}/wp-json/wp/v2/pages/${widget.page.id}')
          .replace(queryParameters: const {'_fields': 'content,modified'});
      final res = await http.get(uri, headers: const {'Accept': 'application/json'}).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final html = cleanPageHtml(((j['content'] as Map?)?['rendered'] ?? '').toString());
      final modified = (j['modified'] ?? '').toString();
      await prefs.setString(_cacheKey, jsonEncode({'html': html, 'modified': modified}));
      if (!mounted) return;
      setState(() {
        _content = _LegalContent(html, modified);
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (_content == null) setState(() => _error = 'Die Seite konnte nicht geladen werden. Bitte Internetverbindung prüfen.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    Widget body;
    if (content != null) {
      body = RefreshIndicator(
        color: ArkaColors.gold,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: HtmlWidget(
                content.html,
                textStyle: const TextStyle(fontSize: 15, height: 1.55, color: ArkaColors.ink),
                customStylesBuilder: (element) {
                  switch (element.localName) {
                    case 'h1':
                      return {'font-size': '22px', 'font-weight': '600', 'margin': '16px 0 8px 0'};
                    case 'h2':
                      return {'font-size': '18px', 'font-weight': '600', 'margin': '20px 0 6px 0'};
                    case 'h3':
                    case 'h4':
                      return {'font-size': '16px', 'font-weight': '600', 'margin': '16px 0 4px 0'};
                    case 'a':
                      return {'color': '#B08D57', 'text-decoration': 'underline'};
                    case 'p':
                      return {'margin': '0 0 10px 0'};
                  }
                  return null;
                },
                onTapUrl: (url) => handleContentLink(context, url),
              ),
            ),
            if (content.modified.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Stand: ${_formatDate(content.modified)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: ArkaColors.muted),
              ),
            ],
          ],
        ),
      );
    } else if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: ArkaColors.gold));
    } else {
      body = ErrorView(
        message: _error ?? 'Die Seite konnte nicht geladen werden.',
        onRetry: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }
    return Scaffold(
      appBar: arkaAppBar(context, title: Text(widget.page.title, style: const TextStyle(fontSize: 18))),
      body: body,
    );
  }
}

/// Removes page-builder wrappers and inline styles so the text uses the app's
/// typography, while keeping every word of the website text.
String cleanPageHtml(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'\s(style|class|id|data-[\w-]+)="[^"]*"', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<h[1-6]>\s*(<br\s*/?>\s*)*</h[1-6]>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<p>\s*(&nbsp;|\s)*</p>', caseSensitive: false), '');
  return decodeLeadingWhitespace(s.trim());
}

String decodeLeadingWhitespace(String s) => s.replaceAll(RegExp(r'^\s+', multiLine: true), '');
