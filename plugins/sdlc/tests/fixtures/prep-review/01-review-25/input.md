# Fixture: prep-review / 01-review-25

## Scenario

An M-size feature, PRD + sad.md + tasks/_epic.md ready. Expected: review-checklist.md with ≤25 items, domain-relevant, each with WHERE-context.

## Pre-existing

```
delivery/usage-metrics-export/
├── .size                          # M
├── PRD.md
├── sad.md
├── data-model.md
├── api/openapi.yaml
├── adr/0001-...md                 # Accepted
└── tasks/
    ├── _epic.md
    ├── tracker.md
    └── <task-slug>.md             # ≥1 story file
```

## User input

```
/sdlc-prep-review usage-metrics-export
```

## Expected behavior

1. Prereq check: PRD.md + sad.md + tasks/_epic.md exist — OK.
2. Read PRD AC/NFR, sad.md §6 runtime + §11 risks, `tasks/_epic.md` scope.
3. Read the ADR for consequences (what to monitor after merge).
4. Copy template → `review-checklist.md`.
5. Generate ≤25 actionable items grouped by category:
   - **Correctness** (5-7): tenant isolation, parquet schema versioning, watermark advance, etc.
   - **Performance** (3-4): p95 latency on the endpoint, S3 batch size, no N+1.
   - **Security** (2-3): IAM role scope, S3 bucket policy, no PII leak.
   - **Tests** (3-5): unit for the transformer, integration with S3, idempotency replay.
   - **Operability** (2-3): metrics emission, alert thresholds, runbook updated.
6. Each item has a WHERE: a file/function reference + 1-2 sentences of why.
7. Self-check: ≤25 items, all actionable, all with WHERE.
8. Commit `16: review-checklist for usage-metrics-export`.

## Expected files

```
delivery/usage-metrics-export/
└── review-checklist.md      # NEW — ≤25 items, grouped, with WHERE
```

## Score against rubric.md

D1: review-checklist.md created.
D2: ≤25 items; all actionable; all with WHERE; domain-relevant (specific to usage export, not generic).
D3: does NOT contain «no typos», «no debug logs», «no obvious bugs». Items refer to specific files/functions.
D4: commit prefix `16:`.

## Why this catches a regression

If the checklist is >25 → it becomes noise, nobody reads it. If it is generic-only — the review is uneven. Both caught.
