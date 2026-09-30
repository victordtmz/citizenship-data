/// Rebuilds `current_answers.json`: the people and places behind
/// the questions whose answers change with elections or depend on where the
/// applicant lives.
///
/// Run from the repository root (the weekly GitHub Action does this):
///
/// ```
/// dart run tool/build_current_answers.dart
/// ```
///
/// Every name is downloaded from the official page USCIS points to:
///
/// | Answer | Source |
/// | --- | --- |
/// | President, Vice President, Speaker, Chief Justice | uscis.gov/citizenship/testupdates |
/// | Senators | senate.gov (the Senate's own XML list) |
/// | Governors | usa.gov/states-and-territories, one page per state |
/// | Capitals | the USCIS study guide map, in `tool/data/jurisdictions.json` |
///
/// Nothing is written if any source fails or any check does not pass.
library;

import 'dart:convert';
import 'dart:io';

import 'src/official_sources.dart';

const _jurisdictionsPath = 'tool/data/jurisdictions.json';
const _officesPath = 'tool/data/offices.json';

/// At the repository root, where GitHub Pages serves it to the app.
const _outputPath = 'current_answers.json';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    _fail('Run this from the repository root (where pubspec.yaml is).');
  }

  final input = jsonDecode(
    File(_jurisdictionsPath).readAsStringSync(),
  ) as Map<String, dynamic>;
  final jurisdictions = (input['jurisdictions'] as List)
      .cast<Map<String, dynamic>>();
  final officeByQuestion = _readOffices();
  final today = DateTime.now().toIso8601String().substring(0, 10);

  stdout.writeln('Reading USCIS test updates…');
  final officeholders = parseUscisTestUpdates(
    await download(OfficialSources.uscisTestUpdates),
    officeByQuestion: officeByQuestion,
  );

  stdout.writeln('Reading the Senate list…');
  final senate = parseSenateXml(await download(OfficialSources.senators));

  stdout.writeln(
    'Reading ${jurisdictions.length} usa.gov pages for governors…',
  );
  final governors = await _readGovernors(jurisdictions);

  final problems = [
    ..._checkOfficeholders(officeholders, officeByQuestion.values),
    ..._checkJurisdictions(jurisdictions, senate, governors),
  ];
  if (problems.isNotEmpty) {
    _fail(
      'Nothing written. ${problems.length} problem(s):\n${problems.map((p) => '  - $p').join('\n')}',
    );
  }

  final asset = {
    'schema_version': 1,
    'checked': today,
    'sources': {
      'officeholders': {
        'url': OfficialSources.uscisTestUpdates,
        'source_updated': officeholders.pageUpdated,
      },
      'senators': {
        'url': OfficialSources.senators,
        'source_updated': senate.listUpdated,
      },
      'governors': {'url': OfficialSources.usaGovStates},
      'capitals': {'reference': input['capitals_source']},
    },
    'officeholders': {
      for (final office in officeByQuestion.values)
        office: officeholders.namesByOffice[office],
    },
    'jurisdictions': [
      for (final jurisdiction in jurisdictions)
        {
          'code': jurisdiction['code'],
          'name': jurisdiction['name'],
          'kind': jurisdiction['kind'],
          'capital': jurisdiction['capital'],
          'governor': governors[jurisdiction['code']],
          'senators':
              senate.namesByState[jurisdiction['code']] ?? const <String>[],
        },
    ],
  };

  File(
    _outputPath,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(asset)}\n');
  stdout.writeln('Wrote $_outputPath, checked $today.');
}

/// The governor of each state and territory, by code. D.C. has none: USCIS
/// says D.C. residents should answer that D.C. does not have a governor, so
/// its page (which lists the mayor) is not read.
Future<Map<String, String?>> _readGovernors(
  List<Map<String, dynamic>> jurisdictions,
) async {
  final governors = <String, String?>{};
  for (final jurisdiction in jurisdictions) {
    final code = jurisdiction['code'] as String;
    if (jurisdiction['kind'] == 'district') {
      governors[code] = null;
      continue;
    }
    final page = await download(
      OfficialSources.usaGovPage(jurisdiction['usa_gov_page'] as String),
    );
    governors[code] = parseUsaGovGovernor(page);
    // Be polite to usa.gov: one page at a time, with a short pause.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  return governors;
}

/// Question number → office, e.g. 38 → `president`.
Map<int, String> _readOffices() {
  final json =
      jsonDecode(File(_officesPath).readAsStringSync()) as Map<String, dynamic>;
  final offices = json['office_by_question'] as Map<String, dynamic>;
  return offices.map(
    (number, office) => MapEntry(int.parse(number), office as String),
  );
}

List<String> _checkOfficeholders(
  UscisOfficeholders officeholders,
  Iterable<String> offices,
) => [
  for (final office in offices)
    if ((officeholders.namesByOffice[office] ?? const []).isEmpty)
      'USCIS page: no names found for $office.',
];

List<String> _checkJurisdictions(
  List<Map<String, dynamic>> jurisdictions,
  SenateList senate,
  Map<String, String?> governors,
) {
  final problems = <String>[];
  for (final jurisdiction in jurisdictions) {
    final code = jurisdiction['code'] as String;
    final isState = jurisdiction['kind'] == 'state';

    // States have exactly two senators; D.C. and the territories have none.
    final senatorCount = senate.namesByState[code]?.length ?? 0;
    if (senatorCount != (isState ? 2 : 0)) {
      problems.add('$code: found $senatorCount senators.');
    }

    // Every state and territory has a governor; D.C. does not.
    final hasGovernor = governors[code] != null;
    if (hasGovernor != (jurisdiction['kind'] != 'district')) {
      problems.add(
        '$code: governor ${hasGovernor ? 'found where none was expected' : 'not found on usa.gov'}.',
      );
    }

    // Every state and territory has a capital; D.C. is not a state.
    if ((jurisdiction['capital'] != null) !=
        (jurisdiction['kind'] != 'district')) {
      problems.add(
        '$code: capital does not match its kind (${jurisdiction['kind']}).',
      );
    }
  }

  final unknownStates = senate.namesByState.keys.toSet().difference(
    jurisdictions.map((j) => j['code']).toSet(),
  );
  if (unknownStates.isNotEmpty) {
    problems.add('Senate list has unknown states: $unknownStates.');
  }
  return problems;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
