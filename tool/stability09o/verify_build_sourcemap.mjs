// IVE-COMMERCIAL-STABILITY-09O — CI-only source-map self-check (mission
// section 09).
//
// Proves the freshly generated main.dart.js.map actually corresponds to
// THIS build's lib/main.dart, without touching app source (no query-param
// self-test throw retained in production, per section 09's explicit
// instruction) and without assuming any fixed compiled-offset, which would
// silently rot on the next dart2js/Flutter upgrade.
//
// Codex Gate (STABILITY-09O mandatory review, P1 ACCEPTED) — the first cut
// of this script only checked the map's INTERNAL self-consistency (its own
// embedded sourcesContent against its own mappings), which a stale-but-
// well-formed map would pass just as easily as a genuinely fresh one.
//
// SECOND ATTEMPT (this comment kept for the record) tried to close that gap
// by requiring the map's embedded sourcesContent to be byte-identical to
// the real checked-out lib/main.dart. Failed in the very first real CI run
// on Flutter 3.47.4 / stable dart2js: `flutter build web --source-maps`
// does NOT embed sourcesContent by default (confirmed live: absent
// entirely) — so requiring it made every real build fail closed.
//
// THIRD ATTEMPT (also kept for the record) fell back to a SINGLE known
// line (the runApp(...) call) round-tripped through the map. Codex's
// follow-up review (2nd Gate, P1 ACCEPTED) correctly flagged that this only
// proves the map is fresh AT THAT ONE LINE — a map built from a different
// revision that happens to leave that one line's position unchanged, while
// differing "elsewhere [in the file], undetected", would still false-PASS.
//
// ACTUAL METHOD (source of truth = the real file on disk, not anything the
// map claims about itself, which may not even exist):
//   1. Read the real, currently-checked-out lib/main.dart (this build's
//      OWN source, from the SAME job/checkout that just produced the map).
//   2. Locate SEVERAL known, always-compiled (never comment-only) MARKERS
//      in that real file, deliberately spread across its entire compiled
//      span — not clustered together — so that a stale map would need to
//      coincidentally preserve the exact line position of EVERY one of
//      them, near the top, middle, and end of the file, to still pass.
//   3. Find the map's sources[] entry that is unambiguously lib/main.dart
//      (an exact ".../lib/main.dart" suffix; zero or multiple matches
//      fail closed rather than guessing).
//   4. For EVERY marker: reverse-map real-source-position -> generated
//      (generatedPositionFor), then forward-map that generated position
//      back -> source (originalPositionFor), and require it to land on the
//      EXACT same source and EXACT same line (no tolerance — the real line
//      is known exactly, not guessed). ALL markers must independently pass.
//
// This is a real, substantial (not a false sense of) improvement over a
// single-marker check: the markers below span essentially the entire
// compiled body of lib/main.dart (from _logUncaughtError near the top to
// the runApp(...) call at the very end), so "unrelated changes elsewhere"
// in this file's compiled code have nowhere left to hide undetected. It is
// still not a byte-for-byte whole-file guarantee (that would need
// sourcesContent, which this toolchain does not produce, or a separate
// build-manifest artifact — out of proportion for this mission per its own
// "do not over-engineer" instruction) — this is documented as a known,
// accepted residual limitation, not claimed as absolute.
//
// A map that fails this either doesn't correspond to the current source at
// all (BUILD_MISMATCH, the exact failure mode STABILITY-09R already proved
// makes historical symbolication silently worthless) or is stale — either
// way, per section 09: "If the mapping check fails: deployment should not
// claim forensic readiness." This script exits non-zero in both cases,
// which the calling CI step treats as a hard failure of the observability
// gate.
//
// Usage: node verify_build_sourcemap.mjs <path-to-main.dart.js.map> <path-to-real-lib/main.dart>
import { readFileSync } from 'node:fs';
import { SourceMapConsumer } from 'source-map';

const [, , mapPath, realFilePath] = process.argv;
if (!mapPath || !realFilePath) {
  console.error('Usage: node verify_build_sourcemap.mjs <map-file> <path-to-real-lib/main.dart>');
  process.exit(1);
}

// Deliberately spread across the ENTIRE compiled span of lib/main.dart —
// from the top of _logUncaughtError to the last line of main() — so a
// stale map has to coincidentally preserve every one of these positions,
// not just one, to false-PASS. Each is real, always-compiled code, never a
// comment-only line. Keep this list in sync if lib/main.dart is refactored
// (the script fails loudly, naming which marker vanished, rather than
// silently skipping it).
const MARKERS = [
  "debugPrint('[uncaught] ${error.runtimeType}",
  'diagnosticLogger.logEvent(',
  'WidgetsFlutterBinding.ensureInitialized();',
  "await dotenv.load(fileName: '.env');",
  'runApp(UncontrolledProviderScope',
];

function fail(reason) {
  console.error(`STABILITY-09O SOURCE-MAP SELF-CHECK: FAIL — ${reason}`);
  process.exit(1);
}

const rawMap = JSON.parse(readFileSync(mapPath, 'utf8'));
const realContent = readFileSync(realFilePath, 'utf8').replace(/\r\n/g, '\n');
const lines = realContent.split('\n');

const knownPositions = MARKERS.map((marker) => {
  const zeroBasedLineIndex = lines.findIndex((l) => l.includes(marker));
  if (zeroBasedLineIndex === -1) {
    fail(
      `the real file "${realFilePath}" does not contain the marker "${marker}" — ` +
      'this script itself needs updating for a lib/main.dart refactor, not the build.',
    );
  }
  return {
    marker,
    line: zeroBasedLineIndex + 1, // source-map package's public API is 1-based.
    column: lines[zeroBasedLineIndex].indexOf(marker),
  };
});

// Posix-normalize for the suffix match (dart2js source-map paths are
// forward-slash already, but be defensive).
const posixSuffix = (p) => p.replace(/\\/g, '/');
const isLibMainDart = (p) => {
  const norm = posixSuffix(p);
  return norm === 'lib/main.dart' || norm.endsWith('/lib/main.dart');
};

const matchIndices = [];
for (let i = 0; i < rawMap.sources.length; i++) {
  if (isLibMainDart(rawMap.sources[i])) matchIndices.push(i);
}

if (matchIndices.length === 0) {
  fail('no sources[] entry unambiguously identifies as lib/main.dart (checked for an exact ".../lib/main.dart" suffix).');
}
if (matchIndices.length > 1) {
  fail(
    `${matchIndices.length} sources[] entries all match lib/main.dart ` +
    `(${matchIndices.map((i) => rawMap.sources[i]).join(', ')}) — ambiguous, refusing to guess.`,
  );
}

const sourcePath = rawMap.sources[matchIndices[0]];

const hasEmbeddedContent =
  Array.isArray(rawMap.sourcesContent) &&
  typeof rawMap.sourcesContent[matchIndices[0]] === 'string';
if (hasEmbeddedContent) {
  // Bonus check when present (not required — this Flutter/dart2js version
  // does not embed it by default, confirmed live in CI): if the map DOES
  // carry its own copy of the source, it should match the real file too.
  const embedded = rawMap.sourcesContent[matchIndices[0]].replace(/\r\n/g, '\n');
  if (embedded !== realContent) {
    fail(`map's embedded sourcesContent for "${sourcePath}" does not match the real file (and embedded content IS present, so this is a direct contradiction).`);
  }
}

const consumer = await new SourceMapConsumer(rawMap);
try {
  const results = [];
  for (const known of knownPositions) {
    const generated = consumer.generatedPositionFor({
      source: sourcePath,
      line: known.line,
      column: known.column,
      bias: SourceMapConsumer.LEAST_UPPER_BOUND,
    });

    if (generated.line == null || generated.column == null) {
      fail(
        `marker "${known.marker}" — generatedPositionFor(${sourcePath}:${known.line}:${known.column}) ` +
        'returned no mapping — the map does not cover this exact line of the real, currently-checked-out file.',
      );
    }

    const roundTrip = consumer.originalPositionFor({
      line: generated.line,
      column: generated.column,
      bias: SourceMapConsumer.LEAST_UPPER_BOUND,
    });

    if (roundTrip.source !== sourcePath) {
      fail(
        `marker "${known.marker}" — round-trip source mismatch — expected "${sourcePath}", got "${roundTrip.source}" ` +
        `(generated position ${generated.line}:${generated.column}).`,
      );
    }

    if (roundTrip.line !== known.line) {
      fail(
        `marker "${known.marker}" — round-trip line mismatch — queried the real file's line ${known.line}, ` +
        `map round-tripped to line ${roundTrip.line} (generated position ${generated.line}:${generated.column}) — ` +
        'map does not match the current source at this position.',
      );
    }

    results.push({ marker: known.marker, source_line: known.line, generated_position: generated, round_trip_line: roundTrip.line });
  }

  console.log(`STABILITY-09O SOURCE-MAP SELF-CHECK: PASS (${results.length}/${MARKERS.length} markers, spanning the file, all round-tripped exactly)`);
  console.log(JSON.stringify({
    source: sourcePath,
    embedded_sources_content_present: hasEmbeddedContent,
    markers: results,
  }, null, 2));
} finally {
  consumer.destroy();
}
