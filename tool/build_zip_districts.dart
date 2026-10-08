/// Builds `zip_districts.json`: which congressional district or districts
/// each ZIP code lies in, so the app can find a user's representative from
/// their ZIP code, offline.
///
/// Run from the repository root **when districts change** (a new Congress,
/// or a state redraws its map), not weekly:
///
/// ```
/// dart run tool/build_zip_districts.dart
/// ```
///
/// The Congress is the one `current_answers.json` lists representatives for
/// (`sources.representatives.congress`), so the map and the names always
/// match. The source is the Census Bureau's ZCTA ↔ congressional district
/// relationship file for that Congress.
///
/// Nothing is written if the download fails or a check does not pass.
library;

import 'dart:convert';
import 'dart:io';

import 'src/official_sources.dart';
import 'src/zip_districts.dart';

const _jurisdictionsPath = 'tool/data/jurisdictions.json';
const _currentAnswersPath = 'current_answers.json';

/// At the repository root, where GitHub Pages serves it to the app.
const _outputPath = 'zip_districts.json';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    _fail('Run this from the repository root (where pubspec.yaml is).');
  }

  final currentAnswers = _readJson(_currentAnswersPath);
  final congress =
      (currentAnswers['sources'] as Map)['representatives']['congress'] as int;
  final stateByFips = {
    for (final place
        in (_readJson(_jurisdictionsPath)['jurisdictions'] as List)
            .cast<Map<String, dynamic>>())
      place['fips'] as String: place['code'] as String,
  };

  final url = censusZipDistrictsUrl(congress);
  stdout.writeln(
    'Reading the Census ZIP code ↔ district file (${congress}th Congress)…',
  );
  final zips = parseZipDistricts(
    await download(url),
    congress: congress,
    stateByFips: stateByFips,
  );

  final problems = _check(zips, _districtsWithRepresentatives(currentAnswers));
  if (problems.isNotEmpty) {
    _fail(
      'Nothing written. ${problems.length} problem(s):\n${problems.map((p) => '  - $p').join('\n')}',
    );
  }

  final today = DateTime.now().toIso8601String().substring(0, 10);
  File(_outputPath).writeAsStringSync(
    _encode(
      header: {
        'schema_version': 1,
        'congress': congress,
        'built': today,
        'source': {
          'url': url,
          'name':
              'U.S. Census Bureau, ZCTA to ${congress}th Congressional District relationship file',
        },
      },
      zips: zips,
    ),
  );
  final split = zips.values.where((districts) => districts.length > 1).length;
  stdout.writeln(
    'Wrote $_outputPath: ${zips.length} ZIP codes, $split in more than one district.',
  );
}

/// Every district `current_answers.json` has a seat for, as `"NY-7"`.
Set<String> _districtsWithRepresentatives(
  Map<String, dynamic> currentAnswers,
) => {
  for (final place
      in (currentAnswers['jurisdictions'] as List).cast<Map<String, dynamic>>())
    for (final seat
        in (place['representatives'] as List).cast<Map<String, dynamic>>())
      '${place['code']}-${seat['district']}',
};

/// The map and the representatives must describe the same districts: every
/// seat reachable from some ZIP code, and no ZIP code pointing at a district
/// with no seat (which would mean the two are for different Congresses).
List<String> _check(Map<String, List<String>> zips, Set<String> seats) {
  final mapped = zips.values.expand((districts) => districts).toSet();
  return [
    if (zips.length < 30000)
      'Only ${zips.length} ZIP codes; expected about 33,000.',
    for (final seat in seats.difference(mapped).toList()..sort())
      'No ZIP code in $seat.',
    for (final district in mapped.difference(seats).toList()..sort())
      'ZIP codes in $district, which has no seat in $_currentAnswersPath.',
  ];
}

/// The header fields, then one ZIP code per line, so a redrawn map shows up
/// in the diff as the ZIP codes that moved.
String _encode({
  required Map<String, Object> header,
  required Map<String, List<String>> zips,
}) {
  final buffer = StringBuffer('{\n');
  for (final MapEntry(:key, :value) in header.entries) {
    buffer.writeln('  ${jsonEncode(key)}: ${jsonEncode(value)},');
  }
  buffer.writeln('  "zips": {');
  final lines = [
    for (final MapEntry(key: zip, value: districts) in zips.entries)
      '    ${jsonEncode(zip)}: ${jsonEncode(districts)}',
  ];
  buffer
    ..writeln(lines.join(',\n'))
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
