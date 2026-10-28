<!-- Format: MADR (Markdown Any Decision Record — a format for recording architecture decisions). -->

---
status: Accepted                                # Proposed → Accepted → Superseded by NNNN. This skill writes Accepted right away.
owner: "<decision owner — usually Architect>"   # Who is accountable for the decision
reviewers: []                                   # Who reviewed the ADR before merge (usually Tech Lead + Security if relevant)
updated_at: "<YYYY-MM-DD>"                      # Date of the last update (for Superseded — the replacement date)
feature_size: M                                 # XS/S/M/L/XL — inherited from the PRD
stage: "04-05"                                  # The SDLC stage where the ADR was born
ticket: "<ticket-id>"                           # The tracker ticket (Jira/Linear) that triggered the feature
---

# NNNN — <title in imperative: e.g. "Use sliding window for rate limiting">

<!-- Spawned by sdlc:architecture-design when a decision crosses the blast-radius threshold. -->
<!-- See sdlc/plugin/skills/architecture-design/references/blast-radius-heuristic.md -->
<!-- IMPORTANT: the title describes the DECISION, not the problem. -->
<!-- ✓ "Store a lesson as a table of blocks of different types"  -->
<!-- ✗ "Lesson storage strategy"                                  -->

- **Status:** Accepted
- **Date:** <YYYY-MM-DD>
- **Deciders:** <names — usually the Architect + the user during the Socratic walk>

## Context

<2-4 sentences: what is happening, why this decision needs to be made now. Pull from sad.md §3 (Context) + the section that triggered this ADR.>

<!-- Example (from 0001-content-storage-strategy.md):                                                         -->
<!-- "PRD §4 says: a methodist builds a lesson from mixed content — text + video + images.                    -->
<!--  Question: in what form do we store the lesson body in the DB? This is a foundational decision; the API, -->
<!--  the shape of the frontend editor and the ability to reorder blocks depend on it." (3 sentences)         -->

## Decision drivers

<bullets — the quality goals / constraints that pushed the choice>

- <e.g. NFR latency p95 ≤ 5 ms (PRD §NFR)>
- <e.g. Multi-tenant isolation requirement (PRD §Constraints)>
- <e.g. Existing Redis cluster — no new infra cost>

<!-- Principle: each bullet comes from PRD §6 NFR, or SAD §2 Constraints, or the §1 top-3 qualities. -->
<!-- Do NOT invent drivers — this filters out «pet decisions» (decisions from the architect's own preferences). -->

## Considered options

<List ALL options that were presented in AskUserQuestion, including the ones the user rejected. One-line summary each.>

1. **<Option A>** — <one sentence describing the option>.
2. **<Option B>** — <one sentence>.
3. **<Option C>** — <one sentence>.

<!-- IMPORTANT: every option that was really considered — including the ones the user rejected. -->
<!-- Do NOT add a straw man (an option the stack constraints already rule out) — that is a critic F6 error. -->

## Decision outcome

**Chosen:** Option <letter or name>. <1-2 sentences rationale — why this option won over the alternatives, referencing the decision drivers above.>

## Consequences

**Positive**
- <e.g. Per-tenant fairness — bursts in tenant A don't starve tenant B>
- <e.g. Reuses existing Redis cluster — no new infra>

**Negative**
- <e.g. ~30% more memory per key vs fixed window>
- <e.g. Counter math is slightly more complex to reason about>

**Neutral**
- <e.g. Migration to fixed window later is possible but requires data backfill>

<!-- An honest consequences log differs from «forgot» in that Negative and Neutral are filled in too, not only Positive. -->

## Links

<!-- Without this section the ADR is an orphan file. An ADR lives in three links to other files:            -->
<!--   1) up to the PRD (which user story triggered it)                                                    -->
<!--   2) up to SAD §N (which section it is attached to)                                                   -->
<!--   3) sideways to a neighbouring ADR (if together they form one contract)                              -->

- PRD: [[../PRD.md]]
- SAD: [[../sad.md]] §<N>
- Related ADR: <[[NNNN-other]] if any>
