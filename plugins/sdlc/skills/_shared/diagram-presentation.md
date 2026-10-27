# Diagram presentation — how to confirm a diagram readably (never dump raw Mermaid)

> **Reference-only.** Not a skill. Any skill that asks the user to confirm a Mermaid diagram
> (`architecture-design` C4 §3/§5, `complete-sequence-diagrams` §6 flows; others may adopt it) follows this. The rule it enforces:
> **never paste raw Mermaid source into the terminal as the thing to confirm.** Raw `sequenceDiagram` /
> `C4Context` source is unreadable in a chat box — the user can't judge a flow from `participant A as …`
> lines. Confirm the diagram by a **plain-language description** of what it shows, while the actual
> source lands in the file (where Obsidian renders it) and, if a renderer is available, an image.

## Why

A dogfood run pasted raw `sequenceDiagram` blocks as the confirmation prompt. The user can't read arrows-as-text; they approve blind or get frustrated. The fix separates two concerns: the **source** goes where it renders (the `.md` file, an optional image), and the **question** is asked in prose the user can actually evaluate.

This composes with [`mermaid-check.md`](./mermaid-check.md) (which answers «does it parse?») and [`interview-depth.md`](./interview-depth.md) (which answers «ask per-diagram, or proceed?»). This file answers «how do I present it?».

## Procedure (per diagram)

1. **Write the diagram to its file first.** The `sad.md` §6 flow, the §3 C4Context block, etc. — that's where Obsidian renders it natively, so writing-first means the user can flip to the rendered view immediately. (This reverses the old «show then write» order: in practice «show» dumped raw source. Write-first makes the file the render surface.)
2. **Validate it parses** per [`mermaid-check.md`](./mermaid-check.md) (render-parse with `mmdc` if available, else the structural lint). A diagram that doesn't parse is never confirmed — fix it first.
3. **Describe it in prose** — the confirmation prompt is a plain-language account of what the diagram shows, not its source. Name the participants in words and walk the flow as a sentence or two, **including the key branches**. Example for a sequence flow:
   > «Flow 1 — read preferences: the member asks for their prefs → the handler asks the service → the service reads the store; if there's no saved row, it returns the on-by-default state instead of an error.»
   For a C4 view: «The Context shows the member and the admin talking to the Preferences system, which depends on the existing Identity system for who's-allowed and writes to one datastore.» Cover every actor/participant and every `alt`/`else` branch in words.

   **Then a provenance line.** A diagram is a picture of decisions already taken (PRD user stories / ACs, SAD sections, ADRs, existing code), so the prose ends with **"Sources: …"** — where the diagram as a whole and each branch come from:
   > "Sources: US-01; branch 'no saved row' — AC-03; participants — sad §5; cache read — ADR-0002."

   Anything the diagram shows that no source covers is named in the same line as a source gap ("source gap: the PRD doesn't say what the user sees on error → /sdlc:clarify-prd") — the skill doesn't decide it during the confirm. The question is then a **review**: "I generated this diagram from these sources — check that it matches them", never "how should … work?" or "which flows do we need?".
4. **Render an image if a renderer is available.** If `mmdc` (mermaid-cli) is on PATH (or `npx -y @mermaid-js/mermaid-cli`), **also** render the block to an image and reference its path so non-Obsidian users can see it too:
   ```bash
   mmdc -i docs/features/<slug>/sad.md -o docs/features/<slug>/_diagrams/<name>.png 2>&1   # one image per diagram, or per file
   ```
   Mention the path in the prose («rendered to `_diagrams/flow-1.png`»). If no renderer is available, the file + the prose description are enough — say so, don't block (graceful fallback, like the `mmdc` path in `mermaid-check.md`).

## Depth governs the ask (per [`interview-depth.md`](./interview-depth.md))

- **easy** → write the diagram + emit a **one-line prose summary** with its "Sources: …" per diagram, then **proceed** — no per-diagram `AskUserQuestion`. The summaries are batched into the easy-level assumptions ledger so the user can still veto any flow after the fact, but the skill doesn't stop on each one.
- **medium / hard** → the prose description + "Sources: …" line (step 3) + an `AskUserQuestion` **review per diagram**, using the review options from [`ask-style.md`](./ask-style.md) → *Review of a derived artifact* ("Correct — approve" / "Mismatch with source — fix" / "Defer to OQ" / "Remove"). On **"Mismatch with source — fix"**, take the reviewer's note — which source the drawing contradicts — and regenerate that one diagram to match it (one round, second answer final), then re-validate and re-describe. A note that adds behaviour no source has is a source gap, routed back to the stage that owns it, not drawn.

The question text is always the **prose description + the "Sources: …" line + the file/image path** — never the raw block. (If the user explicitly asks to see the source, show it; but the *default* confirmation channel is prose.)

## Discipline

- **Never** make the raw Mermaid source the thing the user confirms — that's the anti-pattern this file exists to kill.
- **Write before you ask** — the file is the render surface; asking before writing means there's nothing for the user to flip to.
- **Describe every branch**, not just the happy path — an `alt`/`else`/dead-letter branch the prose skips is a branch the user can't veto.
- **Name the source of every branch** — a branch without a "Sources" entry is either a skill convention (say so) or a source gap (say so); the reviewer checks the drawing against its sources, they don't design it.
- **Validate before you describe** — never describe (or render an image of) a diagram that doesn't parse; fix it per `mermaid-check.md` first.
- The prose is for the user; the source is for the file and `generate-data-model`/downstream. Keep the two channels separate.

## Where each skill calls this

- `architecture-design` — at the §3 C4Context and §5 C4Container confirms (steps 5–6): describe the context/containers in prose, don't paste raw C4 source as the question.
- `complete-sequence-diagrams` — at the §6 flow review (step 6): write each flow → validate → prose-describe + "Sources" → review-by-prose (or proceed at easy).

Each keeps only a one-line «present per [`diagram-presentation.md`]» pointer; the procedure lives here.
