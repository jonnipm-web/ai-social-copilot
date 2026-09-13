#!/usr/bin/env node
// IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — regression coverage for the
// GitHub Pages SPA-fallback restore script injected into web/index.html by
// .github/workflows/deploy-web.yml.
//
// Physical evidence (reproduced live against the deployed site): a "clean"
// path link like /ai-social-copilot/account triggers web/404.html's
// redirect, but the restore script (Remediation 04) wrote the recovered
// path into `window.location.pathname` — the wrong target for an app using
// Flutter/GoRouter's default HASH url strategy (no usePathUrlStrategy() in
// lib/main.dart, by product decision). GoRouter only ever reads
// `window.location.hash`, so the destination was silently dropped and the
// visible URL ended up as a broken hybrid like
// ".../account#/login" instead of ".../#/account". This script extracts the
// *actual* injected snippet from a real generated web/index.html and
// evaluates it against a fake window.location/history, asserting the
// restored URL lands in the hash — catching a regression back to the
// pathname-based version even though the whole thing only exists as a
// Python-generated string inside a GitHub Actions YAML step.
//
// Usage: node scripts/ci/verify_spa_hash_restore.mjs path/to/web/index.html
// Exit code 0 = pass, 1 = fail. No external dependencies (Node builtins only).

import { readFileSync } from 'node:fs';
import vm from 'node:vm';

function extractSnippet(html) {
  const start = html.indexOf('Single Page Apps for GitHub Pages');
  if (start === -1) {
    throw new Error('Restore snippet marker not found in index.html — was it injected?');
  }
  const scriptOpen = html.lastIndexOf('<script>', start);
  const scriptClose = html.indexOf('</script>', start);
  if (scriptOpen === -1 || scriptClose === -1) {
    throw new Error('Could not locate <script>...</script> bounds around the restore snippet.');
  }
  return html.slice(scriptOpen + '<script>'.length, scriptClose);
}

function runAgainst(snippet, { pathname, search, hash = '' }) {
  let restoredUrl = null;
  const fakeWindow = {
    location: { pathname, search, hash },
    history: {
      replaceState(_state, _title, url) {
        restoredUrl = url;
      },
    },
  };
  fakeWindow.window = fakeWindow; // the snippet references `window.location`/`window.history`
  vm.createContext(fakeWindow);
  vm.runInContext(snippet, fakeWindow);
  return restoredUrl;
}

function main() {
  const indexPath = process.argv[2];
  if (!indexPath) {
    console.error('Usage: node verify_spa_hash_restore.mjs <path/to/web/index.html>');
    process.exit(1);
  }

  const html = readFileSync(indexPath, 'utf8');
  const snippet = extractSnippet(html);

  // Simulates the state right after web/404.html has already redirected
  // "/ai-social-copilot/account" back to "/ai-social-copilot/?/account".
  const restored = runAgainst(snippet, {
    pathname: '/ai-social-copilot/',
    search: '?/account',
  });

  const failures = [];
  if (restored === null) {
    failures.push('history.replaceState was never called for a /?/account query string.');
  } else {
    if (!restored.includes('#/account')) {
      failures.push(
        `Expected the restored URL to carry the route in the HASH ("#/account"), got: ${restored}`,
      );
    }
    // The exact regression this test exists to catch: Remediation 04 wrote
    // the recovered path into the pathname instead, producing something
    // like "/ai-social-copilot/account" with an empty/unrelated hash.
    if (/\/account(?!#)/.test(restored.split('#')[0])) {
      failures.push(
        `Restored URL still carries "account" in the PATHNAME, not just the hash: ${restored}`,
      );
    }
  }

  // A request with no encoded path (plain reload of the app root) must not
  // be touched at all.
  const untouched = runAgainst(snippet, { pathname: '/ai-social-copilot/', search: '' });
  if (untouched !== null) {
    failures.push(`Expected no history.replaceState call for a plain root load, got: ${untouched}`);
  }

  // Nested route (e.g. a shared /market-intelligence/gaps/abc123 link).
  const nested = runAgainst(snippet, {
    pathname: '/ai-social-copilot/',
    search: '?/market-intelligence/gaps/abc123',
  });
  if (nested === null || !nested.includes('#/market-intelligence/gaps/abc123')) {
    failures.push(`Nested path not restored correctly into the hash, got: ${nested}`);
  }

  // web/404.html encodes every "&" in the recovered path as "~and~" (so the
  // real query string's own "&" separators survive being folded into a
  // single search param) — the restore script must decode all of them, not
  // just the first.
  const multiAmpersand = runAgainst(snippet, {
    pathname: '/ai-social-copilot/',
    search: '?/knowledge/new&source~and~url~and~extra',
  });
  if (multiAmpersand === null || !multiAmpersand.includes('#/knowledge/new?source&url&extra')) {
    failures.push(`"~and~"-encoded ampersands not fully decoded, got: ${multiAmpersand}`);
  }

  // Codex adversarial review (Remediation 06, 2nd pass): a request that
  // already carried its own fragment must not have it silently dropped —
  // but it also must not become a SECOND "#" in the restored URL, because
  // GoRouter's hash strategy only recognizes the first "#" as the route
  // boundary; anything from a second "#" onward would be swallowed into
  // the route string and fail to match instead of being cleanly ignored.
  // Folded into a query param on the restored route instead.
  const withExistingHash = runAgainst(snippet, {
    pathname: '/ai-social-copilot/',
    search: '?/account',
    hash: '#preexisting',
  });
  if (withExistingHash === null) {
    failures.push('Expected a history.replaceState call when a pre-existing hash is present.');
  } else {
    const hashCount = (withExistingHash.match(/#/g) || []).length;
    if (hashCount !== 1) {
      failures.push(
        `Restored URL must contain exactly one "#" (GoRouter only honors the first), ` +
          `found ${hashCount}: ${withExistingHash}`,
      );
    }
    if (!withExistingHash.includes('#/account?orig_hash=preexisting')) {
      failures.push(
        `Pre-existing hash fragment was not preserved as a query param on the route, got: ${withExistingHash}`,
      );
    }
  }

  if (failures.length > 0) {
    console.error('FAIL: SPA hash-restore regression check failed:');
    for (const f of failures) console.error(`  - ${f}`);
    process.exit(1);
  }

  console.log(`OK: SPA hash-restore script correctly restores "?/account" -> hash (got: ${restored})`);
}

main();
