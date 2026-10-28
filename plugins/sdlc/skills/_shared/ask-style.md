# Ask-style — junior-friendly `AskUserQuestion` in the user's language

> **Reference-only.** Not a skill. Every skill that calls `AskUserQuestion` reads this for the
> canonical shape of questions and options. The rule: an **option label is the next mechanical
> step the skill takes**, not just a name; the **description explains, in plain words, what will
> happen** — written so a first-year junior can pick correctly without a senior beside them.

> **Volume vs. style.** How **many** questions a Q&A skill asks scales with the interview-depth dial
> (easy asks few, hard asks all — see [`interview-depth.md`](./interview-depth.md)). The **per-question
> explanatory rule below is unchanged at every depth** — even a single easy-level question is glossed
> and explained in full. Depth tunes the count; it never licenses a dry question.

## The one rule that matters most

**Never ask dryly.** The most common failure is a terse, jargon-dense question — a few words plus acronyms, no context — that forces the user to already know the project to answer. Fix it two ways, every time:

1. **Gloss every technical term inline, on first use** — the plain meaning in parentheses, right there. Not «order by RICE» but «order by RICE — a quick score, Reach × Impact × Confidence ÷ Effort, where higher = more value per unit of work». Not «forces a worktree» but «forces a worktree — a separate working copy of the repo so two agents don't edit the same files». The reader should never have to look a term up to choose.
2. **Spend the words on the WHY and the trade-off**, not the WHAT. A short label is fine; the *description* is where you explain — in plain language — what happens, what you gain and lose, and the hidden catch.

If a question reads like a config dump or a spec excerpt, it's wrong. Write it as if explaining the choice to a capable colleague who just joined and doesn't know your acronyms yet. **More explanation always beats less here** — a long, clear description is a feature, not bloat.

## Shape

- **`question`** — 3–4 sentences in three blocks:
  - **CONTEXT** — why this decision, what scenario to picture, what exactly we're deciding (one sentence with a concrete example).
  - **WHY IT MATTERS** — which quality goal / NFR / PRD vector it touches; reversibility (irreversible? multi-module? affects performance / security / UX?); the main trade-off in play.
  - **READ OPTIONS** — a nudge to read the descriptions before choosing.
- **Each option**:
  - `label` — 1–5 words, **action form** = the next mechanical step: "Accept", "Fix", "Move to open question", "Discard", "Record as ADR". Add "(Recommended)" to the first option when you recommend it.
  - `description` — 3–5 sentences with four mandatory elements (below).

## The four mandatory elements of a `description`

1. **What technically happens** — concrete names: tables / endpoints / files / ADR numbers. Not «modify the API» but «add field `is_active BOOLEAN` to table `members` and a new route in the module's handler».
2. **What you gain / what you lose** — the trade-off in plain words, **every technical term glossed**:
   - not «backfill migration» → «a script that walks every existing row and fills the new field; while it runs the rows are read-locked for writes»
   - not «cursor pagination» → «the client sends the last id it saw so the next page starts after it; avoids `OFFSET`, which slows down on large pages»
   - not «GIN index» → «a special index type that lets you search inside JSON columns, but takes 3–5× more space and writes slower»
3. **The skill's next mechanical step** — «I spawn ADR-NNNN titled X, add a row to the §9 ADR table, the schema is locked for the data-model stage».
4. **Hidden trade-off** — if there's a condition under which the choice breaks («only works if Redis is already in your stack», «in 6 months you'll need downtime for a backfill», «existing users have to re-login»), state it **right in the description**, not in a follow-up. A junior won't see that trigger on their own.

## Language

- **Ask in the user's language, not the examples' language.** The question, every label, every description and the "Sources" line are written in the language the user converses in: the session's configured response language if the harness sets one, otherwise the language of the user's own recent messages. The skill files and every example in them are in English as reference only — translate them at ask time; never copy an example's language, and never switch language because an artifact (PRD, SAD) happens to be written in another one.
- Technical identifiers stay in their original form (ADR, JSONB, JWT, UUID, FK, OpenAPI, US-NN, AC-NN) — they are names. The *actions* (labels) are translated like the rest.
- Glossary roles and domain-invariant **names** (natural-language phrases like «no published lessons») are allowed — they are business terms.

## Forbidden

- Terse labels («Approve», «Edit», «Drop», «Reword») — in any language.
- One-line descriptions.
- Technical terms without a gloss (UNION, backfill, GIN, cursor, idempotent, transactional…).
- Trade-offs hidden in a follow-up («if you pick this I'll later ask about X, which has complexity Y»).

## Counter-example (deprecated) vs correct

```
# DON'T — opaque next step, no gloss
- label: "Approve"
  description: "Apply decision."

# DO — action-form label, description names the concrete step + glossed trade-off
- label: "Accept the JSONB column (→ spawn ADR-0002)"
  description: "One `body` column of type jsonb stores the whole array of blocks as JSON. PROS: editing a lesson is a single UPDATE; a new block type needs no schema migration. CONS: block validation moves to the app layer (the DB doesn't know the types); searching inside body needs a GIN index (a special Postgres index for searching inside JSON — 3–5× more space, slower writes). NEXT: I spawn ADR-0002 with the 3 options considered, add a row to §9, and the schema is locked for the data-model stage."
```

## The 4-state actions, phrased this way (canonical set)

```
- label: "Accept as is"
  description: "I keep the decision verbatim and run the next check (the gate, if this section has one)."
- label: "Fix"
  description: "You give the new wording/value; I regenerate the decision under the new constraint and ask once more (one round — the second answer is final)."
- label: "Move to open question"
  description: "I take the decision out of the section and add a row to the Open-Questions table with owner + due (asked next). Without both, the decision becomes Drop."
- label: "Discard"
  description: "I remove the decision. If it is mandatory, I reframe the options and ask once more; if optional, I leave it out with no replacement."
```

## Review of a derived artifact (diagrams, inventories, coverage rows)

Some stages don't make decisions — they **derive** an artifact from decisions earlier stages already approved: `complete-sequence-diagrams` draws flows from PRD §4/§5 + `sad.md` §5/ADRs + code; a C4 view renders SAD decisions. There the person answering (usually the Tech Lead) is a **reviewer**, not a designer: product behaviour was settled by the PM in `write-prd` / `clarify-prd`, architecture in `architecture-design`. A question that sounds like "which flows should exist?" or "take these 7?" hands them a decision that isn't theirs and that was already made.

So the question shape changes:

- **`question`** — CONTEXT says plainly what was generated and **from what**: "I generated the flow 'accept invite' from US-02, AC-04, AC-05 and sad §5." Then the prose description, then one **"Sources: …"** line — the source of the whole item and of each branch (US/AC id, `sad` section or ADR, code `file:line`, or "skill convention" for fixed mechanics). Then any **source gaps** — what the item needs but no source says, and which command owns it. Close with the ask: "Check that this matches the sources."
- **Options** — review actions, not design choices (canonical set below). No option invents new behaviour; a correction that would add behaviour no source has is routed back to its stage (`/sdlc:clarify-prd` for product, `/sdlc:architecture-design` for technical), not drawn here.

```
- label: "Correct — approve"
  description: "The diagram (or list) matches the sources in the 'Sources' line. I keep the block in the
    file as is, mark it reviewed and move to the next one. Nothing new enters the PRD or the SAD — you
    only confirm that I carried over decisions that were already made."
- label: "Mismatch with source — fix"
  description: "I carried something over wrong: e.g. AC-04 says 'show an error', but the diagram just
    ignores the invite. You name the source (US/AC, a sad section or ADR, file:line in the code) and
    what is off; I redraw that one block to match the source, check that the Mermaid parses, and show it
    again (one round — the second answer is final). If the fix adds behaviour that no source has, it is
    not a diagram fix but a source gap: I mark it and route it to /sdlc:clarify-prd or
    /sdlc:architecture-design."
- label: "Defer to OQ"
  description: "It can't be settled now whether the diagram is right (e.g. two sources contradict each
    other). I remove the block and add a row to the open-questions table (OQ — open question, a question
    with an owner and a due date); I ask for the owner and due next — without both it becomes 'Remove'.
    The US/AC coverage this block held is re-checked at the coverage step."
- label: "Remove"
  description: "The block is redundant — e.g. it duplicates another flow. I remove it from the file. If
    that leaves a US or AC uncovered, at the coverage step I derive it again from its source or mark it
    as a source gap — I never draw new behaviour myself."
```

For a whole derived list (e.g. the flow inventory before drawing) the first two options are enough: "Correct — approve" / "Mismatch with source — fix".

## Dry → explanatory (worked rewrite)

```
# TOO DRY (jargon-dense, no context — the failure to avoid):
Question: "Prioritize Next by RICE or manual?"
Options:
  - label: "RICE"
    description: "RICE score, ordered desc."
  - label: "Manual"
    description: "Manual order."

# EXPLANATORY (context + why + glossed terms — do this):
Question:
  "How should we decide the ORDER of the not-yet-started ideas in the roadmap's «Next» list?
   This only affects which problem we pick up next — nothing is committed yet, and you can always
   reorder. The trade-off: a scoring formula is more objective but takes a minute per idea; eyeballing
   it is faster but drifts with mood. Read both options below."
Options:
  - label: "Score each idea (Recommended)"
    description: "I rate every Next idea with RICE — a quick score = Reach (how many users it touches) ×
      Impact (how much it moves the needle, 3 down to 0.25) × Confidence (how sure we are, as a %) ÷
      Effort (rough person-weeks). It gives one sortable number per idea, so «Next» orders itself by
      value-per-effort. You can still override any ranking by hand. Costs ~a minute of estimating per idea."
  - label: "Just order them by hand"
    description: "No formula — you (or I) drag the ideas into the order that feels right; row position =
      priority. Faster and fine for a short list, but with many ideas it gets subjective and the order
      tends to drift over time. You can switch to scoring later if the list grows."
```

The dry version is unanswerable without knowing what RICE is; the explanatory version teaches the term in the act of asking and makes the trade-off obvious.

## Why (feedback, 2026-05-23 + reinforced 2026-05-29)

The user is a PM, methodist, or junior dev opening the repo for the first time. Terse questions give them neither the substance of the decision nor the difference between options. Feedback (2026-05-23, translated): "the explanations must be even clearer, for people who are literally juniors in development". Reinforced (2026-05-29, translated): "questions and answer options need to be more explanatory — right now Claude asks rather dryly and packs many terms into short text" — i.e. the dryness + term-density was still happening, so this file now leads with the "never ask dryly / gloss every term" rule above.

The language rule (2026-10-27): the plugin is described in English, and Claude translates every question into the language the user speaks — the examples' language must never decide it.
