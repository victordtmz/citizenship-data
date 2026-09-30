# Citizenship test: current answers

The current answers to the U.S. naturalization civics questions whose answers
change with elections or depend on where the applicant lives. The
**U.S. Citizenship Test** study app downloads this file so it stays current
without an app update.

**The file:** [`current_answers.json`](current_answers.json), served by GitHub
Pages at
`https://victordtmz.github.io/citizenship-data/current_answers.json`.

## What is in it

| Answer | 2025 test question | Read from |
| --- | --- | --- |
| President, Vice President, Speaker, Chief Justice | 38, 39, 30, 57 | [uscis.gov/citizenship/testupdates](https://www.uscis.gov/citizenship/testupdates): every name form USCIS accepts |
| Senators | 23 | [senate.gov](https://www.senate.gov/general/contact_information/senators_cfm.xml): the Senate's own list |
| Governors | 61 | [usa.gov/states-and-territories](https://www.usa.gov/states-and-territories): one page per state and territory |
| Capitals | 62 | The USCIS 2025 Civics Test Study Guide map (p. 41), kept in [`tool/data/jurisdictions.json`](tool/data/jurisdictions.json) |

These are the pages USCIS itself points to. Nothing is typed from memory.

The 50 states, D.C. and the five territories are all included. D.C. has no
senators, governor or capital, and the territories have no senators; USCIS's
official notes say what those applicants should answer, and the app shows
them. The representative (question 29) depends on the congressional district,
not the state, so it is not here: the user types it into the app.

## How it is updated

Every week a GitHub Action runs the updater. If any name changed, it opens a
pull request showing exactly what changed. **Merging the pull request
publishes it.** Nothing reaches the app without that review. If a source
fails or a check does not pass, the run fails and nothing is proposed.

To run the updater by hand, from the repository root:

```
dart pub get
dart run tool/build_current_answers.dart
```

It checks everything before writing (four officeholders, two senators per
state, none for D.C. or the territories, a governor everywhere but D.C., a
capital everywhere but D.C.) and writes nothing if a check fails.

`dart test` checks the page readers against small samples of each site.

## The format

```json
{
  "schema_version": 1,
  "checked": "2026-09-29",
  "sources": { "officeholders": { "url": "…", "source_updated": "09/18/2025" }, "…": {} },
  "officeholders": { "president": ["Donald J. Trump", "Donald Trump", "Trump"], "…": [] },
  "jurisdictions": [
    { "code": "TX", "name": "Texas", "kind": "state", "capital": "Austin",
      "governor": "Greg Abbott", "senators": ["John Cornyn", "Ted Cruz"] }
  ]
}
```

`schema_version` changes only if the format changes. The app refuses a
version it does not know, and keeps the copy it already has.
