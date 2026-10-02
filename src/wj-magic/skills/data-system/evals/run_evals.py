#!/usr/bin/env python3
"""Trigger-eval runner for the wj-magic `data-system` skill.

Zero third-party dependencies (stdlib only). This skill is a single skill with
internal modes (ARCHITECT / DOMAIN / MODEL / EXPERIMENT / CRITIC), so eval
cases either trigger `data-system` (with a target mode) or trigger nothing.

Modes:

  validate  Structurally validate evals/trigger-evals.json: schema, duplicate
            queries, that every positive `should_trigger` equals this skill's
            own name, and that each positive case names a known mode. Exits
            non-zero on any problem (CI-friendly).

  score     Build a manual grading worksheet or score a filled-in one. You run
            each query against the installed plugin, record whether the
            `data-system` skill actually fired (and which mode), and the runner
            reports trigger accuracy, mode accuracy, and no-trigger correctness.

Usage:
  python3 evals/run_evals.py validate
  python3 evals/run_evals.py score --template graded.json
  python3 evals/run_evals.py score --infile graded.json
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# This file lives at <skill>/evals/run_evals.py -> skill dir is parent of evals/.
SKILL_DIR = Path(__file__).resolve().parent.parent
SKILL_NAME = SKILL_DIR.name
EVALS_FILE = SKILL_DIR / "evals" / "trigger-evals.json"

KNOWN_MODES = {"ARCHITECT", "DOMAIN", "MODEL", "EXPERIMENT", "CRITIC"}

GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
RESET = "\033[0m"


def _c(text: str, color: str) -> str:
    return f"{color}{text}{RESET}" if sys.stdout.isatty() else text


def load_cases() -> list[dict]:
    if not EVALS_FILE.is_file():
        raise SystemExit(_c(f"ERROR: {EVALS_FILE} not found", RED))
    try:
        data = json.loads(EVALS_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(_c(f"ERROR: invalid JSON in {EVALS_FILE}: {exc}", RED))
    if not isinstance(data, list):
        raise SystemExit(_c("ERROR: top-level JSON must be an array", RED))
    return data


def validate() -> int:
    cases = load_cases()
    errors: list[str] = []
    warnings: list[str] = []
    seen: set[str] = set()
    mode_counts: dict[str, int] = {}
    pos = neg = 0

    for i, case in enumerate(cases):
        loc = f"case[{i}]"
        if not isinstance(case, dict):
            errors.append(f"{loc}: not an object")
            continue

        q = case.get("query")
        if not isinstance(q, str) or not q.strip():
            errors.append(f"{loc}: missing/empty 'query'")
        else:
            if q in seen:
                errors.append(f"{loc}: duplicate query")
            seen.add(q)

        if "should_trigger" not in case:
            errors.append(f"{loc}: missing 'should_trigger'")
            continue

        st = case["should_trigger"]
        if st is False:
            neg += 1
            if "mode" in case:
                errors.append(f"{loc}: no-trigger case must not declare a 'mode'")
        elif isinstance(st, str):
            pos += 1
            if st != SKILL_NAME:
                errors.append(
                    f"{loc}: should_trigger '{st}' != this skill '{SKILL_NAME}'"
                )
            mode = case.get("mode")
            if mode is None:
                errors.append(f"{loc}: positive case must declare a 'mode'")
            elif mode not in KNOWN_MODES:
                errors.append(
                    f"{loc}: unknown mode '{mode}' (known: {sorted(KNOWN_MODES)})"
                )
            else:
                mode_counts[mode] = mode_counts.get(mode, 0) + 1
        else:
            errors.append(
                f"{loc}: 'should_trigger' must be '{SKILL_NAME}' or false, "
                f"got {type(st).__name__}"
            )

    for mode in sorted(KNOWN_MODES):
        if mode not in mode_counts:
            warnings.append(f"mode '{mode}' has no positive eval case")

    print(f"skill: {SKILL_NAME}")
    print(f"cases: {len(cases)}  (positive: {pos}, negative: {neg})")
    print(f"positive cases per mode: {mode_counts}")

    for w in warnings:
        print(_c(f"WARN  {w}", YELLOW))
    for e in errors:
        print(_c(f"FAIL  {e}", RED))

    if errors:
        print(_c(f"\n{len(errors)} error(s). validation FAILED.", RED))
        return 1
    print(_c("\nvalidation PASSED.", GREEN))
    return 0


def make_template(outfile: Path) -> int:
    cases = load_cases()
    template = [
        {
            "query": c.get("query", ""),
            "should_trigger": c.get("should_trigger"),
            "expected_mode": c.get("mode"),
            "actual_trigger": None,  # fill: "data-system" or false
            "actual_mode": None,     # fill: mode name, or null if no-trigger
        }
        for c in cases
    ]
    outfile.write_text(json.dumps(template, ensure_ascii=False, indent=2), encoding="utf-8")
    print(_c(f"wrote grading template -> {outfile}", GREEN))
    print("Fill 'actual_trigger' (skill name or false) and 'actual_mode' per case,")
    print(f"then run:  python3 {Path(__file__).name} score --infile {outfile.name}")
    return 0


def score(infile: Path) -> int:
    try:
        graded = json.loads(infile.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(_c(f"ERROR reading {infile}: {exc}", RED))

    ungraded = [i for i, c in enumerate(graded) if c.get("actual_trigger") is None]
    if ungraded:
        raise SystemExit(
            _c(f"ERROR: {len(ungraded)} case(s) still have actual_trigger=null "
               f"(indices {ungraded[:10]}{'...' if len(ungraded) > 10 else ''})", RED)
        )

    def norm(v):
        return False if v is False else v

    total = len(graded)
    trigger_ok = sum(
        1 for c in graded if norm(c.get("should_trigger")) == norm(c.get("actual_trigger"))
    )

    # Mode accuracy only over cases that should trigger AND did trigger.
    mode_pairs = [
        c for c in graded
        if norm(c.get("should_trigger")) and norm(c.get("actual_trigger"))
    ]
    mode_ok = sum(1 for c in mode_pairs if c.get("expected_mode") == c.get("actual_mode"))

    neg_total = sum(1 for c in graded if norm(c.get("should_trigger")) is False)
    neg_ok = sum(
        1 for c in graded
        if norm(c.get("should_trigger")) is False and norm(c.get("actual_trigger")) is False
    )

    print(f"trigger accuracy: {trigger_ok}/{total} = {trigger_ok / total:.1%}")
    if mode_pairs:
        print(f"mode accuracy (triggered cases): {mode_ok}/{len(mode_pairs)} = {mode_ok / len(mode_pairs):.1%}")
    if neg_total:
        print(f"no-trigger correctness: {neg_ok}/{neg_total} = {neg_ok / neg_total:.0%}")

    mism = [c for c in graded if norm(c.get("should_trigger")) != norm(c.get("actual_trigger"))]
    mode_mism = [c for c in mode_pairs if c.get("expected_mode") != c.get("actual_mode")]
    if mism:
        print(_c(f"\n{len(mism)} trigger mismatch(es):", YELLOW))
        for c in mism:
            print(f"  want={c['should_trigger']!r:>14} got={c['actual_trigger']!r:<14} {c['query'][:56]}")
    if mode_mism:
        print(_c(f"\n{len(mode_mism)} mode mismatch(es):", YELLOW))
        for c in mode_mism:
            print(f"  want={c['expected_mode']!r:>12} got={c['actual_mode']!r:<12} {c['query'][:56]}")
    if not mism and not mode_mism:
        print(_c("\nperfect: no trigger or mode mismatches.", GREEN))
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("validate", help="structurally validate the eval file")
    sp = sub.add_parser("score", help="build a grading template or score a filled one")
    sp.add_argument("--template", metavar="OUT", help="write a blank grading template to OUT")
    sp.add_argument("--infile", metavar="IN", help="score a filled-in grading file")

    args = p.parse_args()
    if args.cmd == "validate":
        return validate()
    if args.cmd == "score":
        if args.template:
            return make_template(Path(args.template))
        if args.infile:
            return score(Path(args.infile))
        sp.error("provide --template OUT or --infile IN")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
