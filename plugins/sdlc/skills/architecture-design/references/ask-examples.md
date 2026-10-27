# `AskUserQuestion` examples — explanatory pattern for architecture-design

## TL;DR (short intro)

This file shows **exactly how to word the questions to the user** at steps 7 (Socratic loop) and 8 (resolving the critic's findings).

Principle: an option label is **the skill's next action** («Accept», «Move to §11 OQ»), and an option description is **3-5 sentences on what technically happens** + **the trade-off in plain words, without jargon**. Not «modify the API» but «I'll add field X to table Y and route Z». Not «UNION-query» but «combining 4 SELECTs via SQL UNION — slower than reading from one table».

The canonical end-to-end example is **ADR-0001 «Store a lesson as a table of blocks of different types»** (`content-storage-strategy`) from a teaching LMS project: every fragment of this file below quotes it.

## General shape

The canonical question/option contract — junior-friendly, bilingual, label = next mechanical step, description = 3-5 sentences — lives in [`../../_shared/ask-style.md`](../../_shared/ask-style.md). Read that first. How Step 6 (Socratic batch loop) and Step 7 (critic resolution) phrase questions and options. The contract from [socratic-loop.md](./socratic-loop.md) and [critic-phase.md](./critic-phase.md) is normative; this file shows the **shape** of the dialogue so options *describe what the skill will do*, not just *what they're labelled*.

## Shape

- **Question**: 1 sentence framing the decision + (when useful) a 1-line «earlier decisions» recap so the user sees the dependency chain without scrolling.
- **Each option**:
  - `label` — 1-5 words, action-form: «Async via outbox events (Recommended)», «Sync HTTP call», «Save as Open Question», «Drop and re-frame», «Lock as ADR», «Override».
  - `description` — 1-2 sentences explaining the **mechanical next step** (no architecture philosophy, no design rationale beyond a 1-line WHY).

All decision-types (Surface / UI-architecture / Strategic / Building-block / Crosscutting bundle / Quality scenario / Risk entry / Open-architectural-decision) share the same 4-state machine: `Approve` / `Edit` / `Save as Open Question` / `Drop`. `Cancel` and `Reject` are synonyms for `Drop`.

## Target-surface decision (§4 — walked FIRST) — what exactly we build

> **Note.** This is the **first** §4 decision and the skill's headline mechanism: *which surface we build* — backend service, web frontend, mobile, CLI, worker, library. It is `multiSelect` (more than one can be picked). The Recommended set is derived from PRD §1 «for whom» + the §4 roles. >1 surface almost always → ADR (multi-module + irreversible). On resolution the skill writes `target_surfaces: [...]` into the SAD frontmatter, and §5 draws one container per surface. → `../../_shared/surfaces.md`

```
Question:
  §4 — WHAT EXACTLY do we build for course-lesson-mvp? (several can be picked)
  CONTEXT: PRD §1 says «the methodist builds a lesson in the browser, the learner reads the lesson in the browser». So
  there is a server part (storage + contract) and a browser UI. This decision is made FIRST in §4,
  because it gates §5 (one C4 container per surface) and every later stage (api-forge, tests, tasks).
  WHY IT MATTERS: >1 surface = a multi-module irreversible feature → ADR; it also decides which
  artifacts the later skills generate (the UI task layer, frontend test tiers, the contract shape).
  Read the descriptions before choosing.

Options:  # multiSelect
  - label: "backend-service + web-frontend (Recommended) (→ spawn ADR)"
    description: "We build both a backend service (owns the REST/JSON contract + storage) and a web frontend (a browser UI that CONSUMES the contract, doesn't create it). NEXT: I write target_surfaces: [backend-service, web-frontend] into the frontmatter; §5 draws TWO containers (API + web/SPA); a follow-on UI-architecture decision comes next (SSR / SPA / hybrid); api-forge will generate OpenAPI, break-tasks will add the `ui` layer, plan-tests will add the component / visual-regression / e2e-through-UI tiers. Multiple surfaces → I spawn an ADR for the choice itself."
  - label: "backend-service only (→ possibly no ADR)"
    description: "Only a server-side service with a contract (HTTP/REST or events); the UI already exists separately or isn't needed. NEXT: target_surfaces: [backend-service]; §5 — one API container; no UI task layer and no frontend tests. One surface → the blast radius usually doesn't fire on the choice itself."
  - label: "Save as Open Question"
    description: "I'll remove the surface decision from §4 and add a row to §11: «Open architectural decision: target surfaces — Open question — owner: <you type>, due: <you type>». Without surfaces §5 and every later stage are blocked, so owner+due are mandatory; without both — Drop."
  - label: "Drop and re-frame"
    description: "I'll discard the current set and ask again with a reworded one (e.g. I'll add mobile-app if an app is needed too). This decision is mandatory — a second Drop escalates to Save-as-OQ with owner=Architect."
```

## UI-architecture decision (§4 — one per declared UI surface)

> **Note.** Comes RIGHT AFTER Target-surface, once per declared UI surface (`web-frontend` / `mobile-app` / `desktop-app`). web → SSR / SPA / hybrid; mobile → native / cross-platform. Gated like any §4 strategic decision (often → ADR). Keep it light: do NOT draw a component tree / tokens / screens — the UI **reuses** the existing design system from `architecture-map.md` §Frontend. → `../../_shared/surfaces.md`

```
Question:
  §4 UI-architecture for web-frontend — how is the browser UI of the lesson editor rendered?
  CONTEXT: the methodist drags blocks on the fly (drag-and-drop), the learner reads a finished page.
  architecture-map.md §Frontend shows: the repo already has React + the design system @org/ui (Button, Card,
  Modal) + tokens in tokens.css.
  WHY IT MATTERS: this is an irreversible delivery choice (rewriting SSR↔SPA later = weeks). The UI REUSES
  the existing design system — we don't draw a new one.
  Read the descriptions.

Options:
  - label: "SPA consuming the API (Recommended) (→ spawn ADR)"
    description: "The browser client (React, the existing @org/ui) keeps the editor state locally and calls the backend's REST contract. Reordering blocks is optimistic and local, then a PATCH. PROS: instant drag-and-drop with no round-trip; a clean UI/contract split. CONS: duplicates a bit of validation logic on the client; the learner's SEO page needs a separate render. NEXT: I spawn an ADR named 'spa-consuming-rest-api', §5 draws a web/SPA container next to the API, screens are built from the existing @org/ui components + tokens (not new ones), break-tasks adds the `ui` layer."
  - label: "Server-rendered (SSR) (→ spawn ADR)"
    description: "The server returns ready HTML, interactivity only where needed. PROS: a simple learner page, good SEO. CONS: the editor's drag-and-drop needs a round-trip or islands of interactivity. NEXT: I spawn ADR 'server-rendered-ui', §5 draws the web container as part of the server deployment."
  - label: "Save as Open Question"
    description: "I'll remove the UI architecture from §4 and add a row to §11: «Open architectural decision: web UI-architecture — Open question — owner: Frontend Lead, due: <you type>». I ask for owner+due next."
  - label: "Drop and re-frame"
    description: "I'll discard the set and ask again (e.g. hybrid instead of pure SSR/SPA). The decision is mandatory for a declared UI surface — a second Drop escalates to Save-as-OQ."
```

## Strategic decision (§4 Solution strategy) — the canonical `course-lesson-mvp` example

> **Note.** This is the same example that lecture 6.4 (Slides 14-19) and beer-lms `adr/0001-content-storage-strategy.md` use end to end. The question is a real one from the `course-lesson-mvp` feature — «how do we store a lesson made of mixed content?». Notice: the option label = the skill's next action, not just the option's name. The description is 3-5 sentences with specifics (table names, ADR numbers), not «modify the storage».

```
Question:
  §4 Solution Strategy — How do we store a lesson with content_type=mixed (text + media)?
  Scenario: the methodist builds a lesson from blocks (text / video attachments / images),
  presses Publish; the learner then reads it; the methodist wants to reorder blocks on the fly.
  (Earlier decisions: §1 top-3 qualities — editing speed, rendering the learner's page;
   §2 the stack has Postgres + S3 for media; §3 actors methodist, learner.)

  IMPORTANT: blast-radius 3/3 — the decision is irreversible (methodists will fill dozens of lessons →
  a migration with downtime), it touches 3 modules (frontend editor / backend API / media processor),
  and there are honest alternatives. Expected → spawn an ADR.

Options:
  - label: "A table of blocks of different types + a separate media table (Recommended) (→ spawn ADR-0001)"
    description: "Two new tables: lesson_blocks (id, lesson_id, sequence INT, type, content) and media_blobs (id, s3_url, mime, …). The sequence column stores the order. PROS: the NFR p95 ≤500 ms per edit is met naturally — UPDATE one row (not a whole document); reordering is one transaction with a few UPDATEs on sequence. CONS: two new tables in the migration; UNIQUE(lesson_id, sequence) needs a separate neighbouring ADR. NEXT: I spawn ADR-0001 named 'content-storage-strategy', add a row to the §9 ADR table, the schema is locked for `sdlc:generate-data-model`."
  - label: "One whole JSON object in S3, metadata in the DB (→ spawn ADR-0001)"
    description: "The frontend editor serializes the whole lesson to JSON and puts it in S3 as lessons/{id}.json; the DB stores only lesson_id → s3_key + updated_at. PROS: one DB table instead of two; adding a new block type needs no schema migration. CONS: dragging one block makes the frontend send the whole lesson ≈100 KB; the NFR p95 ≤500 ms is at risk on large lessons; full-text search inside a lesson is impossible. NEXT: I spawn ADR-0001 with the option 'json-blob-in-s3', add a row to §9, the schema for `sdlc:generate-data-model` is lessons metadata only."
  - label: "Two separate entities text_blocks + media_blocks, JOIN at the API level (→ spawn ADR-0001)"
    description: "A clean split by content type. On GET /lessons/{id} the API makes two queries (SELECT from text_blocks and media_blocks) and merges the result by sequence. PROS: clean entity boundaries. CONS: 'mixed content' becomes a leaky abstraction, because the client stitches two separate shapes into one; an extra JOIN on every read; new block types (poll, code) will need new tables. NEXT: I spawn ADR-0001 with the option 'two-entities-join', add a row to §9."
  - label: "Save as Open Question"
    description: "I'll remove this decision from §4 and add a row to §11 Risks: «Open architectural decision: content storage strategy — Open question — Resolve before `sdlc:generate-data-model` — owner: <you type>». Next I'll ask you to enter owner + due in one line. Without both, the decision becomes Drop."
  - label: "Drop and re-frame"
    description: "I'll discard the current set of options and ask again with a reworded set (e.g. only structured options, if you rejected the JSON blob). Use it if the option set is missing an important dimension."
```

**What was not junior-friendly in the old version and how it was simplified:**

- It used to be an abstract «module-to-module integration» — now it is a concrete feature with a concrete scenario (the methodist builds a lesson).
- The option label used to be «Async via outbox events» — now «A table of blocks of different types + a separate media table (→ spawn ADR-0001)» with an explicit technical shape and the ADR name.
- The description used to be one sentence of jargon — now 3-5 sentences with PROS / CONS / NEXT and concrete numbers (p95, ≈100 KB, number of tables).

After `Save as Open Question`, the follow-up `AskUserQuestion`:

```
Question:
  Module-integration decision is migrating to §11 Open Decisions. Provide owner and due
  (YYYY-MM-DD or stage trigger like «before `/sdlc:break-tasks`»). Both mandatory.

Options:
  - label: "Provide owner + due"
    description: "You type «owner: <name/role>, due: <date or stage>» in one line; skill applies it to the §11 row."
  - label: "Cancel — Drop instead"
    description: "Skill abandons the OQ migration and applies Drop to the decision (removes from §4, no row in §11)."
```

## Building-block decision (§5)

```
Question:
  §5 Building blocks — Where does the rate-limiter logic live?
  (Earlier: §4 chose sliding-window + Redis; Explore shows APIGW middleware layer exists.)

Options:
  - label: "Middleware in APIGW (Recommended)"
    description: "Reuses APIGW lifecycle, no new deployment unit, ~80 LOC. Likely no ADR (small blast radius). Skill keeps decision verbatim, runs blast-radius gate."
  - label: "New module internal/modules/ratelimit/"
    description: "Cleaner module boundary, easier to unit-test in isolation. Cost: new module wiring + extra deployment surface. Skill keeps decision verbatim, runs blast-radius gate."
  - label: "Save as Open Question"
    description: "Skill removes the decision from §5 and adds a §11 row: «Open architectural decision: rate-limiter location — Open question — owner: <you-type>, due: <you-type>». Skill asks owner+due next. Without both, downgrades to Drop."
  - label: "Drop and re-frame"
    description: "Skill discards the current option set and asks once more with reframed options. Building-block decisions are mandatory — second drop escalates to Save as OQ with owner=Architect + warning."
```

## Crosscutting bundle (§8)

```
Question:
  §8 Crosscutting concepts — Logging / auth / errors / IDs.
  Defaults from CLAUDE.md: slog structured JSON / JWT via session middleware / domain
  sentinel → apperr JSON / UUID v7 in app layer. Override any of these for this feature?

Options:
  - label: "Keep CLAUDE.md defaults (Recommended)"
    description: "Skill writes §8 table referencing CLAUDE.md sections, no per-feature overrides. Fastest, consistent with rest of repo."
  - label: "Override one or more"
    description: "You type which crosscutting concept needs a feature-specific override + the reason; skill regenerates §8 with the override row + asks once more. Use only when PRD §6 NFR or §6.1 Security signals it (rare)."
  - label: "Save as Open Question"
    description: "Skill removes the §8 row and adds a §11 row: «Open architectural decision: crosscutting overrides — Open question — owner: <you-type>, due: <you-type>». Skill asks owner+due next."
  - label: "Drop and re-frame"
    description: "Skill discards the bundle and asks per-concept individually (slog? auth? errors? IDs?). Use when you want granular review of plumbing."
```

## Quality scenario (§10)

```
Question:
  §10 Quality requirements — QG-1 (Availability under partial failure).
  When: downstream perf module returns 5xx for ≥30s; Then: goals writes still succeed
  (PRD NFR p95 ≤ 250ms holds); How verify: chaos drill (kill perf pod for 60s, observe
  goals.write_success_rate ≥ 99.5%).
  Approve the scenario verbatim, edit, defer, or drop?

Options:
  - label: "Approve as-is"
    description: "Skill keeps QG-1 scenario verbatim in §10 and moves to QG-2."
  - label: "Edit verification method"
    description: "You type the new How-verify (e.g. «load test with k6 — 10k RPS for 5 min»); skill regenerates QG-1 and asks once more (single-iteration cap)."
  - label: "Save as Open Question"
    description: "Skill removes QG-1 scenario from §10 and adds a §11 row: «Open architectural decision: QG-1 verification method — Open question — owner: SRE, due: before `/sdlc:plan-tests`». Skill asks owner+due next."
  - label: "Drop"
    description: "Skill removes QG-1 from §10 and re-prompts you to pick a replacement Quality Goal from PRD NFR. §1 Top-3 must remain ≥3 — this is a coverage-floor case."
```

## ADR-gate decision (after Approve fires blast-radius)

```
Question:
  Blast-radius gate after «Async via outbox events» Approved.
  Score: irreversible (3 days+ rework after data accumulates) + multi-module (events
  cross goals/perf module boundaries).
  Lock as ADR or inline only?

Options:
  - label: "Lock as ADR (Recommended)"
    description: "Skill creates adr/0001-async-outbox-for-module-integration.md from the AskUserQuestion options + your rationale; adds a row to §9 ADR table; commits sad §4 + adr/0001 together in Step 6e."
  - label: "Inline only"
    description: "Skill writes the decision into §4 with rationale paragraph but no ADR file. Use when the decision feels small-blast-radius despite 2+ criteria firing — typical only for §8 crosscutting or §5 internal layout."
```

## Critic-finding resolution (Step 7)

```
Question:
  [F1] Strategic-vector drift — §4 caps «async via outbox events» (DEC-§4-modulesIntegration
  Approved at Step 6d), but §6 Critical flow 1 «happy-path goal create» shows synchronous
  call from goals → perf without outbox emit.
  PRD §6 NFR QG-1 cites availability under partial failure as dominant (line 47).
  Suggested: amend §6 flow 1 to insert outbox emit between goals.write and perf.update,
  OR mark §4 outbox decision as preliminary and re-open it in next pass.
  How do you want to resolve it?

Options:
  - label: "Accept revert"
    description: "Skill applies the critic's suggested amendment verbatim — §6 flow 1 regenerated with outbox emit step. §4 stays unchanged."
  - label: "Accept amendment (different wording)"
    description: "You type the alternative wording for §6 flow 1 (or which sad section to amend differently); skill applies your wording."
  - label: "Override"
    description: "Skill keeps §6 unchanged and emits a bullet in §1 ¶4: «Strategic-vector drift in §6 flow 1 — overridden by author, rationale: <your reason>», so downstream skills (`sdlc:complete-sequence-diagrams`, `sdlc:api-forge`) see the deliberate choice. You provide the rationale next."
```

```
Question:
  [F5] §3 C4 Context block left as template stub — Mermaid block contains placeholder
  `Person(user, "<User>", "<role + intent>")` instead of real actors from CONTEXT glossary
  + PRD §4 US.
  Suggested: regenerate §3 C4Context block with real actors (IC, EM, HR per CONTEXT) +
  external systems from the architecture-map / scan (Postgres, notification-service).
  How do you want to resolve it?

Options:
  - label: "Accept regenerate"
    description: "Skill regenerates §3 C4Context block from CONTEXT glossary + PRD §4 US + the architecture-map / scan. Skill asks once more on the regenerated block (single-iteration cap)."
  - label: "Accept amendment (different wording)"
    description: "You type the Mermaid block contents; skill applies your version verbatim."
  - label: "Override"
    description: "Skill keeps §3 unchanged and emits a §1 ¶4 bullet: «§3 C4 stub left intentional — overridden by author, rationale: <yours>». Use rarely — downstream skills (`sdlc:complete-sequence-diagrams`) need C4 Context for the flow passes."
```

```
Question:
  [F6] §10 QG-2 references a number not in PRD — scenario says «p99 ≤ 100ms» but PRD
  §6 NFR only specifies p95 (≤ 250ms) and «no p99 target this phase».
  Suggested: rewrite QG-2 to use p95 target from PRD verbatim, OR add p99 target to PRD
  §8 Open Questions before continuing.
  How do you want to resolve it?

Options:
  - label: "Rewrite into PRD-cited form"
    description: "Skill regenerates QG-2 with PRD §6 NFR p95 ≤ 250ms verbatim. Skill asks once more on the new scenario."
  - label: "Override"
    description: "Skill keeps QG-2 unchanged and emits §1 ¶4 bullet: «§10 QG-2 p99 target — overridden by author, rationale: <yours>». Use only when you're committed to PRD §8 follow-up (own the back-port to PRD)."
```

## Anti-pattern: terse option labels

```
# DON'T — option label = next mechanical step is opaque
Options:
  - Approve
  - Edit
  - Reject
  - Defer

# DO — option label is action-form, description names the next concrete step
Options:
  - label: "Approve as-is"
    description: "Skill keeps decision verbatim, runs blast-radius gate next."
  - label: "Edit"
    description: "You type new wording; skill regenerates and asks once more."
  - label: "Save as Open Question"
    description: "Skill removes decision, adds §11 row with owner+due (asked next)."
  - label: "Drop"
    description: "Skill removes decision. If mandatory, re-asks with reframed options once; if optional, leaves it out."
```

## Junior-friendly explanations in the user's language (mandatory from 2026-05-23)

Every `AskUserQuestion` in this skill is worded so that **a first-year junior developer** can understand the substance of the decision, the difference between the options and the consequences of each — without a helper next to them. The old template («1-line WHY», 5-word labels) is deprecated for Step 6 + Step 7.

### Mandatory shape

1. **Ask in the user's language** — per [`../../_shared/ask-style.md`](../../_shared/ask-style.md) → *Language*: the question, labels and descriptions follow the language the user converses in (the session's configured response language, else the user's own recent messages), never the language of the examples here. Technical identifiers (ADR, JSONB, JWT, UUID, FK, GIN) stay as they are — they are names; the option *actions* are translated like the rest.

2. **`question` field — 3-4 sentences** in three blocks:
   - **CONTEXT** — why this question, what scenario to picture, what exactly we are deciding (in one sentence with an example)
   - **WHY IT MATTERS** — which QG / NFR / PRD vector it touches; blast radius (irreversible? multi-module? affects performance / security / UX?); the main trade-off in play
   - **OPTIONS BELOW** — a nudge to read the descriptions before choosing

3. **Option `description` — 3-5 sentences** with four mandatory elements:
   - **What technically happens**: concrete names of tables / endpoints / files / ADR numbers. Not «modify the API» but «I'll add the field `is_methodist BOOLEAN` to the `org_members` table and a new route `POST /courses` in `internal/modules/course/ports/handler.go`».
   - **What we gain / what we lose** — the trade-off in plain words, without jargon:
     - Not «backfill-migration» → «a script that walks every existing row in the table and fills in the new fields; while it runs the DB is readable, but writes to those rows are blocked»
     - Not «UNION-query» → «combining 4 separate SELECTs into one result via SQL UNION — slower than reading from one table»
     - Not «GIN indexing» → «a special Postgres index type that lets you search inside JSON fields, but takes 3-5× more space and writes slower»
     - Not «cursor pagination» → «sending the client the last ID it saw, so the next page starts from it; avoids `OFFSET`, which slows down on large pages»
   - **The skill's next mechanical step**: «I spawn ADR-NNNN named X, add a row to the §9 ADR table, the schema is locked for `sdlc:generate-data-model`»
   - **Hidden trade-off** — if there is a condition under which the decision breaks («this only works if you already have Redis in the stack», «in 6 months you'll need downtime for a backfill», «UX changes for existing users and they'll have to log in again») — state it **right in the description**, not in a follow-up. A junior won't see that trigger on their own.

### Forbidden

- Terse labels («Approve», «Edit», «Drop», «Reword») — in any language
- One-line descriptions
- Technical terms without a gloss (UNION, backfill, GIN, cursor, idempotent, transactional, etc.)
- Trade-offs hidden in a follow-up («if you pick this I'll later ask about X, and it has complexity Y»)

### Counter-example (deprecated shape)

```
- label: "Approve"
  description: "Apply decision."
```

### Correct (mandatory shape)

```
- label: "Accept the JSONB column (→ spawn ADR-0002)"
  description: "One lessons.body column of type jsonb that stores the whole array of blocks as JSON: [{type:\"text\",content:\"...\"},{type:\"video_embed\",url:\"...\"}]. PROS: atomic editing of a lesson with one UPDATE; adding a new block type in v2 needs no schema migration (only the app validator changes). CONS: block validation lives explicitly in the app layer (the DB doesn't know the types); full-text search inside body needs a GIN index (a special Postgres index type for searching inside JSON, 3-5× more space and slower writes). NEXT: I spawn ADR-0002 with the 3 options considered, add a row to the §9 ADR table, the schema «jsonb NOT NULL DEFAULT '[]'::jsonb» is locked as the contract for `sdlc:generate-data-model`."
```

### Why

The user is a PM, methodist or junior dev opening the repository for the first time. Terse questions give them neither the substance of the decision nor the difference between the options. That breaks the Socratic cadence and makes the skill usable only by seniors with full context. Feedback from 2026-05-23 (translated): «the explanations must be even clearer, for people who are literally juniors in development».
