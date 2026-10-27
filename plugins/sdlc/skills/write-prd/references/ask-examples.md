# `AskUserQuestion` examples — explanatory pattern for write-prd

How step 7 (Socratic batch loop) and step 8 (critic resolution) phrase questions and options. The contract from [socratic-loop.md](./socratic-loop.md) and [critic.md](./critic.md) is normative; this file shows the **shape** of the dialogue so options *describe what the skill will do*, not just *what they're labelled*.

## Shape

- **Question**: inline the full item content verbatim (US text, AC GWT, NFR row, KPI line, critic finding) + 1 sentence framing the choice.
- **Each option**:
  - `label` — 1-4 words, action-form: «Approve as-is», «Reword», «Drop», «Save as Open Question», «Add another AC», «Override».
  - `description` — 1 sentence explaining the mechanical next step (no PRD philosophy, no design rationale).

All four item-types (US / AC / NFR / KPI) share the same 4-state machine. AC has one extra optional 5th option (`Add another AC`). `Cancel` and `Reject` are synonyms for `Drop`.

## User-story validation (step 7)

```
Question:
  US-03 (As an editor, I want to publish an article, so that readers can access it).
  Is this story right as written, needs a tweak, should be deferred, or dropped?

Options:
  - label: "Approve as-is"
    description: "Skill keeps US-03 verbatim and moves to the next item."
  - label: "Reword"
    description: "You type the new wording in one go; skill regenerates US-03 with your wording and asks once more (last call — second answer is final)."
  - label: "Save as Open Question"
    description: "Skill removes US-03 from §4 and adds «- [ ] US-03 (text) — is it valid? — owner: <you-type>, due: <you-type>» to §8. Skill asks owner+due next. Without both, the resolution downgrades to Drop with a warning."
  - label: "Drop"
    description: "Skill deletes US-03, renumbers later stories (US-04 → US-03), and AC tagged with US-03 are reassigned or dropped — skill will ask which."
```

After `Save as Open Question`, the follow-up `AskUserQuestion`:

```
Question:
  US-03 is migrating to §8 Open Questions. Provide owner and due (YYYY-MM-DD or stage trigger like "before 6.9"). Both are mandatory — without them the migration downgrades to Drop.

Options:
  - label: "Provide owner + due"
    description: "You type «owner: <name/role>, due: <date or stage>» in one line; skill applies it to the §8 entry."
  - label: "Cancel — Drop instead"
    description: "Skill abandons the OQ migration and applies Drop to US-03 (deletes + renumbers)."
```

## Acceptance-criterion validation (step 7)

The skill first renders the full proposed AC list (7a), then issues one question per AC (7b):

```
Question:
  AC-04 (US-03, domain invariant) — Given an editor owns a draft article with no
  sections, When the editor attempts to publish the article, Then the system
  blocks the publication and tells the editor that at least one section must
  exist first.
  Is this criterion right as written, needs a tweak, should be deferred, or
  dropped? You can also request one more AC for this US.

Options:
  - label: "Approve as-is"
    description: "Skill keeps AC-04 verbatim in §5 and moves to the next AC."
  - label: "Reword GWT"
    description: "You type the new Given/When/Then in one go; skill regenerates AC-04 with your wording and asks once more (last call)."
  - label: "Save as Open Question"
    description: "Skill removes AC-04 from §5 and adds «- [ ] AC-04 (text) — is this AC valid? — owner: <you-type>, due: <you-type>» to §8. Skill asks owner+due next. If coverage gate breaks (this was the only domain-invariant AC), skill regenerates a replacement of the same type."
  - label: "Drop"
    description: "Skill deletes AC-04 and renumbers later AC. If AC-04 was the only domain-invariant for US-03, skill regenerates a replacement of the same coverage type and asks about it as an extra item."
  - label: "Add another AC"
    description: "Skill generates one more AC for US-03 in a coverage type not yet present on this US (e.g. cross-context if happy + error + invariant are already covered), then asks about the new AC."
```

## NFR-row validation (step 7)

```
Question:
  NFR row — Latency p95 for publishing an article: target ≤ 250 ms, measured via
  the `articles.publish` endpoint metric.
  Is this row right as written, needs a tweak, should be deferred, or dropped?

Options:
  - label: "Approve as-is"
    description: "Skill keeps the row verbatim and moves to the next NFR row."
  - label: "Edit target"
    description: "You type the new numeric target (e.g. ≤ 400 ms); skill updates the row and asks once more (last call)."
  - label: "Save as Open Question"
    description: "Skill removes the row from §6 and adds «- [ ] NFR row «<aspect>» — is this target valid? — owner: <you-type>, due: <you-type>» to §8. Skill asks owner+due next. Without both, the resolution downgrades to Drop."
  - label: "Drop"
    description: "Skill deletes the row from §6. No replacement (NFR is recommended-list, not coverage-gated)."
```

## KPI validation (step 7)

```
Question:
  KPI — Adoption rate of article publishing: baseline 0, target ≥ 25% of active
  editors within 30 days.
  Is this KPI right as written, needs a tweak, should be deferred, or dropped?

Options:
  - label: "Approve as-is"
    description: "Skill keeps the KPI verbatim and moves to the next KPI."
  - label: "Edit baseline/target"
    description: "You type new baseline / target / timeframe; skill regenerates the KPI line and asks once more (last call)."
  - label: "Save as Open Question"
    description: "Skill removes the KPI from §7 and adds «- [ ] KPI «<name>» — is this KPI valid? — owner: <you-type>, due: <you-type>» to §8. Skill asks owner+due next. Without both, the resolution downgrades to Drop."
  - label: "Drop"
    description: "Skill deletes the KPI from §7. No replacement (KPIs are recommended-list with a ≥3 floor; if drop takes count under 3, skill regenerates one extra KPI from a remaining RICE driver)."
```

## Critic-finding resolution (step 7.5)

```
Question:
  [F1] Approach C drift after US-06 reject — §1 Context ¶3 still cites
  «Approach C: Progressive Async Learning + Social Completion», but US-06
  (peer completion) was dropped during Socratic.
  idea-brief §13 names Approach C as the Recommendation.
  Suggested: amend §1 ¶3 to drop the social-completion claim, OR add US-06 back.
  How do you want to resolve it?

Options:
  - label: "Accept revert"
    description: "Skill applies the critic's suggested amendment verbatim — §1 ¶3 rewritten to drop social-completion. US-06 stays dropped."
  - label: "Accept amendment (different wording)"
    description: "You type the alternative wording for §1 ¶3; skill applies your wording, US-06 stays dropped."
  - label: "Override"
    description: "Skill keeps §1 ¶3 unchanged and emits a bullet in §1 ¶4: «Approach C drift after US-06 drop — overridden by author, rationale: <your reason>», so downstream skills see the deliberate choice. You provide the rationale next."
```

```
Question:
  [F6] AC-02 contains forbidden tokens — line: «When editor calls POST
  /articles/{id}/publish, Then API returns 409 with code article.no_sections».
  Hits: `POST`, `/articles/{id}/publish`, `409`, `article.no_sections`.
  Suggested: rewrite into business form (actor-observable outcome) — the
  HTTP/error/schema detail moves to stage 09 `sdlc:api-forge`.
  How do you want to resolve it?

Options:
  - label: "Rewrite into business form"
    description: "Skill rewrites AC-02 as «When the editor attempts to publish the article, Then the system blocks the publication and names the missing-sections invariant», then asks once more on the new wording (last call)."
  - label: "Override"
    description: "Skill keeps AC-02 unchanged and emits a bullet in §1 ¶4: «AC-02 implementation-leak — overridden by author, rationale: <your reason>». Use this only for a quoted glossary term; technical mapping belongs in stage 09."
```

## Anti-pattern: terse option labels

```
# DON'T — option label = next mechanical step is opaque
Options:
  - Approve
  - Edit
  - Reject

# DO — option label is action-form, description names the next concrete step
Options:
  - label: "Approve as-is"
    description: "Skill keeps the item verbatim and moves on."
  - label: "Reword"
    description: "You type the new wording; skill regenerates and asks once more."
  - label: "Save as Open Question"
    description: "Skill removes the item, adds it to §8 with owner+due (asked next)."
  - label: "Drop"
    description: "Skill deletes the item and renumbers later items."
```

## Junior-friendly explanations in the user's language (mandatory from 2026-05-23)

Every `AskUserQuestion` in this skill is worded so that **a junior developer or a PM without a technical background** can understand the substance of each PRD item (US / AC / NFR / KPI), the difference between the options and the consequences of the choice — without a helper next to them. The old template («1-sentence framing», 4-word labels) is deprecated.

### Mandatory shape

1. **Ask in the user's language** — per [`../../_shared/ask-style.md`](../../_shared/ask-style.md) → *Language*: the question, labels and descriptions follow the language the user converses in (the session's configured response language, else the user's own recent messages), never the language of the examples here. Technical identifiers (US-NN, AC-NN, NFR, KPI, GWT, AsyncAPI, OpenAPI) stay as they are — they are names; the option *actions* are translated like the rest.

2. **`question` field — 3-4 sentences** in three blocks:
   - **THE FULL TEXT of the item** verbatim (US text, AC GWT, NFR row, KPI line, critic finding) — as it was
   - **CONTEXT + WHY IT MATTERS** — where the item came from (which source: idea-brief / interview / NFR), which user scenario or quality vector it covers, what breaks if the item is wrong
   - **WHAT SPECIFIC THOUGHT IS NEEDED** — what to look at before choosing (the wording? GWT correctness? the number in the NFR? the owner in the KPI?)

3. **Option `description` — 3-5 sentences** with three mandatory elements:
   - **What technically happens in the PRD**: concretely — which line changes, which later items are affected (renumbering, AC tags reassigned, a KPI without an owner downgraded)
   - **What this option really means** in plain words, without jargon:
     - Not «GWT-form» → «the Given/When/Then format: «Given: the user is logged in; When: they press Submit; Then: 201 is returned and the resource is in the DB»»
     - Not «AC tagged with US-03 are reassigned or dropped» → «every AC that currently refers to US-03 (visible in the `AC-NN | US: US-03 | ...` rows) either moves to another US or is deleted along with it — the skill asks you about each one separately»
     - Not «cursor pagination» → «sending the client the last ID it saw»
     - Not «idempotent operation» → «the same action can be called several times and the result stays the same — publishing an already-published course again doesn't change the data»
   - **Hidden trade-off** — if the option has a consequence a PM/junior might not see (e.g. «Drop on US-03 deletes 4 more ACs; all of them belong to the core flow») — state it **right in the description**

### Forbidden

- Terse labels («Approve as-is», «Reword», «Drop») — in any language
- One-line descriptions
- Technical terms without a gloss (GWT, cursor, idempotent, NFR, SLA, RPO/RTO, etc.)
- Trade-offs hidden in a follow-up

### Counter-example (deprecated shape)

```
- label: "Approve as-is"
  description: "Skill keeps US-03 verbatim and moves to the next item."
```

### Correct (mandatory shape)

```
- label: "Accept US-03 as is"
  description: "The skill keeps US-03 verbatim in PRD §4 and moves on to US-04 without extra follow-ups. This means the wording of the role (editor), the intent (publish article) and the outcome (readers access) are fixed as the baseline — later changes only by re-running the skill or editing the file by hand. ACs linked to US-03 (via the `US: US-03` tag in the AC table) stay valid. If in idea-brief §13 Recommendation the «editor» role turns out to be outdated, the Phase-8 critic will raise it as strategic-vector drift."
```

### Why

The user in the PRD phase is most often a PM without a deep technical background, or a junior dev who just joined the team. Terse questions force them to stop and ask for clarification, which breaks the Socratic cadence and doubles the time spent on the PRD. Feedback from 2026-05-23 (translated): «the explanations must be even clearer, for people who are literally juniors in development» (context — sdlc:architecture-design, with the request to «build it not only into architecture but also into the idea brief and write-prd»).
