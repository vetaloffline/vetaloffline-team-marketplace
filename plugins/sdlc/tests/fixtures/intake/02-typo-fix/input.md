# Fixture: intake / 02-typo-fix

## Scenario

XS feature (a typo fix in an error message). The skill is expected to **not** duplicate the MP-check, **not** create an ADR, **not** create CONTEXT (no domain terms).

## Pre-existing

(Nothing.)

## User input

```
/sdlc-intake fix-typo-in-429-message

Typo in the error message: «Too Many Reqests» → «Too Many Requests». 1 PR, under 1 day.
No migrations, no new API, no breaking changes.
```

## Expected behavior

- §A: creates `idea-brief.md` with Problem (typo), Users (everyone), Out-of-scope (all other error messages), Size=XS, Competitors=N/A (internal), RICE (low), Feasibility 3/3.
- §B: **skip** — no domain terms. It meets only «typo», «error message» — generic.
- §C: creates `brainstorm.md` with a minimal set (3 approaches: hotfix / wait for the next release / batch with other typo fixes). Recommendation = hotfix.
- §D: MP-check — hard-to-reverse=FAIL (a 1-line PR, revertible). The skill **does not propose an ADR** and says so transparently: «the recommendation is in brainstorm, no ADR needed — easy to redo (a 1-line change)».
- §E: **skip** (D failed).
- §F: one commit `01-02: intake for fix-typo-in-429-message (idea-brief + brainstorm)`.
- §G: proposes `sdlc:classify-size` (will be XS).

## Expected files

```
delivery/fix-typo-in-429-message/
├── idea-brief.md        # XS, RICE low, Feasibility 3/3
└── brainstorm.md        # 3 approaches, recommendation = hotfix, no **Locked in:** line
```

NO `CONTEXT.md`, NO `adr/` directory.

## Score against rubric.md

D1: only 2 files. No CONTEXT.md, no adr/. ✅ if the expected diff is clean.
D2: intake DoD met; propose-adr correctly REFUSED with a reason.
D3: the skill doesn't create an ADR for a trivial change (anti-pattern avoided).
D4: commit without the ADR-NNNN/CONTEXT bracketed parts.

## Why this catches a regression

If the skill created an ADR for a typo fix → the MP threshold is broken. Catch it early.
