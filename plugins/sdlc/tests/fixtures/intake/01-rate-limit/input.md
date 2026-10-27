# Fixture: intake / 01-rate-limit

## Scenario

Full intake flow on a rate-limiting feature. The skill is expected to go §A interview → §B inline CONTEXT (for «tenant») → §C brainstorm → §D MP-check (PASS) → §E ADR stub.

## Pre-existing

(Nothing — clean start.)

## User input

```
/sdlc-intake rate-limiting-per-user

Context: 3 customers complained this week about 429s caused by other users.
One user sends 10k req/min and takes the rate limit down for everyone. Customers are B2B
on shared infra; the contract promises a per-tenant SLA.

Size: S (one week, 2-5 PRs).

Domain hint: we operate on «tenant» (a billable customer org with 1+ users —
NOT user). In the brainstorm consider: Redis token bucket vs Nginx limit_req_zone
vs Envoy ratelimit (3 finalists). I expect the recommendation to be Redis token bucket
(Redis is already there, the library is mature).
```

## Expected behavior

- §A: creates `delivery/rate-limiting-per-user/idea-brief.md` with Problem/Users/Why now/Out of scope/Size (S)/Competitors (Kong, Tyk, AWS API Gateway)/RICE (~240)/Feasibility (3/3).
- §B: during §A meets «tenant» → proactively proposes `sdlc:fix-term tenant`. The skill creates the root `CONTEXT.md` with `tenant — billable customer org with 1+ users. NOT user.`
- §C: creates `brainstorm.md` with 5-7 approaches, 3 finalists, recommendation = Redis token bucket.
- §D: MP-check — hard-to-reverse=PASS (≥3 days), surprising=PASS (Nginx alternative), real-trade-off=PASS (3 finalists). User confirms ADR creation.
- §E: creates `adr/0001-token-bucket-with-redis.md` with Status=Proposed. Backlink in brainstorm.md.
- §F: one commit `01-02: intake for rate-limiting-per-user (idea-brief + brainstorm + ADR-0001 + CONTEXT)`.
- §G: proposes `sdlc:classify-size`.

## Expected files

```
delivery/rate-limiting-per-user/
├── idea-brief.md        # DoD §1: Problem/Users/Competitors/RICE=240/Feasibility 3/3
├── brainstorm.md        # 3 finalists, recommendation, **Locked in:** [[adr/0001-...]]
└── adr/
    └── 0001-token-bucket-with-redis.md   # Status=Proposed
CONTEXT.md              # ## Glossary: - tenant — ...
```

## Score against rubric.md

D1: 5 files exist, no extras.
D2: all DoDs of intake + fix-term + propose-adr met.
D3: no inline MP-check duplication in intake; the ADR title describes the decision, not the problem.
D4: the commit message has the right prefix `01-02:` + the full list of files.
