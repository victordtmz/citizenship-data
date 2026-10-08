import 'package:test/test.dart';

import '../tool/src/html_text.dart';
import '../tool/src/official_sources.dart';

/// Small samples shaped like the real pages, so the parsers can be tested
/// without the network. If a site changes its layout, the updater fails its
/// checks; these tests pin down what it expects.
void main() {
  group('htmlToLines', () {
    test('keeps visible text, one element per line, and decodes entities', () {
      const html =
          '<p>Governor <b>Pula&rsquo;ali&#8217;i</b></p><script>ignored()</script><p>A &amp; B</p>';

      expect(htmlToLines(html), ['Governor', 'Pula’ali’i', 'A & B']);
    });
  });

  group('USCIS test updates', () {
    const page = '''
      <h2>Civics Test (2008 Version) Updates</h2>
      <p>28. What is the name of the President of the United States now?*</p>
      <ul><li>Wrong Section</li></ul>
      <h2>Civics Test (2025 Naturalization Civics Test) Updates</h2>
      <p>23. Who is one of your state's U.S. Senators now?*</p>
      <p>Answers will vary.</p>
      <p>38. What is the name of the President of the United States now?</p><p>*</p>
      <ul><li>Donald J. Trump</li><li>Donald Trump</li><li>Trump</li></ul>
      <p>57. Who is the Chief Justice of the United States now</p><p>?</p>
      <ul><li>John Roberts</li></ul>
      <p>Last Reviewed/Updated:</p><p>09/18/2025</p>
    ''';

    final result = parseUscisTestUpdates(
      page,
      officeByQuestion: {38: 'president', 57: 'chief_justice'},
    );

    test('reads only the 2025 section, every accepted form in order', () {
      expect(result.namesByOffice['president'], [
        'Donald J. Trump',
        'Donald Trump',
        'Trump',
      ]);
    });

    test('ignores the stray "*" and "?" left by split headings', () {
      expect(result.namesByOffice['chief_justice'], ['John Roberts']);
    });

    test('skips questions that are not about an office', () {
      expect(
        result.namesByOffice.keys,
        unorderedEquals(['president', 'chief_justice']),
      );
    });

    test('reads the page date', () {
      expect(result.pageUpdated, '09/18/2025');
    });
  });

  group('Senate XML', () {
    const xml = '''
      <contact_information><last_updated>2026-09-23T13:19-05:00</last_updated>
      <member><last_name>Zeta</last_name><first_name>Ann B.</first_name><state>TX</state></member>
      <member><last_name>Alpha</last_name><first_name>Carl</first_name><state>TX</state></member>
      </contact_information>''';

    final senate = parseSenateXml(xml);

    test('full names by state, sorted by last name', () {
      expect(senate.namesByState['TX'], ['Carl Alpha', 'Ann B. Zeta']);
    });

    test('reads when the Senate last updated the list', () {
      expect(senate.listUpdated, '2026-09-23T13:19-05:00');
    });
  });

  group('usa.gov governor', () {
    test('"Governor Name"', () {
      expect(
        parseUsaGovGovernor('<h3>Governor</h3><p>Governor Greg Abbott</p>'),
        'Greg Abbott',
      );
    });

    test(
      'falls back to "Contact Governor Name" when that is all the page has',
      () {
        expect(
          parseUsaGovGovernor(
            '<h3>Governor</h3><a>Contact Governor Dan McKee</a>',
          ),
          'Dan McKee',
        );
      },
    );

    test('none on a page without a governor', () {
      expect(
        parseUsaGovGovernor('<h3>Governor</h3><p>Mayor Muriel Bowser</p>'),
        isNull,
      );
    });
  });

  group('House XML', () {
    const xml = '''
      <MemberData publish-date="October 1, 2026"><title-info><congress-num>119</congress-num></title-info>
      <members>
      <member><statedistrict>NY10</statedistrict><member-info><official-name>Dan Goldman</official-name></member-info></member>
      <member><statedistrict>NY07</statedistrict><member-info><official-name>Nydia M. Vel&#225;zquez</official-name></member-info></member>
      <member><statedistrict>TX23</statedistrict><member-info><official-name></official-name></member-info>
        <predecessor-info><pred-official-name>Tony Gonzales</pred-official-name></predecessor-info></member>
      <member><statedistrict>AK00</statedistrict><member-info><official-name>Nicholas J. Begich III</official-name></member-info></member>
      <member><statedistrict>AQ00</statedistrict><member-info><official-name>Aumua Amata Coleman Radewagen</official-name></member-info></member>
      </members>
      <committees><committee><member>not a House seat</member></committee></committees>
      </MemberData>''';

    final house = parseHouseXml(xml);

    test('seats by state, in district order, names decoded', () {
      expect(house.seatsByState['NY']!.map((seat) => seat.toJson()), [
        {'district': '7', 'name': 'Nydia M. Velázquez'},
        {'district': '10', 'name': 'Dan Goldman'},
      ]);
    });

    test('a vacant seat has no name, not the predecessor\'s', () {
      expect(house.seatsByState['TX']!.single.toJson(), {
        'district': '23',
        'name': null,
      });
    });

    test('district 00 is at-large', () {
      expect(house.seatsByState['AK']!.single.district, 'at-large');
    });

    test('the Clerk\'s AQ is American Samoa, AS', () {
      expect(house.seatsByState.keys, isNot(contains('AQ')));
      expect(
        house.seatsByState['AS']!.single.name,
        'Aumua Amata Coleman Radewagen',
      );
    });

    test('reads only the members list, the Congress and the publish date', () {
      expect(
        house.seatsByState.keys,
        unorderedEquals(['NY', 'TX', 'AK', 'AS']),
      );
      expect(house.congress, 119);
      expect(house.publishDate, 'October 1, 2026');
    });
  });
}
