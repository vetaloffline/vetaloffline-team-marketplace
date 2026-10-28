---
name: user-documentation
model: sonnet
effort: medium
agents: [explorer, doc-flow]
description: >-
  Use to generate END-USER documentation for a LIVE web application: Playwright walks the app,
  captures state screenshots (optional screencast replays), and clean-context doc-flow subagents
  write one flow guide each in the reference style, finished with a linked User Guide index.
  Detects the target automatically (Obsidian vault → wikilink embeds, repo docs/ → markdown
  embeds). Triggers on "generate user documentation", "document the app flows", "user guide from
  the live app", "згенеруй користувацьку документацію", "задокументуй флоу застосунку",
  "юзер-гайд по застосунку", "/sdlc:user-documentation <target-dir>". Hard-refuses if no dev
  server is reachable or playwright-cli is not installed.
triggers:
  - /sdlc:user-documentation
  - "generate user documentation"
  - "document the app flows"
  - "user guide from the live app"
  - "згенеруй користувацьку документацію"
  - "задокументуй флоу"
stage: "util"
---

# Skill: user-documentation (cross-cutting — live application → user documentation)

Generates **user** (not dev) documentation from a live web application: a flow inventory →
a deterministic run of each flow in the browser with an action journal and state screenshots → a separate
clean-context agent writes one flow document strictly from the journal → a thin User Guide index with links
to all flows. Optionally — screencasts by replaying the journal. The source of truth for style is
[`./references/style-guide.md`](./references/style-guide.md); for reproducibility —
[`./references/determinism.md`](./references/determinism.md).

The browser channel is **`playwright-cli`** (the plugin's canon, see `verify-ui`): a token-efficient CLI
for loops. Playwright MCP in the pipeline is a documented anti-pattern.

**Owner:** the parent orchestrator (this skill) owns the manifest, the gate, the index and coherence;
each flow as a whole (browser + text) belongs to one `sdlc:doc-flow` agent.

## When to use

- The product has a UI that already runs on dev/staging, and a «how to use it» user guide is needed —
  with real screenshots, not imagined ones.
- Updating the documentation after noticeable UI changes (regeneration — the same protocol).
- NOT for dev docs (architecture/API — those are backbone stages), NOT for static sites without flows.

## Inputs

```
/sdlc:user-documentation <target-dir> [--flows a,b,c] [--video] [--base-url URL] [--embed wikilink|markdown]
```

- `<target-dir>` — the folder the documents go into (a vault folder or the repo's `docs/user-guide/`).
- `--flows` — an explicit list of slugs; without it the list is built by the inventory (step 4).
- `--video` — after the docs, generate screencasts by replaying the journals.
- `--base-url` — the application's address; without it we ask the user at step 2.
- `--embed` — force the embed syntax; without it — auto-detect (step 1).

**Gate (hard refuse):**

1. `playwright-cli --version` fails → refuse with instructions:
   `npm install -g @playwright/cli@latest && npx playwright install chromium`.
2. The dev server doesn't respond at `<base-url>` → refuse: «start the application and retry» (we
   don't invent state — the `verify-ui` precedent).
3. The auth strategy is unknown → AskUserQuestion (options: no auth / login steps /
   a ready state file / a service token). No answer → refuse.

## Protocol

1. **Detect the target and the syntax.** Walk up from `<target-dir>` to the root: found `.obsidian/` →
   vault → `embed_syntax: wikilink`; otherwise → `markdown`. `--embed` overrides. Paths with
   spaces (an iCloud vault) — always quoted.
2. **Gate** (see above) + record the `base_url` and the product name.
3. **Auth bootstrap** (once per role, done by the PARENT): go through the login with the chosen strategy →
   `playwright-cli -s=docgen-auth state-save` → `<target>/.docgen/auth-<role>.json` → close
   the session. Subagents only `state-load` — no agent logs in by itself.
4. **Flow inventory** → the protocol in [`./references/flow-inventory.md`](./references/flow-inventory.md):
   merge three sources (`--flows` / a repo scan via `sdlc:explorer`, fallback `Explore` / a live
   navigation `snapshot`); classify each flow by `doc_type` (task-flow / state-reference /
   auth) and `mutates` (whether it changes data). AskUserQuestion: confirm the list + types + scope.
   **After confirmation the list is frozen.**
5. **Manifest** `<target>/.docgen/flows-manifest.json` + create the folders `screenshots/<slug>/`:

   ```json
   {
     "product_name": "Beer LMS",
     "base_url": "http://localhost:5173",
     "target_dir": "/abs/path/to/target",
     "embed_syntax": "wikilink",
     "viewport": { "capture": "1280x800", "publish_width": 780 },
     "video": false,
     "data_prefix": "Docgen:",
     "flows": [
       {
         "slug": "create-session",
         "title": "Create Mentorship Session",
         "doc_type": "task-flow",
         "mutates": true,
         "start_url": "/mentorship",
         "auth_state": ".docgen/auth-mentor.json",
         "scope": "list → create dialog → toast; no edit/delete",
         "out_file": "Flow - Create Mentorship Session.md",
         "screenshots_dir": "screenshots/create-session",
         "journal": ".docgen/journals/create-session.jsonl",
         "session": "df-1",
         "status": "pending"
       }
     ]
   }
   ```

6. **Fan out `sdlc:doc-flow`** (fallback: general-purpose with the same prompt). **Batch
   by `mutates`, not by count**: read-only flows in parallel in batches of ≤3; mutating ones STRICTLY
   SEQUENTIALLY after the read-only ones (concurrent mutations of a shared DB spoil the neighbours' screenshots: agent A
   creates a record in the middle of B's run — and B's list differs between its own steps). The prompt
   to each agent inlines (clean context — the agent doesn't see this conversation):
   - worker preamble: «execute directly, do not spawn sub-agents, use tools directly, report
     results with absolute file paths»;
   - its JSON entry from the manifest (with absolutized paths) + the global fields (`base_url`,
     `embed_syntax`, `data_prefix`, `product_name`);
   - absolute paths: style-guide, determinism, template
     `${CLAUDE_PLUGIN_ROOT}/skills/user-documentation/templates/flow-doc.md`, auth-state;
   - **the names of all flows in this run** — Related Flows links only to planned docs, not
     invented ones;
   - cwd hygiene: run every playwright-cli command from its own temporary folder (the
     `.playwright-cli/` artifacts land in the cwd and must not litter the target/vault);
   - short session names (`df-<n>` by flow index) — longer ones hit the unix-socket
     path limit (determinism.md §5).

   The expected final line is the sentinel `DOCFLOW_OK ...` / `DOCFLOW_FAIL ...`. On FAIL —
   **1 retry**; FAIL again → `status: failed` in the manifest, the pipeline continues.
7. **User Guide index** (parent): from the H1 + lead paragraph of each finished doc + the manifest, build
   a thin `<Product> - User Guide.md` per
   [`./templates/user-guide-index.md`](./templates/user-guide-index.md). Every flow is linked
   (vault: `[[Flow - X]]`; repo: `[Flow - X](<Flow - X.md>)`). Index v1 has no screenshots of its own.
8. **Optional screencast** (`--video`): for the chosen flows
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/skills/user-documentation/scripts/replay-screencast.sh" \
     "<target>/.docgen/journals/<slug>.jsonl" "<target>/screencasts/<slug>.webm" \
     "<target>/.docgen/auth-<role>.json" "<base-url>" "<start-url>"
   ```
   → a `## Screencast` section with the embed right after the lead. For mutating flows warn
   the user: the replay will create one more `Docgen:` record.
9. **Mechanical gate**:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/skills/user-documentation/scripts/validate-docs.py" \
     "<target-dir>" --embed <mode> [--video]
   ```
   Red → targeted fixes (the parent itself, no agents) → re-run until green.
10. **Coherence** (the parent; WITHOUT `sdlc:critic` — its probes are wired for PRD/SAD, and the parent here
    is clean-context by construction): a grep cross-check between the docs — the product name is the same, roles and
    statuses are named consistently, terms match the UI.
11. **Handoff.** A git repo → propose the commit `docs: user documentation for <product>`
    (ONLY the target paths); a vault → no commit (obsidian-git handles it). Close ITS OWN sessions
    (`-s=<name> close`, never `close-all`). `.docgen/` stays — the journals are raw material for
    future `--video` runs. Finish with a **stage-handoff block** per
    [`../_shared/handoff.md`](../_shared/handoff.md), the utility variant: *Run next* = «resume
    your backbone stage» or a repeat call with `--video`.

## Questions for discussion (open, to be checked by a live run)

- Does `video-start --size` exist in playwright-cli 0.1.13 (not confirmed in the help). If not —
  the video size = the viewport size (1280×800), which suits us anyway.
- Does `run-code` accept a named session's context the way we expect — the first live screencast
  replay will confirm or refute it.
- The replay pacing pause of 0.5–1.0s (`PACE` env in replay-screencast.sh) — tune it by eye.

## Definition of Done

- Every confirmed flow has `DOCFLOW_OK` (≤1 retry) or an honest `failed` in the manifest and in the
  final report — no silent skips.
- `validate-docs.py` is green (exit 0) on `<target-dir>`.
- The index exists and links every generated flow; the embed syntax matches the target mode.
- `.docgen/` contains the manifest + the journals of every flow run.
- All `docflow-*`/`replay-*`/`docgen-auth` sessions are closed.
- With `--video` — the .webm exists and is embedded in the corresponding doc.

## Anti-patterns

- **Don't invent UI.** No fact outside the journal/snapshot (the only exception is `doc_type: auth`,
  explicitly marked in [`../../agents/doc-flow.md`](../../agents/doc-flow.md)).
- **Don't run mutating flows in parallel** — it's the main source of non-deterministic screenshots.
- **Don't keep Playwright MCP in the loop** — the canon is the CLI (the `verify-ui` precedent); MCP only for
  live debugging outside the pipeline.
- **Don't publish a screenshot wider than 780px** — it's an un-resized frame that escaped the pipeline.
- **Don't use `> [!note]`** — the docs must render on GitHub; only `> **Note:**`.
- **Don't mix embed syntaxes** — one mode for the whole target, from the manifest.
- **Don't `close-all`/kill-all** — parallel agents share the machine.
- **Don't «fix» the application** — a found bug goes into the report/Troubleshooting, not into the code.
- **Don't duplicate the CLI cheat sheet** — `playwright-cli install --skills` installs its own SKILL.md;
  here only the skill-specific gotchas (determinism.md §5).

## Templates / References

- [`./templates/flow-doc.md`](./templates/flow-doc.md) — the flow-document template (type A + the insertable
  type B block + tail tables).
- [`./templates/user-guide-index.md`](./templates/user-guide-index.md) — the thin index v1.
- [`./references/style-guide.md`](./references/style-guide.md) — the codified reference style.
- [`./references/determinism.md`](./references/determinism.md) — data state, 780px, journal,
  validator invariants, CLI gotchas.
- [`./references/flow-inventory.md`](./references/flow-inventory.md) — the inventory protocol.
- [`../verify-ui/SKILL.md`](../verify-ui/SKILL.md) — the browser channel for verifying ACs; the same
  CLI canon, a different goal (a verdict, not documentation).

## Example invocation

```
/sdlc:user-documentation "~/vault/Beer-LMS-docs" --flows create-session,authentication --video
```

Example of dispatching one flow (step 6):

```
Task(subagent_type="sdlc:doc-flow", prompt="
  Execute directly, do not spawn sub-agents, use tools directly, report results with absolute
  file paths.
  Document ONE flow of 'Beer LMS' (base_url http://localhost:5173, embed_syntax wikilink,
  data_prefix 'Docgen:').
  Flow entry: {"slug":"create-session", ... (the full JSON entry, absolute paths)}.
  Read first: <abs>/references/style-guide.md, <abs>/references/determinism.md,
  template <abs>/templates/flow-doc.md. Auth: state-load <abs>/.docgen/auth-mentor.json.
  Session: df-1. Sibling flows this run: Authentication, Session Lifecycle.
  End with the DOCFLOW_OK/DOCFLOW_FAIL sentinel line.")
```

## Stage handoff

> **user-documentation → (utility, ad-hoc).** At the end a stage-handoff block is printed per
> [`../_shared/handoff.md`](../_shared/handoff.md): *What I did* — how many flows OK/failed, the path
> to the index and docs, the proposed commit (for a git target); *Review* — the index + each flow doc +
> the validator report; *Run next* — resume your backbone stage (e.g. `/sdlc:ship-feature <slug>`)
> or a repeat call with `--video` / the remaining flows. `/clear` is optional (the utility variant).
