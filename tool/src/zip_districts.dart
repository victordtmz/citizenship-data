/// Reads the Census Bureau's ZCTA ↔ congressional district relationship file:
/// which district or districts each ZIP code area lies in.
///
/// The file is pipe-separated, one row per piece of a ZIP code area inside a
/// district, with the land area of that piece (`AREALAND_PART`).
library;

/// The Census file for a Congress, e.g. 119 →
/// `…/tab20_cd11920_zcta520_natl.txt` (119th Congress districts on the 2020
/// census geography).
String censusZipDistrictsUrl(int congress) =>
    'https://www2.census.gov/geo/docs/maps-data/data/rel2020/cd-sld/'
    'tab20_cd${congress}20_zcta520_natl.txt';

/// ZIP code → its districts, as `"NY-7"` or `"AK-at-large"`, the district
/// covering most of the ZIP code's land first.
///
/// [stateByFips] turns the Census state number into our two-letter code
/// (`"36"` → `"NY"`). A row for a state not in it is an error, so a new
/// place is never dropped silently.
///
/// Left out:
/// - rows with no ZIP code (the parts of a district outside every ZIP code area);
/// - `ZZ` districts (water that belongs to no district);
/// - a district that only touches the ZIP code across water (no land),
///   unless the ZIP code has no land at all.
Map<String, List<String>> parseZipDistricts(
  String text, {
  required int congress,
  required Map<String, String> stateByFips,
}) {
  final lines = text
      .replaceFirst('﻿', '') // The Census file starts with a BOM.
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) throw const FormatException('Census file: empty.');

  final header = lines.first.split('|');
  int column(String name) {
    final index = header.indexOf(name);
    if (index == -1) {
      throw FormatException('Census file: no $name column (wrong Congress?).');
    }
    return index;
  }

  final districtColumn = column('GEOID_CD${congress}_20');
  final zipColumn = column('GEOID_ZCTA5_20');
  final landColumn = column('AREALAND_PART');

  // ZIP code → district → land area of that piece.
  final landByZip = <String, Map<String, int>>{};
  for (final line in lines.skip(1)) {
    final fields = line.split('|');
    final zip = fields[zipColumn];
    final censusDistrict = fields[districtColumn];
    if (zip.isEmpty || censusDistrict.endsWith('ZZ')) continue;

    final district = _ourDistrict(censusDistrict, stateByFips);
    final land = int.tryParse(fields[landColumn]) ?? 0;
    final districts = landByZip.putIfAbsent(zip, () => {});
    districts[district] = (districts[district] ?? 0) + land;
  }

  return {
    for (final MapEntry(key: zip, value: landByDistrict)
        in (landByZip.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
      zip: _orderByLand(landByDistrict),
  };
}

/// `"3607"` → `"NY-7"`; `"0200"` (a state's only seat) and `"1198"` (a
/// delegate) → `"AK-at-large"`, `"DC-at-large"`.
String _ourDistrict(String censusDistrict, Map<String, String> stateByFips) {
  final fips = censusDistrict.substring(0, 2);
  final state = stateByFips[fips];
  if (state == null) {
    throw FormatException('Census file: unknown state number $fips.');
  }
  final number = int.parse(censusDistrict.substring(2));
  return number == 0 || number == 98 ? '$state-at-large' : '$state-$number';
}

/// The districts with land in the ZIP code, most land first (ties in
/// district order). Water-only districts are kept only when nothing has land.
List<String> _orderByLand(Map<String, int> landByDistrict) {
  final withLand = {
    for (final entry in landByDistrict.entries)
      if (entry.value > 0) entry.key: entry.value,
  };
  final districts = withLand.isEmpty ? landByDistrict : withLand;
  return districts.keys.toList()..sort((a, b) {
    final byLand = districts[b]!.compareTo(districts[a]!);
    return byLand != 0 ? byLand : a.compareTo(b);
  });
}
