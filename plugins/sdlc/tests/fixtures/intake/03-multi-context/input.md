# Fixture: intake / 03-multi-context

## Scenario

A multi-context repo with `CONTEXT-MAP.md`. `fix-term` is expected to ask which context to record the term in, and to write to the matching `<ctx>/CONTEXT.md`, not the root.

## Pre-existing

Place before running:
```
./CONTEXT-MAP.md            (with list of contexts: billing, runtime, admin)
billing/CONTEXT.md          (existing, with the definition `tenant — billable org`)
```

## User input

```
/sdlc-intake usage-metrics-export

A feature to export usage metrics — runtime context. The tenant runtime view
(separate from the billing tenant view).

Domain terms in play: «usage», «tenant» (runtime — this is a different view than the billing
tenant!), «export window». A brainstorm is needed: pull-based (cron) vs
push-based (event-driven).
```

## Expected behavior

- §A: creates `delivery/usage-metrics-export/idea-brief.md`. Detects multi-context at the first mention of «tenant» — asks: «which context?» options: billing / runtime / admin. The user picks `runtime`.
- §B: calls `sdlc:fix-term tenant --context runtime`. The skill creates `runtime/CONTEXT.md` (new) with `tenant — runtime view of billable org (compute/quota state). NOT billing tenant (billing CONTEXT.md), NOT user.` Detects the conflict with `billing/CONTEXT.md` and fixes it via disambiguation.
- §C: brainstorm — pull vs push vs hybrid (3 finalists).
- §D: MP-check — recommendation «event-driven push», hard-to-reverse=PASS, surprising=PASS, finalists=PASS. ADR pass.
- §E: creates `delivery/usage-metrics-export/adr/0001-event-driven-usage-export.md`.
- §F: commit.

## Expected files

```
delivery/usage-metrics-export/
├── idea-brief.md
├── brainstorm.md
└── adr/
    └── 0001-event-driven-usage-export.md
runtime/CONTEXT.md           # NEW — runtime context, with tenant disambiguation
billing/CONTEXT.md           # UNCHANGED — already existed
```

## Score against rubric.md

D1: critical — `runtime/CONTEXT.md` is created, not the root `CONTEXT.md`. `billing/CONTEXT.md` unchanged.
D2: fix-term DoD met (multi-context resolve + conflict-with-billing notation).
D3: no overwrite of the existing `billing/CONTEXT.md`.
D4: the commit refers to `runtime/CONTEXT.md`, not the root.

## Why this catches a regression

If the skill writes to the root `CONTEXT.md` → multi-context detection is broken; a reader 6 months later confuses the billing tenant with the runtime tenant.
