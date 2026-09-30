import 'dart:convert';

import 'package:test/test.dart';

import '../tool/src/describe_changes.dart';

void main() {
  Map<String, dynamic> sample() => jsonDecode('''
    {
      "schema_version": 1,
      "checked": "2026-09-29",
      "sources": { "senators": { "source_updated": "2026-09-23" } },
      "officeholders": { "president": ["Donald J. Trump", "Donald Trump", "Trump"] },
      "jurisdictions": [
        { "code": "TX", "name": "Texas", "kind": "state", "capital": "Austin",
          "governor": "Greg Abbott", "senators": ["John Cornyn", "Ted Cruz"] }
      ]
    }''') as Map<String, dynamic>;

  test('no name changed: nothing to describe', () {
    expect(describeNameChanges(sample(), sample()), isEmpty);
  });

  test('dates alone are not a change worth a review', () {
    final fresh = sample()
      ..['checked'] = '2026-10-06'
      ..['sources'] = {
        'senators': {'source_updated': '2026-10-01'},
      };

    expect(describeNameChanges(sample(), fresh), isEmpty);
  });

  test('a new governor', () {
    final fresh = sample();
    (fresh['jurisdictions'] as List).first['governor'] = 'Jane Smith';

    expect(describeNameChanges(sample(), fresh), [
      '**Texas governor**: Greg Abbott → Jane Smith',
    ]);
  });

  test('a new senator', () {
    final fresh = sample();
    (fresh['jurisdictions'] as List).first['senators'] = [
      'Ted Cruz',
      'Ann Other',
    ];

    expect(describeNameChanges(sample(), fresh), [
      '**Texas senators**: John Cornyn, Ted Cruz → Ted Cruz, Ann Other',
    ]);
  });

  test('a new officeholder, with every accepted form', () {
    final fresh = sample()
      ..['officeholders'] = {
        'president': ['New Name', 'Name'],
      };

    expect(describeNameChanges(sample(), fresh), [
      '**President**: Donald J. Trump, Donald Trump, Trump → New Name, Name',
    ]);
  });

  test('a place that disappears is called out', () {
    final fresh = sample()..['jurisdictions'] = [];

    expect(describeNameChanges(sample(), fresh), ['**Texas** removed']);
  });
}
