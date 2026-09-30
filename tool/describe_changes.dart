/// Compares two copies of `current_answers.json` and prints the pull-request
/// description for the names that changed. Prints nothing when no name
/// changed (only dates), which is how the weekly Action tells the two apart.
///
/// ```
/// dart run tool/describe_changes.dart published.json current_answers.json
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'src/describe_changes.dart';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/describe_changes.dart <published.json> <fresh.json>',
    );
    exit(64);
  }

  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final published = read(arguments[0]);
  final fresh = read(arguments[1]);
  final changes = describeNameChanges(published, fresh);
  if (changes.isEmpty) return;

  stdout.writeln('''
## Names that changed

${changes.map((change) => '- $change').join('\n')}

## Before you merge

Merging publishes these names to every copy of the app within about ten
minutes. Check each one against its source:

- Officeholders: https://www.uscis.gov/citizenship/testupdates
- Senators: https://www.senate.gov/senators/
- Governors: https://www.usa.gov/states-and-territories

If a change looks wrong, close this pull request: nothing is published.

Checked ${fresh['checked']} by the weekly update.''');
}
