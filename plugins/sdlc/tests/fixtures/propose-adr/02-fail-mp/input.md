# Fixture: propose-adr / 02-fail-mp

## Scenario

A recommendation that **fails** the MP-check (an easily reversible choice between two HTTP clients with an identical API). Expected: a REFUSAL with a transparent reason, no ADR created.

## Pre-existing

```
delivery/http-client-pick/brainstorm.md
```

Contents (fragment):

```markdown
# Brainstorm — http-client-pick

## Options

### `requests` Python library
Pros: industry standard, well documented.
Cons: blocking.

### `httpx` Python library
Pros: async + sync API, modern.
Cons: a bit newer.

## Recommendation
`httpx` — async-ready for the future.
```

## User input

```
/sdlc-propose-adr http-client-pick

Recommendation — httpx. Is an ADR worth it?
```

## Expected behavior

1. Skill reads brainstorm.md.
2. Q1 hard-to-reverse: `< 1 day` (a library swap with an identical API). FAIL.
3. Threshold gate: ≥1 FAIL → STOP.
4. Skill explanation: «The recommendation `httpx` is recorded in brainstorm.md. No ADR needed — easy to redo (a library with an identical API, < 1 day rework).»
5. NO ADR created. NO backlink in brainstorm.

## Expected files

```
delivery/http-client-pick/
└── brainstorm.md   # UNCHANGED
```

NO `adr/` directory created.

## Score against rubric.md

D1: no new files. brainstorm unchanged.
D2: skill correctly identified FAIL and REFUSED with a reason (which criterion).
D3: skill did NOT create an ADR for a reversible choice. MP-threshold protection working.
D4: NO commit proposal (nothing changed).

## Why this catches a regression

If the skill created an ADR — the MP threshold is deflated, ADRs become noise. Catch it early.
