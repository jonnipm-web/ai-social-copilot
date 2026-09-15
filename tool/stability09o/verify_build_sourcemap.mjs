// IVE-COMMERCIAL-STABILITY-09O — CI-only source-map self-check (mission
// section 09).
//
// Proves the freshly generated main.dart.js.map actually corresponds to
// THIS build's lib/main.dart, without touching app source (no query-param
// self-test throw retained in production, per section 09's explicit
// instruction) and without assuming any fixed compiled-offset, which would
// silently rot on the next dart2js/Flutter upgrade.
//
// Method: round-trip self-consistency.
//   1. Find the map's own entry for lib/main.dart via its EMBEDDED
//      sourcesContent (dart2js --source-maps inlines original sources, so
//      no separate checkout of the exact built commit is needed here).
//   2. Locate a known, always-compiled (never comment-only) line: the
//      literal runApp(...) call in main().
//   3. reverse-map source→generated  (generatedPositionFor)
//   4. forward-map that generated position back  (originalPositionFor)
//   5. Assert step 4 lands back in the same source, near the same line.
//
// A map that fails this either doesn't correspond to the current source at
// all (BUILD_MISMATCH, the exact failure mode STABILITY-09R already proved
// makes historical symbolication silently worthless) or was generated
// without embedded sourcesContent (a build config regression) — either way,
// per section 09: "If the mapping check fails: deployment should not claim
// forensic readiness." This script exits non-zero in both cases, which the
// calling CI step treats as a hard failure of the observability gate.
//
// Usage: node verify_build_sourcemap.mjs <path-to-main.dart.js.map>
import { readFileSync } from 'node:fs';
import { SourceMapConsumer } from 'source-map';

const [, , mapPath] = process.argv;
if (!mapPath) {
  console.error('Usage: node verify_build_sourcemap.mjs <map-file>');
  process.exit(1);
}

const MARKER = 'runApp(UncontrolledProviderScope';

function fail(reason) {
  console.error(`STABILITY-09O SOURCE-MAP SELF-CHECK: FAIL — ${reason}`);
  process.exit(1);
}

const rawMap = JSON.parse(readFileSync(mapPath, 'utf8'));

if (!Array.isArray(rawMap.sourcesContent) || rawMap.sourcesContent.length === 0) {
  fail('map has no embedded sourcesContent — cannot self-validate without a separate checkout.');
}

let sourceIndex = -1;
for (let i = 0; i < rawMap.sources.length; i++) {
  const content = rawMap.sourcesContent[i];
  if (typeof content === 'string' && content.includes(MARKER) && rawMap.sources[i].endsWith('main.dart')) {
    sourceIndex = i;
    break;
  }
}
if (sourceIndex === -1) {
  fail(`no sources[] entry ending in "main.dart" has embedded content containing "${MARKER}".`);
}

const sourcePath = rawMap.sources[sourceIndex];
const content = rawMap.sourcesContent[sourceIndex];
const lines = content.split('\n');
const zeroBasedLineIndex = lines.findIndex((l) => l.includes(MARKER));
if (zeroBasedLineIndex === -1) {
  fail('marker line vanished between includes() and findIndex() — should be unreachable.');
}
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
      'the map does not actually cover this line of the current source.',
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

  const lineDelta = Math.abs((roundTrip.line ?? -9999) - knownLine);
  if (lineDelta > 2) {
    fail(
      `round-trip line drifted too far — queried line ${knownLine}, got back ${roundTrip.line} ` +
      `(generated position ${generated.line}:${generated.column}).`,
    );
  }

  console.log('STABILITY-09O SOURCE-MAP SELF-CHECK: PASS');
  console.log(JSON.stringify({
    source: sourcePath,
    known_source_position: { line: knownLine, column: knownColumn },
    generated_position: generated,
    round_trip_source_position: roundTrip,
  }, null, 2));
} finally {
  consumer.destroy();
}
