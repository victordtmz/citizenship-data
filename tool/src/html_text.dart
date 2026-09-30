/// Turns an HTML page into its visible lines of text, one element per line,
/// trimmed, with empty lines dropped. Enough to read names off official
/// pages; not a general HTML parser.
List<String> htmlToLines(String html) {
  final withoutCode = html.replaceAll(
    RegExp(r'<script.*?</script>|<style.*?</style>', dotAll: true),
    '',
  );
  final text = _decodeEntities(
    withoutCode.replaceAll(RegExp(r'<[^>]+>'), '\n'),
  );
  return text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

const _namedEntities = {
  'amp': '&',
  'quot': '"',
  'apos': "'",
  'lt': '<',
  'gt': '>',
  'nbsp': ' ',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
  'ndash': '–',
  'mdash': '—',
};

/// Decodes `&amp;`, `&rsquo;`, `&#8217;` and `&#x2019;` style entities.
String _decodeEntities(String text) => text.replaceAllMapped(
  RegExp(r'&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'),
  (match) {
    final entity = match.group(1)!;
    if (entity.startsWith('#x')) {
      return String.fromCharCode(int.parse(entity.substring(2), radix: 16));
    }
    if (entity.startsWith('#')) {
      return String.fromCharCode(int.parse(entity.substring(1)));
    }
    return _namedEntities[entity] ?? match.group(0)!;
  },
);
