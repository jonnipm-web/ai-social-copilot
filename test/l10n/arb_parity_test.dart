import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (section 10) -- structural regression
// guard: fails the build if app_pt.arb and app_en.arb ever diverge in key
// set. This does NOT prove a string is actually TRANSLATED (a value could
// be copy-pasted identically into both files and still pass) -- it only
// proves neither locale is missing a key the other has, which is the
// cheapest, most mechanical check available and catches the most common
// regression: a key added to one .arb and forgotten in the other.
void main() {
  test('app_pt.arb and app_en.arb have exactly the same key set', () {
    final ptFile = File('lib/l10n/app_pt.arb');
    final enFile = File('lib/l10n/app_en.arb');
    expect(ptFile.existsSync(), isTrue, reason: 'app_pt.arb must exist');
    expect(enFile.existsSync(), isTrue, reason: 'app_en.arb must exist');

    final pt = jsonDecode(ptFile.readAsStringSync()) as Map<String, dynamic>;
    final en = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

    // '@@...' locale metadata and '@key' ICU placeholder metadata are
    // expected to exist only where the base key itself uses placeholders --
    // filtered out here since comparing them 1:1 would just re-assert the
    // same thing as the base keys they describe.
    final ptKeys = pt.keys.where((k) => !k.startsWith('@')).toSet();
    final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();

    final onlyInPt = ptKeys.difference(enKeys);
    final onlyInEn = enKeys.difference(ptKeys);

    expect(onlyInPt, isEmpty,
        reason: 'Keys present in app_pt.arb but missing from app_en.arb: $onlyInPt');
    expect(onlyInEn, isEmpty,
        reason: 'Keys present in app_en.arb but missing from app_pt.arb: $onlyInEn');
  });
}
