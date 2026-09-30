/// Compares the published current answers with a freshly built copy and
/// describes, in plain words, every name that changed: the body of the pull
/// request you review before anything is published.
///
/// Only names count as changes: officeholders, senators, governors,
/// capitals, and which places are listed. The dates (`checked`, and when
/// each source last updated itself) change almost every week and are not
/// worth a review.
List<String> describeNameChanges(
  Map<String, dynamic> published,
  Map<String, dynamic> fresh,
) {
  final changes = <String>[];

  if (published['schema_version'] != fresh['schema_version']) {
    changes.add(
      '**File format** version ${published['schema_version']} → ${fresh['schema_version']}. '
      'The app ignores a version it does not know: release an app that reads it first.',
    );
  }

  changes.addAll(
    _officeholderChanges(
      (published['officeholders'] as Map).cast<String, dynamic>(),
      (fresh['officeholders'] as Map).cast<String, dynamic>(),
    ),
  );
  changes.addAll(
    _placeChanges(
      _placesByCode(published['jurisdictions'] as List),
      _placesByCode(fresh['jurisdictions'] as List),
    ),
  );
  return changes;
}

const _officeTitles = {
  'president': 'President',
  'vice_president': 'Vice President',
  'speaker_of_the_house': 'Speaker of the House',
  'chief_justice': 'Chief Justice',
};

List<String> _officeholderChanges(
  Map<String, dynamic> published,
  Map<String, dynamic> fresh,
) => [
  for (final office in {...published.keys, ...fresh.keys})
    if (!_sameList(published[office], fresh[office]))
      '**${_officeTitles[office] ?? office}**: ${_names(published[office])} → ${_names(fresh[office])}',
];

List<String> _placeChanges(
  Map<String, Map<String, dynamic>> published,
  Map<String, Map<String, dynamic>> fresh,
) {
  final changes = <String>[];
  for (final code in {...published.keys, ...fresh.keys}) {
    final before = published[code];
    final after = fresh[code];
    if (before == null || after == null) {
      final place = (before ?? after)!['name'];
      changes.add('**$place** ${before == null ? 'added' : 'removed'}');
      continue;
    }
    for (final field in ['name', 'kind', 'capital', 'governor', 'senators']) {
      if (!_sameValue(before[field], after[field])) {
        changes.add(
          '**${after['name']} $field**: ${_names(before[field])} → ${_names(after[field])}',
        );
      }
    }
  }
  return changes;
}

Map<String, Map<String, dynamic>> _placesByCode(List places) => {
  for (final place in places.cast<Map<String, dynamic>>())
    place['code'] as String: place,
};

bool _sameValue(Object? a, Object? b) =>
    a is List || b is List ? _sameList(a, b) : a == b;

bool _sameList(Object? a, Object? b) {
  if (a is! List || b is! List || a.length != b.length) return a == b;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// "Greg Abbott", "John Cornyn, Ted Cruz", or "(none)".
String _names(Object? value) => switch (value) {
  null => '(none)',
  List(isEmpty: true) => '(none)',
  List list => list.join(', '),
  _ => '$value',
};
