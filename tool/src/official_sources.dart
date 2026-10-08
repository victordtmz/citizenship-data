import 'dart:convert';
import 'dart:io';

import 'html_text.dart';

/// The official pages the current answers are read from. These are the
/// pages USCIS itself points to on its test-updates page.
abstract final class OfficialSources {
  static const uscisTestUpdates =
      'https://www.uscis.gov/citizenship/testupdates';
  static const senators =
      'https://www.senate.gov/general/contact_information/senators_cfm.xml';
  static const usaGovStates = 'https://www.usa.gov/states-and-territories';
  static const houseMembers =
      'https://clerk.house.gov/xml/lists/MemberData.xml';

  static String usaGovPage(String page) => 'https://www.usa.gov/states/$page';
}

/// Downloads a page as text. Throws with the URL and status on any failure,
/// so a broken source is never mistaken for an empty one.
Future<String> download(String url) async {
  final client = HttpClient()
    ..userAgent = 'Mozilla/5.0 (citizenship study app content updater)';
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    return body;
  } finally {
    client.close();
  }
}

/// The four officeholders, as USCIS lists them for the 2025 test.
class UscisOfficeholders {
  UscisOfficeholders({required this.namesByOffice, required this.pageUpdated});

  /// Office (e.g. `president`) → every name form USCIS accepts, in its order.
  final Map<String, List<String>> namesByOffice;

  /// The page's own "Last Reviewed/Updated" date, as written (MM/DD/YYYY).
  final String pageUpdated;
}

/// Reads the 2025 section of the USCIS test-updates page.
///
/// The page lists each question as `38. What is the name of …` followed by
/// the accepted answers, one per line, until the next question.
/// [officeByQuestion] says which question numbers to read, and which office
/// each one asks about (from `tool/data/offices.json`).
UscisOfficeholders parseUscisTestUpdates(
  String html, {
  required Map<int, String> officeByQuestion,
}) {
  final lines = htmlToLines(html);

  final start = lines.indexWhere(
    (line) => line.startsWith('Civics Test (2025'),
  );
  final end = lines.indexWhere(
    (line) => line.startsWith('Last Reviewed/Updated'),
  );
  if (start == -1 || end == -1 || end < start) {
    throw const FormatException('USCIS page: the 2025 section was not found.');
  }

  final namesByOffice = <String, List<String>>{};
  String? currentOffice;
  for (final line in lines.sublist(start + 1, end)) {
    final question = RegExp(r'^(\d+)\.\s').firstMatch(line);
    if (question != null) {
      currentOffice = officeByQuestion[int.parse(question.group(1)!)];
      if (currentOffice != null) namesByOffice[currentOffice] = [];
      continue;
    }
    // Headings split across elements leave stray "*" and "?" lines behind.
    if (line == '*' || line == '?') continue;
    if (currentOffice != null) namesByOffice[currentOffice]!.add(line);
  }

  return UscisOfficeholders(
    namesByOffice: namesByOffice,
    pageUpdated: lines[end + 1],
  );
}

/// The senators, and the date the Senate last updated its list.
class SenateList {
  SenateList({required this.namesByState, required this.listUpdated});

  /// Two-letter state code → full names, sorted by last name.
  final Map<String, List<String>> namesByState;
  final String listUpdated;
}

/// Reads the Senate's own contact-information XML.
SenateList parseSenateXml(String xml) {
  String field(String block, String name) =>
      RegExp(
        '<$name>(.*?)</$name>',
        dotAll: true,
      ).firstMatch(block)?.group(1)?.trim() ??
      '';

  final byState = <String, List<({String last, String full})>>{};
  for (final member in RegExp(
    r'<member>(.*?)</member>',
    dotAll: true,
  ).allMatches(xml)) {
    final block = member.group(1)!;
    final first = field(block, 'first_name');
    final last = field(block, 'last_name');
    byState.putIfAbsent(field(block, 'state'), () => []).add((
      last: last,
      full: '$first $last',
    ));
  }

  return SenateList(
    namesByState: {
      for (final entry in byState.entries)
        entry.key: (entry.value..sort((a, b) => a.last.compareTo(b.last)))
            .map((name) => name.full)
            .toList(),
    },
    listUpdated: field(xml, 'last_updated'),
  );
}

/// Reads the governor's name off a usa.gov state or territory page, where it
/// appears as "Governor Greg Abbott" or, on some pages, only as
/// "Contact Governor Dan McKee". Returns null when the page has none.
String? parseUsaGovGovernor(String html) {
  final lines = htmlToLines(html);
  for (final pattern in [
    RegExp(r'^Governor\s+(.+)$'),
    RegExp(r'^Contact Governor\s+(.+)$'),
  ]) {
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) return match.group(1)!.trim();
    }
  }
  return null;
}

/// One seat in the House: a district and who holds it.
class HouseSeat {
  const HouseSeat({required this.district, required this.name});

  /// `"1"`, `"2"`, … or `"at-large"` for a state's only seat, and for the
  /// delegates of D.C. and the territories.
  final String district;

  /// The member's official name, or null while the seat is vacant.
  final String? name;

  Map<String, Object?> toJson() => {'district': district, 'name': name};
}

/// The House, as the Clerk lists it.
class HouseList {
  HouseList({
    required this.seatsByState,
    required this.congress,
    required this.publishDate,
  });

  /// Two-letter code → seats, in district order.
  final Map<String, List<HouseSeat>> seatsByState;

  /// Which Congress the list is for, e.g. 119.
  final int congress;

  /// The Clerk's own publish date, as written ("October 1, 2026").
  final String publishDate;
}

/// The Clerk codes American Samoa `AQ`; everywhere else it is `AS`.
const _clerkStateCodes = {'AQ': 'AS'};

/// Reads the Clerk of the House's member XML.
///
/// Each `<member>` has a `<statedistrict>` such as `NY07`, or `AK00` for an
/// at-large seat and for the delegates, and an `<official-name>` that is
/// empty while the seat is vacant.
HouseList parseHouseXml(String xml) {
  String field(String block, String name) => decodeEntities(
    RegExp(
          '<$name>(.*?)</$name>',
          dotAll: true,
        ).firstMatch(block)?.group(1)?.trim() ??
        '',
  );

  final members = RegExp(
    r'<members>(.*?)</members>',
    dotAll: true,
  ).firstMatch(xml)?.group(1);
  if (members == null) {
    throw const FormatException('House XML: no <members> list.');
  }

  final byState = <String, List<({int number, HouseSeat seat})>>{};
  for (final member in RegExp(
    r'<member>(.*?)</member>',
    dotAll: true,
  ).allMatches(members)) {
    final block = member.group(1)!;
    final stateDistrict = field(block, 'statedistrict');
    final clerkState = stateDistrict.substring(0, 2);
    final state = _clerkStateCodes[clerkState] ?? clerkState;
    final number = int.parse(stateDistrict.substring(2));
    final name = field(block, 'official-name');

    byState.putIfAbsent(state, () => []).add((
      number: number,
      seat: HouseSeat(
        district: number == 0 ? 'at-large' : '$number',
        name: name.isEmpty ? null : name,
      ),
    ));
  }

  return HouseList(
    seatsByState: {
      for (final entry in byState.entries)
        entry.key: (entry.value..sort((a, b) => a.number.compareTo(b.number)))
            .map((entry) => entry.seat)
            .toList(),
    },
    congress: int.parse(field(xml, 'congress-num')),
    publishDate:
        RegExp(r'publish-date="([^"]*)"').firstMatch(xml)?.group(1) ?? '',
  );
}
