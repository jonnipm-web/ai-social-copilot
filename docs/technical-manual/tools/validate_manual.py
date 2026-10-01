#!/usr/bin/env python3
"""Documentation-only validator for the InsightValues Technical Manual.

Checks (no network, no product code touched, not wired into product CI):
  1. required chapters exist
  2. internal Markdown links resolve (files and heading anchors)
  3. Mermaid blocks start with a known diagram type
  4. glossary terms are unique
  5. backticked ALL_CAPS tokens belong to the status vocabulary or a known
     domain/identifier allowlist; forbidden promotions are flagged
  6. backticked repository paths exist at the checked-out SHA, unless the
     line is explicitly attributed to another evidence baseline
  7. secret-shaped strings are absent

Usage: python3 docs/technical-manual/tools/validate_manual.py
Exit code 0 = clean, 1 = errors found.
"""
from __future__ import annotations

import pathlib
import re
import sys

MANUAL_DIR = pathlib.Path(__file__).resolve().parent.parent
REPO_ROOT = MANUAL_DIR.parent.parent

REQUIRED = [
    "README.md", "00-document-control.md", "01-executive-technical-overview.md",
    "02-ecosystem-architecture.md", "03-core-commercial-flow.md", "04-ive.md", "05-aef.md",
    "06-projects-knowledge.md", "07-financial-intelligence.md", "08-impact-intelligence.md",
    "09-growth-intelligence.md", "10-data-architecture.md", "11-supabase.md",
    "12-edge-functions.md", "13-client-architecture.md", "14-security.md",
    "15-monetization.md", "16-automation.md", "17-testing.md", "18-ci-cd.md",
    "19-environments-deployment.md", "20-observability.md", "21-integrations.md",
    "22-mobile-web.md", "23-module-maturity-matrix.md", "24-verification-matrix.md",
    "25-architecture-decisions.md", "26-legacy-deprecation-register.md",
    "27-risk-register.md", "28-glossary.md", "29-source-evidence-index.md",
    "30-change-log.md",
]

STATUS_VOCAB = {
    "VERIFIED", "IMPLEMENTED", "TESTED", "DEPLOYED", "FUNCTIONAL", "EXPERIMENTAL", "LAB",
    "FROZEN", "PLANNED", "DEPRECATED", "NOT_IMPLEMENTED", "ENVIRONMENT_BLOCKED", "UNKNOWN",
    "CONFLICTING_EVIDENCE", "HISTORICAL_EVIDENCE_ONLY",
    "CURRENT", "LEGACY", "ABSORBED", "SUPERSEDED", "RECOVERED", "PROPOSED",
}
# Identifiers that legitimately appear in backticks but are not maturity statuses.
DOMAIN_TOKENS = {
    "SUCCESS", "FAILURE", "PARTIAL", "ROLLED_BACK", "NOT_EXECUTED", "READ_ONLY", "REVERSIBLE",
    "CONSEQUENTIAL", "REQUIRE_HUMAN_REVIEW", "ALLOW", "DENY", "AUTH_FAILED", "INVALID",
    "DENIED", "DUPLICATE", "HUMAN_REVIEW_REQUIRED", "PRO_ROLE_LIMIT", "INTERNAL", "DEPLOY",
    "BASELINE_REAL_VALIDATED_V1", "PAULO_TREND_FIBONACCI_V2_FIDELITY", "AEF_RUNTIME_LAB",
    "INSIGHTVALUES", "BUILD_SHA", "NOT", "APPLIED", "IN_FLIGHT", "COMPLETED", "OPEN",
}
ENV_PREFIXES = ("SUPABASE_", "STRIPE_", "GROQ_", "GOOGLE_", "APP_", "DENO_", "KEYSTORE_",
                "SOURCEMAP_", "GITHUB_", "AEF_", "ANTHROPIC_", "INSIGHTVALUES-")
FORBIDDEN_STATUS = {"PRODUCTION_READY"}

PATH_ROOTS = ("lib/", "supabase/", "aef/", "contracts/", "docs/", ".github/", "scripts/",
              "test/", "web/", "android/", "tool/")
OTHER_BASELINE_MARKERS = ("E-INT02", "E-QUANT", "E-AGENT", "E-SITE", "(unmerged)",
                          "E-INT02 only", "on E-INT02")

MERMAID_TYPES = ("flowchart", "graph", "sequenceDiagram", "erDiagram", "classDiagram",
                 "stateDiagram", "stateDiagram-v2", "gantt", "journey", "pie", "mindmap",
                 "timeline")

SECRET_PATTERNS = [
    (r"sk_(live|test)_[A-Za-z0-9]{10,}", "Stripe secret key"),
    (r"whsec_[A-Za-z0-9]{10,}", "Stripe webhook secret"),
    (r"sb_(publishable|secret)_[A-Za-z0-9_-]{10,}", "Supabase API key"),
    (r"gsk_[A-Za-z0-9]{20,}", "Groq key"),
    (r"AIza[0-9A-Za-z_-]{30,}", "Google API key"),
    (r"eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}", "JWT"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "private key"),
    (r"\b\d{10,14}-[a-z0-9]{32}\.apps\.googleusercontent\.com", "OAuth client id"),
    (r"\b[a-z]{20}\.supabase\.co\b", "Supabase project URL"),
]

errors: list[str] = []
warnings: list[str] = []


def slugify(heading: str) -> str:
    s = heading.strip().lower()
    s = re.sub(r"[`*_~]", "", s)
    s = re.sub(r"[^\w\- ]", "", s)
    return s.replace(" ", "-")


def anchors_of(path: pathlib.Path) -> set[str]:
    out = set()
    in_code = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("```"):
            in_code = not in_code
        if not in_code and line.startswith("#"):
            out.add(slugify(line.lstrip("#")))
    return out


def main() -> int:
    md_files = sorted(MANUAL_DIR.glob("*.md"))
    names = {p.name for p in md_files}
    for req in REQUIRED:
        if req not in names:
            errors.append(f"missing required chapter: {req}")

    anchor_cache = {p.name: anchors_of(p) for p in md_files}
    link_count = 0
    mermaid_count = 0
    path_checked = 0

    for p in md_files:
        text = p.read_text(encoding="utf-8")
        lines = text.splitlines()
        in_code = False
        code_lang = ""
        first_code_line = True
        for n, line in enumerate(lines, 1):
            if line.startswith("```"):
                if not in_code:
                    in_code, code_lang, first_code_line = True, line[3:].strip(), True
                else:
                    in_code = False
                continue
            if in_code:
                if code_lang == "mermaid" and first_code_line and line.strip():
                    mermaid_count += 1
                    if not line.strip().startswith(MERMAID_TYPES):
                        errors.append(f"{p.name}:{n}: unknown mermaid diagram type '{line.strip()}'")
                    first_code_line = False
                continue

            for pat, label in SECRET_PATTERNS:
                if re.search(pat, line):
                    errors.append(f"{p.name}:{n}: secret-shaped string ({label})")

            for m in re.finditer(r"\]\(([^)\s]+)\)", line):
                target = m.group(1)
                if target.startswith(("http://", "https://", "mailto:")):
                    continue
                link_count += 1
                file_part, _, anchor = target.partition("#")
                dest = (p.parent / file_part).resolve() if file_part else p
                if not dest.exists():
                    errors.append(f"{p.name}:{n}: broken link '{target}'")
                    continue
                if anchor and dest.suffix == ".md":
                    if anchor not in anchor_cache.get(dest.name, anchors_of(dest)):
                        errors.append(f"{p.name}:{n}: missing anchor '#{anchor}' in {dest.name}")

            other_baseline = any(mk in line for mk in OTHER_BASELINE_MARKERS)
            for m in re.finditer(r"`([^`]+)`", line):
                tok = m.group(1).strip()
                if re.fullmatch(r"[A-Z][A-Z0-9_]+", tok):
                    if tok in FORBIDDEN_STATUS:
                        errors.append(f"{p.name}:{n}: forbidden status '{tok}'")
                    elif tok not in STATUS_VOCAB and tok not in DOMAIN_TOKENS \
                            and not tok.startswith(ENV_PREFIXES):
                        errors.append(f"{p.name}:{n}: unknown status-like token '{tok}'")
                if tok.startswith(PATH_ROOTS) and not other_baseline:
                    candidate = tok.split()[0].rstrip(",;:)")
                    if any(ch in candidate for ch in "*<>{}"):
                        continue
                    candidate = re.sub(r":\d+(-\d+)?$", "", candidate)
                    path_checked += 1
                    if not (REPO_ROOT / candidate).exists():
                        errors.append(f"{p.name}:{n}: path not found at this SHA '{candidate}'")

    glossary = MANUAL_DIR / "28-glossary.md"
    if glossary.exists():
        seen: dict[str, int] = {}
        for n, line in enumerate(glossary.read_text(encoding="utf-8").splitlines(), 1):
            m = re.match(r"\|\s*([^|]+?)\s*\|", line)
            if not m or m.group(1) in ("Term", "---"):
                continue
            term = m.group(1).lower()
            if term in seen:
                errors.append(f"28-glossary.md:{n}: duplicate term '{m.group(1)}' (first at {seen[term]})")
            seen[term] = n

    print(f"chapters: {len(md_files)} | links checked: {link_count} | mermaid blocks: {mermaid_count} "
          f"| repo paths checked: {path_checked}")
    for w in warnings:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print("RESULT:", "PASS" if not errors else f"FAIL ({len(errors)} errors)")
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
