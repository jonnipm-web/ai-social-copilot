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
// FIRST ATTEMPTED FIX (this comment kept for the record) tried to close
// that gap by requiring the map's embedded sourcesContent to be byte-
// identical to the real checked-out lib/main.dart. That attempt failed in
// the very first real CI run on Flutter 3.47.4 / stable dart2js:
// `flutter build web --source-maps` does NOT embed sourcesContent by
// default (confirmed live: rawMap.sourcesContent was absent entirely) —
// so requiring it made every real build fail closed, not just stale ones.
//
// ACTUAL METHOD (source of truth = the real file on disk, not the map's
// own embedded claims about itself, which may not exist):
//   1. Read the real, currently-checked-out lib/main.dart (this build's
//      OWN source, from the SAME job/checkout that just produced the map
//      — no separate fetch, no trust in anything the map itself asserts).
//   2. Locate a known, always-compiled (never comment-only) line in THAT
//      real file: the literal runApp(...) call in main().
//   3. Find the map's sources[] entry that is unambiguously lib/main.dart
//      (an exact ".../lib/main.dart" suffix; zero or multiple matches
//      fail closed rather than guessing).
//   4. reverse-map real-source-position -> generated  (generatedPositionFor)
//   5. forward-map that generated position back -> source (originalPositionFor)
//   6. Require step 5 to land back on the EXACT same source and EXACT same
//      line (no tolerance — the real line is known exactly, not guessed).
//
// This still closes the original P1: a STALE map (built from an older
// lib/main.dart where this marker sat on a different line, or a
// completely different commit's map reused by accident) queried at the
// CURRENT file's real line/column will, in practice, either have no
// mapping entry there at all (dart2js mappings are dense and precise) or
// round-trip back to a different line — both are hard failures here. It is
// a real (not merely theoretical) improvement over the pre-Codex-Gate
// version specifically because the ground truth is the actual file on
// disk in the SAME job, never something the map claims about itself.
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

const MARKER = 'runApp(UncontrolledProviderScope';

function fail(reason) {
  console.error(`STABILITY-09O SOURCE-MAP SELF-CHECK: FAIL — ${reason}`);
  process.exit(1);
}

const rawMap = JSON.parse(readFileSync(mapPath, 'utf8'));
const realContent = readFileSync(realFilePath, 'utf8').replace(/\r\n/g, '\n');

const lines = realContent.split('\n');
const zeroBasedLineIndex = lines.findIndex((l) => l.includes(MARKER));
if (zeroBasedLineIndex === -1) {
  fail(
    `the real file "${realFilePath}" does not contain the marker "${MARKER}" — ` +
    'this script itself needs updating for a lib/main.dart refactor, not the build.',
  );
}
const knownLine = zeroBasedLineIndex + 1; // source-map package's public API is 1-based.
const knownColumn = lines[zeroBasedLineIndex].indexOf(MARKER);

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
  const generated = consumer.generatedPositionFor({
    source: sourcePath,
    line: knownLine,
    column: knownColumn,
    bias: SourceMapConsumer.LEAST_UPPER_BOUND,
  });

  if (generated.line == null || generated.column == null) {
    fail(
      `generatedPositionFor(${sourcePath}:${knownLine}:${knownColumn}) returned no mapping — ` +
      'the map does not cover this exact line of the real, currently-checked-out file.',
    );
  }

  const roundTrip = consumer.originalPositionFor({
    line: generated.line,
    column: generated.column,
    bias: SourceMapConsumer.LEAST_UPPER_BOUND,
  });

  if (roundTrip.source !== sourcePath) {
    fail(
      `round-trip source mismatch — expected "${sourcePath}", got "${roundTrip.source}" ` +
      `(generated position ${generated.line}:${generated.column}).`,
    );
  }

  if (roundTrip.line !== knownLine) {
    fail(
      `round-trip line mismatch — queried the real file's line ${knownLine}, map round-tripped to line ${roundTrip.line} ` +
      `(generated position ${generated.line}:${generated.column}) — map does not match the current source.`,
    );
  }

  console.log('STABILITY-09O SOURCE-MAP SELF-CHECK: PASS');
  console.log(JSON.stringify({
    source: sourcePath,
    embedded_sources_content_present: hasEmbeddedContent,
    known_source_position: { line: knownLine, column: knownColumn },
    generated_position: generated,
    round_trip_source_position: roundTrip,
  }, null, 2));
} finally {
  consumer.destroy();
}
