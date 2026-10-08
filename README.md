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
| Representatives | 29 | [clerk.house.gov](https://clerk.house.gov/xml/lists/MemberData.xml): the Clerk of the House's member list, every district and delegate |
| Governors | 61 | [usa.gov/states-and-territories](https://www.usa.gov/states-and-territories): one page per state and territory |
| Capitals | 62 | The USCIS 2025 Civics Test Study Guide map (p. 41), kept in [`tool/data/jurisdictions.json`](tool/data/jurisdictions.json) |

These are the pages USCIS itself points to. Nothing is typed from memory.

The 50 states, D.C. and the five territories are all included. D.C. has no
senators, governor or capital, and the territories have no senators; USCIS's
official notes say what those applicants should answer, and the app shows
them. The representative (question 29) depends on the congressional
district: every place lists its seats by district (`"1"`, `"2"`, … or
`"at-large"` for a state's only seat and for the six delegates), and a seat
the Clerk lists as vacant has `"name": null`. The Clerk codes American Samoa
`AQ`; the file uses `AS`.

## ZIP codes → districts

**The file:** [`zip_districts.json`](zip_districts.json), served at
`https://victordtmz.github.io/citizenship-data/zip_districts.json`. The app
uses it to find the user's representative from their ZIP code, offline.

```json
{
  "schema_version": 1,
  "congress": 119,
  "built": "2026-10-08",
  "source": { "url": "…", "name": "U.S. Census Bureau, ZCTA to 119th Congressional District relationship file" },
  "zips": {
    "10001": ["NY-12"],
    "77002": ["TX-18","TX-7"],
    "99501": ["AK-at-large"]
  }
}
```

- Built from the Census Bureau's
  [ZIP code area ↔ congressional district file](https://www2.census.gov/geo/docs/maps-data/data/rel2020/cd-sld/)
  for the Congress that `current_answers.json` lists representatives for
  (`sources.representatives.congress`), so the two always match.
- About 17% of ZIP codes lie in more than one district. Their districts are
  listed **by how much of the ZIP code's land each covers, largest first**;
  none is dropped (land is not people). Districts that only touch a ZIP code
  across water are left out.
- Districts are written as in `current_answers.json`: `"NY-7"`, or
  `"AK-at-large"` for a state's only seat and for D.C. and the territories.

**It is not part of the weekly check.** Districts only change when a new
Congress is seated or a state redraws its map. Then, after the
representatives for the new Congress are in `current_answers.json`:

```
dart run tool/build_zip_districts.dart
```

It checks that every seat can be reached from some ZIP code and that no ZIP
code points to a district without a seat (the sign of a map for a different
Congress), and writes nothing otherwise. Next due: **January 2027**, when the
120th Congress is seated (several states redrew their maps for 2026); the
Census publishes the 120th Congress file some months later, and until then
the map may point a few redrawn ZIP codes to the wrong district.

## How it is updated

Every Monday a GitHub Action
([`weekly-update.yml`](.github/workflows/weekly-update.yml)) runs the updater
and compares the names with the published file:

| What it finds | What it does |
| --- | --- |
| A name changed (officeholder, senator, governor, capital) | Opens a pull request listing each change. **Merging it publishes the names.** Nothing reaches the app without that review |
| Only dates changed | Commits the new `checked` date to `main`, so the app can say when the names were last verified |
| A source failed, or a check did not pass | The run fails, GitHub emails, nothing changes |

To check on demand: **Actions → Weekly check of the official sources → Run
workflow**.

To run the updater by hand, from the repository root:

```
dart pub get
dart run tool/build_current_answers.dart
```

It checks everything before writing (four officeholders, two senators per
state, none for D.C. or the territories, a governor everywhere but D.C., a
capital everywhere but D.C., 441 House seats numbered without gaps or one
at-large seat, one delegate for D.C. and each territory) and writes nothing
if a check fails.

`dart test` checks the page readers against small samples of each site.

## The format

```json
{
  "schema_version": 2,
  "checked": "2026-09-29",
  "sources": { "officeholders": { "url": "…", "source_updated": "09/18/2025" }, "…": {} },
  "officeholders": { "president": ["Donald J. Trump", "Donald Trump", "Trump"], "…": [] },
  "jurisdictions": [
    { "code": "TX", "name": "Texas", "kind": "state", "capital": "Austin",
      "governor": "Greg Abbott", "senators": ["John Cornyn", "Ted Cruz"],
      "representatives": [{ "district": "1", "name": "Nathaniel Moran" }, "…"] }
  ]
}
```

`schema_version` changes only if the format changes. The app refuses a
version it does not know, and keeps the copy it already has.
