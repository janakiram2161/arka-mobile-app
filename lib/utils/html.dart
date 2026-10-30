const Map<String, String> _namedEntities = {
  '&amp;': '&',
  '&quot;': '"',
  '&apos;': "'",
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
  '&ndash;': '–',
  '&mdash;': '—',
  '&hellip;': '…',
  '&euro;': '€',
  '&auml;': 'ä',
  '&ouml;': 'ö',
  '&uuml;': 'ü',
  '&Auml;': 'Ä',
  '&Ouml;': 'Ö',
  '&Uuml;': 'Ü',
  '&szlig;': 'ß',
  '&rsquo;': '’',
  '&lsquo;': '‘',
  '&rdquo;': '”',
  '&ldquo;': '“',
  '&bdquo;': '„',
  '&times;': '×',
  '&copy;': '©',
  '&reg;': '®',
  '&trade;': '™',
};

final RegExp _numericEntity = RegExp(r'&#([xX]?)([0-9a-fA-F]+);');
final RegExp _namedEntity = RegExp(r'&[a-zA-Z]+;');

/// Decodes HTML entities such as `&#8211;` or `&amp;` in WooCommerce texts.
String decodeEntities(String input) {
  var s = input.replaceAllMapped(_numericEntity, (m) {
    final isHex = (m.group(1) ?? '').isNotEmpty;
    final code = int.tryParse(m.group(2) ?? '', radix: isHex ? 16 : 10);
    if (code == null) return m.group(0) ?? '';
    return String.fromCharCode(code);
  });
  s = s.replaceAllMapped(_namedEntity, (m) {
    final entity = m.group(0) ?? '';
    return _namedEntities[entity] ?? entity;
  });
  return s;
}

/// Turns a WooCommerce HTML description into readable plain text.
String htmlToText(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
  s = s.replaceAll(RegExp(r'</(p|div|h[1-6]|li|tr|ul|ol)>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = decodeEntities(s);
  s = s.replaceAll('\r', '');
  final lines = s.split('\n').map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim()).toList();
  s = lines.join('\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}
