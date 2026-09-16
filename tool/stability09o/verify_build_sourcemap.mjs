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
// well-formed map (e.g. a caching bug reusing a previous build's artifact)
// would pass just as easily as a genuinely fresh one. Fixed by comparing
// the map's embedded content for lib/main.dart against the ACTUAL
// lib/main.dart on disk in the SAME checkout that produced this build
// (already present — this script now takes that file path as a required
// second argument) via exact string equality, not merely "contains a
// marker". A stale map's embedded text differs from the current file by
// construction (this repo's lib/main.dart changes essentially every
// mission), so this closes the gap deterministically rather than
// heuristically.
//
// Method:
//   1. Read the real lib/main.dart from disk (the second CLI argument).
//   2. Find the map's sources[] entry that is unambiguously lib/main.dart
//      (posix-normalized suffix match on ".../lib/main.dart" or exactly
//      "lib/main.dart" — not merely "*main.dart", which could match an
//      unrelated package's file of the same name; more than one match is
//      treated as ambiguous and fails closed).
//   3. Require that entry's embedded sourcesContent to be BYTE-IDENTICAL
//      (after normalizing line endings) to the real file just read.
//   4. As a secondary sanity check (not the primary authority — content
//      equality is), round-trip a known line through
//      generatedPositionFor -> originalPositionFor and require it lands
//      back on the EXACT same line (no tolerance: we know the real file,
//      so there is no reason to allow drift).
//
// A map that fails this either doesn't correspond to the current build at
// all (BUILD_MISMATCH, the exact failure mode STABILITY-09R already proved
// makes historical symbolication silently worthless), was generated
// without embedded sourcesContent (a build config regression), or the
// content genuinely doesn't match the current commit (a stale artifact,
// exactly Codex's finding) — in every case, per section 09: "If the
// mapping check fails: deployment should not claim forensic readiness."
// This script exits non-zero in all cases, which the calling CI step
// treats as a hard failure of the observability gate.
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

function normalize(text) {
  return text.replace(/\r\n/g, '\n');
}

const rawMap = JSON.parse(readFileSync(mapPath, 'utf8'));
const realContent = normalize(readFileSync(realFilePath, 'utf8'));

if (!realContent.includes(MARKER)) {
  fail(
    `the real file "${realFilePath}" no longer contains the marker "${MARKER}" — ` +
    'this script itself needs updating for a lib/main.dart refactor, not the build.',
  );
}

if (!Array.isArray(rawMap.sourcesContent) || rawMap.sourcesContent.length === 0) {
  fail('map has no embedded sourcesContent — cannot self-validate.');
}

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

const sourceIndex = matchIndices[0];
const sourcePath = rawMap.sources[sourceIndex];
const embeddedContent = rawMap.sourcesContent[sourceIndex];

if (typeof embeddedContent !== 'string') {
  fail(`sources[${sourceIndex}] ("${sourcePath}") has no embedded sourcesContent.`);
}

if (normalize(embeddedContent) !== realContent) {
  fail(
    `map's embedded content for "${sourcePath}" does NOT match the real "${realFilePath}" on disk — ` +
    'this map was built from different source than what is currently checked out ' +
    '(stale artifact, cache reuse, or wrong commit). This is exactly the failure mode a self-consistency-only check would miss.',
  );
}

const lines = realContent.split('\n');
const zeroBasedLineIndex = lines.findIndex((l) => l.includes(MARKER));
const knownLine = zeroBasedLineIndex + 1; // source-map package's public API is 1-based.
const knownColumn = lines[zeroBasedLineIndex].indexOf(MARKER);

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
      'the map does not actually cover this line, despite matching content.',
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

  // Content equality above is the primary authority (deterministic, no
  // guessing); this round trip is a secondary sanity check that the
  // MAPPINGS themselves are coherent, so no drift tolerance is needed —
  // we know the exact real line, not an approximation.
  if (roundTrip.line !== knownLine) {
    fail(
      `round-trip line mismatch — queried line ${knownLine}, got back ${roundTrip.line} ` +
      `(generated position ${generated.line}:${generated.column}).`,
    );
  }

  console.log('STABILITY-09O SOURCE-MAP SELF-CHECK: PASS');
  console.log(JSON.stringify({
    source: sourcePath,
    content_match: 'exact',
    known_source_position: { line: knownLine, column: knownColumn },
    generated_position: generated,
    round_trip_source_position: roundTrip,
  }, null, 2));
} finally {
  consumer.destroy();
}
