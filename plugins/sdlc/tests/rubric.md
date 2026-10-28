# Eval rubric

4 quality dimensions per fixture. Pass = all 4. A fail on any = regression caught.

## D1 — Output artefacts exist

The skill created the expected files in the right places.

Check:
```bash
diff -r docs/features/<slug>/ fixtures/<skill>/<scenario>/expected/
```

- Pass: all expected files present with the expected content (whitespace diff allowed).
- Fail: missing file OR extra file OR major content divergence.

## D2 — DoD criteria met

The skill passed its own `## Definition of Done` section.

Check (per skill):

### intake
- [ ] `idea-brief.md` with Problem/Users/Out-of-scope/Competitors/RICE/Feasibility.
- [ ] `brainstorm.md` with ≥3 approaches, risks (prob × impact), recommendation.
- [ ] (If domain terms) `CONTEXT.md` with `## Glossary`, no empty H2.
- [ ] (If MP-pass) `adr/NNNN-*.md` with Status=Proposed + a backlink in brainstorm.

### propose-adr
- [ ] All 3 MP-check questions asked.
- [ ] PASS path → ADR stub Status=Proposed + backlink.
- [ ] FAIL path → no ADR, refusal with a reason (which criterion failed).

### classify-size
- [ ] `docs/features/<slug>/.size` created with one of: XS/S/M/L/XL.
- [ ] The user confirmed the classification (no silent write).
- [ ] (If a PRD exists) synced with the frontmatter `feature_size:`.

### prep-review
- [ ] `review-checklist.md` ≤25 items.
- [ ] Each item has WHERE-context (which file/function it points to).
- [ ] Domain-relevant items (not only "no typos").

## D3 — No anti-patterns

The skill didn't violate its `## Anti-patterns` section.

Per-skill spot-checks:

### intake
- [ ] Doesn't duplicate the MP-check inline (delegates to propose-adr).
- [ ] Doesn't duplicate the CONTEXT bootstrap (delegates to fix-term).
- [ ] Single commit per phase (not 3-4 separate ones).

### propose-adr
- [ ] Doesn't propose an ADR on a rejected approach.
- [ ] Status=Proposed, not Accepted (Accepted — via decide-adr).
- [ ] The title describes the decision, not the problem.

### classify-size
- [ ] Not silent (asks for a confirm).
- [ ] The `.size` file is a one-liner, no frontmatter.

### prep-review
- [ ] ≤25 actionable items (not 50+).
- [ ] Domain items (not only generic «no typos / build passes»).

## D4 — Commit message correct

The skill proposes a commit in the right format.

Check:
- intake → `01-02: intake for <slug> (idea-brief + brainstorm[ + ADR-NNNN + CONTEXT])`
- propose-adr → `11-proposed: ADR NNNN <title> for <slug> (Proposed)`
- classify-size → `size: <slug> classified as <X>` (or as part of the intake commit)
- prep-review → `16: review-checklist for <slug>`

Pass: format matches (allow minor punctuation drift).
Fail: wrong stage prefix, missing slug, or the skill proposes git push (anti-pattern — only propose, don't execute).

## Aggregate score

| D1 | D2 | D3 | D4 | Result |
|:--:|:--:|:--:|:--:|--------|
| ✅ | ✅ | ✅ | ✅ | PASS — fixture green |
| any | ✅ | any | any | PARTIAL — investigate |
| any | ❌ | any | any | FAIL — regression caught |

D2 is the most important: DoD criteria define correctness. D1 catches missing files; D3 catches subjective drift; D4 catches integration breakage.

## Logging

Manual run results go in the git commit message when adding a fixture, or in an Issue if a regression was caught. Don't store results in the repo (they vary per session).
