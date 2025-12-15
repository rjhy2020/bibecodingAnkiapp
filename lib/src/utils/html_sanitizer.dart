String stripHtmlToPlainText(String input) {
  var s = input;

  // Remove script/style blocks completely (they often contain huge JS/CSS).
  s = s.replaceAll(
    RegExp(r'<script\b[^>]*>[\s\S]*?</script>', caseSensitive: false),
    '',
  );
  s = s.replaceAll(
    RegExp(r'<style\b[^>]*>[\s\S]*?</style>', caseSensitive: false),
    '',
  );

  // Dart RegExp does not support inline flags like (?i). Use `caseSensitive: false`.
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');

  s = s.replaceAll(RegExp(r'<[^>]+>'), '');

  s = s.replaceAll('&nbsp;', ' ');
  s = s.replaceAll('&amp;', '&');
  s = s.replaceAll('&lt;', '<');
  s = s.replaceAll('&gt;', '>');
  s = s.replaceAll('&quot;', '"');
  s = s.replaceAll('&#39;', "'");

  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return s.trim();
}
