// IVE-COMMERCIAL-STABILITY-09O — repository-committed symbolication tool.
//
// Successor to the STABILITY-09R forensic tool that lived only on a single
// machine (C:\Users\jpaul\forensic_09r_tool\symbolicate.mjs) — mission
// section 10 explicitly requires this NOT depend solely on one developer's
// local machine. Same logic, moved into the repo so any future recurrence
// can be symbolicated by anyone with this repo checked out plus the
// matching private source-map artifact (never committed here — see
// .github/workflows/deploy-web.yml and README.md in this directory).
//
// Usage:
//   npm install
//   node symbolicate.mjs <path-to-main.dart.js.map> <line> <column>
//
// line/column are 1-based, exactly as they appear in a browser's compiled
// stack trace ("at ... main.dart.js:LINE:COLUMN") or in a
// diagnostic_events.error_stack row pulled from Supabase.
import { readFileSync } from 'node:fs';
import { SourceMapConsumer } from 'source-map';

const [, , mapPath, lineArg, colArg] = process.argv;
if (!mapPath || !lineArg || !colArg) {
  console.error('Usage: node symbolicate.mjs <map-file> <line> <column>');
  process.exit(1);
}

const rawMap = JSON.parse(readFileSync(mapPath, 'utf8'));

const line = parseInt(lineArg, 10);
const column = parseInt(colArg, 10);

const consumer = await new SourceMapConsumer(rawMap);
try {
  const pos = consumer.originalPositionFor({ line, column, bias: SourceMapConsumer.LEAST_UPPER_BOUND });
  const posLower = consumer.originalPositionFor({ line, column, bias: SourceMapConsumer.GREATEST_LOWER_BOUND });
  console.log(JSON.stringify({ queried: { line, column }, resolved_LUB: pos, resolved_GLB: posLower }, null, 2));
  if (pos.source === null && posLower.source === null) {
    console.error(
      '\nWARNING: both LUB and GLB resolved to null. Per STABILITY-09R evidence, this is the ' +
      'expected signature of a BUILD_MISMATCH (map does not correspond to the build that produced ' +
      'this compiled stack) rather than a tool defect — confirm the map\'s build_sha matches the ' +
      'diagnostic_sessions.build_sha for this event before concluding anything else.',
    );
  }
} finally {
  consumer.destroy();
}
