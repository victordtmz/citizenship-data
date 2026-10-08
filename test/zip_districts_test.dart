import 'package:test/test.dart';

import '../tool/src/zip_districts.dart';

/// A small sample shaped like the Census relationship file: only the columns
/// the reader uses, in a different order, behind a BOM.
void main() {
  const header = '﻿OID_CD119_20|GEOID_CD119_20|GEOID_ZCTA5_20|AREALAND_PART';
  const stateByFips = {'36': 'NY', '02': 'AK', '11': 'DC', '72': 'PR'};

  Map<String, List<String>> parse(List<String> rows) => parseZipDistricts(
    [header, ...rows].join('\r\n'),
    congress: 119,
    stateByFips: stateByFips,
  );

  test('a ZIP code in one district', () {
    expect(parse(['1|3612|10001|500']), {
      '10001': ['NY-12'],
    });
  });

  test('a split ZIP code: the district with the most land first', () {
    expect(parse(['1|3610|10002|100', '2|3607|10002|900']), {
      '10002': ['NY-7', 'NY-10'],
    });
  });

  test('a state\'s only seat (00) and a delegate (98) are at-large', () {
    expect(parse(['1|0200|99501|10', '2|1198|20001|10', '3|7298|00901|10']), {
      '00901': ['PR-at-large'],
      '20001': ['DC-at-large'],
      '99501': ['AK-at-large'],
    });
  });

  test('water: ZZ districts, and districts reached only across water', () {
    expect(parse(['1|36ZZ|10004|0', '2|3610|10004|50', '3|3611|10004|0']), {
      '10004': ['NY-10'],
    });
  });

  test('a ZIP code that is all water keeps its districts', () {
    expect(parse(['1|3610|10005|0', '2|3611|10005|0']), {
      '10005': ['NY-10', 'NY-11'],
    });
  });

  test('rows without a ZIP code are skipped', () {
    expect(parse(['1|3612||500']), isEmpty);
  });

  test('an unknown state number is an error, not a dropped row', () {
    expect(() => parse(['1|9901|00000|5']), throwsFormatException);
  });

  test('a file for another Congress is an error', () {
    expect(
      () => parseZipDistricts(
        '$header\n1|3612|10001|5',
        congress: 120,
        stateByFips: stateByFips,
      ),
      throwsFormatException,
    );
  });
}
