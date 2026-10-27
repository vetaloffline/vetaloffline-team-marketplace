# Fixture: propose-adr / 01-pass-mp

## Scenario

A recommendation that passes all 3 MP checks (PASS). Expected: an ADR stub with Status=Proposed + a backlink.

## Pre-existing

```
delivery/rate-limit-test/brainstorm.md
```

Contents of `brainstorm.md` (fragment):

```markdown
# Brainstorm — rate-limit-test

## Context
Per-tenant rate limit for a B2B platform.

## Options

### Redis token bucket
Pros: Redis existing, INCR+EXPIRE is simple.
Cons: SPOF if Redis is down.

### Nginx limit_req_zone
Pros: nginx existing.
Cons: the zone key is not the tenant.

### Envoy ratelimit
Pros: dedicated service.
Cons: one more component.

## Recommendation
Redis token bucket — Redis is already there, the cheapest integration.
```

## User input

```
/sdlc-propose-adr rate-limit-test

The recommendation from brainstorm is Redis token bucket. I want to record an ADR.
```

## Expected behavior

1. Skill reads brainstorm.md, extracts the recommendation and options.
2. Q1 hard-to-reverse: `≥ 3 days` (a storage change). PASS.
3. Q2 surprising in 6 months: `Yes — non-obvious, nginx existing` (PASS).
4. Q3 real trade-off: a programmatic check finds ≥3 finalists (Redis / Nginx / Envoy). PASS.
5. Threshold gate: 3/3 PASS → confirm.
6. User confirms creation.
7. Compute NNNN=0001, title=`token-bucket-with-redis`.
8. Copy template → `delivery/rate-limit-test/adr/0001-token-bucket-with-redis.md`. Pre-fill.
9. Add `**Locked in:** [[adr/0001-token-bucket-with-redis]] (status=Proposed)` after §Recommendation in brainstorm.md.
10. Commit `11-proposed: ADR 0001 token-bucket-with-redis for rate-limit-test (Proposed)`.

## Expected files

```
delivery/rate-limit-test/
├── brainstorm.md                      # MODIFIED — adds **Locked in:** line
└── adr/
    └── 0001-token-bucket-with-redis.md   # NEW — Status: Proposed
```

## Score against rubric.md

D1: ADR file exists with the expected name; brainstorm.md modified (`**Locked in:**` line added).
D2: propose-adr DoD met — all 3 MP-checks PASS, Status=Proposed, backlink in brainstorm.
D3: the title describes the decision (`token-bucket-with-redis`), not the problem (`rate-limiting`).
D4: commit prefix `11-proposed:`, ADR number 0001, title kebab-case.
