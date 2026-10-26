# Inputs + preconditions (step 1)

## Hard gate

Resolve the plan path in this order and use the **first** that exists:

1. `docs/features/<slug>/tasks/tasks.json` — the canonical location (`break-tasks` writes it; `map-architecture` greenfield writes `docs/features/_scaffold/tasks/tasks.json`).
2. `docs/features/<slug>/tasks.json` — **legacy fallback** for plans written before v4.6.1 (an older `map-architecture` put the scaffold plan at `docs/features/_scaffold/tasks.json`). Use it only when (1) is absent, print `using legacy plan path docs/features/<slug>/tasks.json`, and offer to `git mv` it to `tasks/tasks.json`. If both exist, (1) wins.

Print the resolved path. The file must parse as JSON. Neither found, or malformed → refuse: «run `/sdlc:break-tasks <slug>` first (it emits tasks.json)». Do not try to reconstruct tasks from the markdown — the resolved `tasks.json` is the contract; every later mention of `tasks/tasks.json` means the resolved path.

## Validate the contract

The loaded `tasks.json` must satisfy the shape from the `break-tasks` skill:

- top-level `{ slug, tasks: [...] }`.
- each task: `id` (unique), `title`, `layer` (`migration|domain|infra|app|ports|ui|tests|wiring|docs`; `scaffold` only in a `_scaffold` set, below), `deps` (array of existing ids), `acs` (array of PRD §5 AC ids), `dod` (one testable sentence), `files_hint` (array of paths/dirs).
- `deps` forms a DAG (no cycles) — verified in step 4. A cycle is a hard error: report the cycle and stop (it is a `break-tasks` bug, not an `implement-tasks` one).

## Scaffold task sets (from `map-architecture` greenfield)

A `tasks.json` with `slug: "_scaffold"` and `layer: scaffold` tasks comes from `map-architecture`'s greenfield foundation (not from `break-tasks`), at `docs/features/_scaffold/tasks/tasks.json`; run it as `/sdlc:implement-tasks _scaffold`. There is no `PRD.md`, `sad.md`, `test-plan.md` or `tasks/tracker.md` for `_scaffold` — don't refuse over them; report task status in the summary. These tasks have **no feature `acs`** — they create the project skeleton (structure, baseline module, test harness, migration tooling, CI, conventions doc). Handle them specially:

- **The skeleton smoke test is the red→green anchor**, not a feature AC: RED = «the project does not build / boot / the tooling doesn't run»; GREEN = «build + boot + the empty test suite + the migration tool all succeed». Write that smoke test as part of the scaffold (task S2 in the foundation contract) and drive the skeleton to make it pass — no per-folder TDD theatre.
- Read `docs/architecture-map.md` (`mode: greenfield-bootstrap`) for the exact stack + conventions to scaffold to.
- After the scaffold is green the repo is real, and the normal per-feature flow (`write-prd → … → implement-tasks`) builds into it with real feature TDD.

## Context the agents read directly

The engine does **not** paste these into prompts — each agent (or the sequential runner) reads them itself, so there's no paraphrase drift:

- `docs/features/<slug>/PRD.md` — §5 acceptance criteria (the source of truth for what each test asserts).
- `docs/features/<slug>/test-plan.md` — the AC→test map, if `plan-tests` ran.
- `docs/features/<slug>/data-model.md` + the **staged** migration files under `docs/features/<slug>/migrations/` — the schema the code targets (a `layer: migration` task promotes them into the live migrations tree; see «Staged migrations → promote» below).
- `docs/features/<slug>/contracts/openapi.yaml` — the API contract handlers must match.
- `docs/features/<slug>/sad.md` + Accepted `adr/` — the architecture and the locked decisions.
- `docs/architecture-map.md` (from `map-architecture`, if present) — the existing system's conventions the new code must match (module wiring, error handling, IDs, tests, migrations; **for a `ui` surface, §Frontend / UI foundation — the design system / components / tokens / styling to reuse**) + the closest precedent to copy (including the **closest UI precedent** for a new screen). Saves the agents re-discovering the patterns.

## Staged migrations → promote before running

`generate-data-model` stages each migration as `docs/features/<slug>/migrations/<NN>_<verb>_<entity>.up.sql` + `.down.sql` (feature-local ordinal or timestamp prefix) — or, when `.claude/rules/migrations.md` sets another tool / format, as files in that format (e.g. one file per migration carrying both directions) — **not** in the live migrations tree, so a design-stage schema can't be applied to a real DB before the feature is built. The `layer: migration` task(s) own **promotion** — this is the wiring `generate-data-model` set up:

1. **Promote in ordinal order.** For each staged `<NN>_*` migration — a pair, or a single file in the project's format (ascending) — copy it into the repo's live migrations directory (in a nested-repo workspace: the owning code repo's, see below) under the repo's detected convention or the naming `.claude/rules/migrations.md` sets — sequential → the **next free number** (`000023_*`); timestamped → a fresh timestamp re-stamped **at promote-time** — preserving the intra-feature order. The number/timestamp is assigned **now, at promote-time**, so two features building around the same time never collide and the live sequence stays correct. The body (SQL, or the migration source in the project's format) is copied **verbatim** — never rewritten during promotion; only the filename prefix changes (plus, if the format derives an identifier from the filename, the matching identifier — nothing else). After promotion the live file is canonical; the staged copy is the frozen design record (git keeps it; don't hand-edit it).
2. **Then apply + verify.** Run the migration with the repo's tool against the (ephemeral, testcontainers) DB; the task's DoD «migration applies and reverts cleanly» is checked on the promoted file. The feature's integration tests run against the promoted schema.
3. **Commit** the promoted live file(s) with the migration task (the staged files under `docs/features/<slug>/migrations/` were already committed by `generate-data-model` — in a nested-repo workspace they stay in the docs repo while the promoted copy is committed in the code repo).

A `layer: migration` task with **no** staged file under the feature's `migrations/` is a `break-tasks`/`generate-data-model` mismatch — surface it, do not invent SQL.

## `ui`-layer tasks

A `layer: ui` task (present only when `sad.md` frontmatter `target_surfaces` declares a UI surface — `web-frontend` / `mobile-app` / `desktop-app`) runs through the **same TDD cycle** as any other task; it just follows the **repo's frontend test convention** — component / e2e-through-UI runners detected from `package.json` scripts (Playwright / Storybook / a visual-diff tool / etc.) — **not** a backend assumption. No engine change: command-detection already picks up frontend scripts in its cascade.

**Reuse the UI foundation (don't reinvent).** A `ui` task **composes the existing design system** from `architecture-map.md` §Frontend — reuse the existing components / shared primitives, pull design tokens (colors / spacing / typography) from the repo's token source, and build in the repo's **one** styling approach. Find the **closest existing screen/component** (the §Frontend UI precedent) and extend/compose it; write a **new** component only when no existing primitive fits, in the repo's styling approach — never a second one. This is the frontend echo of "match the repo + copy the closest precedent" → [`../../_shared/surfaces.md`](../../_shared/surfaces.md).

## Repo state

- Note the current branch. If `branch_strategy: feature` and the repo is on its default branch, create/switch to a feature branch before any commit (see [`settings.md`](./settings.md)).
- Do not touch unrelated dirty changes — work only the files each task's `files_hint` names.

### Nested code repos (owning repo per task)

Some workspaces keep `docs/` in the root git repo while the code lives in independent git repos in sub-directories (each with its own `.git`, gitignored by the root). The engine resolves an **owning repo** for every task in step 4 — a single-repo project resolves everything to the cwd repo and nothing below changes.

1. **Resolve.** For each `files_hint` entry, walk up from the path (or its nearest existing ancestor — the file may not exist yet) to the nearest directory containing a `.git` entry (directory or file, so a worktree or submodule counts), stopping at the workspace root; `git -C <dir> rev-parse --show-toplevel` gives the same answer. Hints under `docs/features/<slug>/` don't count — those are the engine's own docs-repo files. The task's owning repo(s) = the distinct results; no hint left → the docs repo (the one holding `docs/features/<slug>/`). A `layer: migration` task always owns the repo holding the live migrations tree (`docs/architecture-map.md` §Migrations / persistence), even if its hints only name the staged files.
2. **Branch per repo.** `branch_strategy` applies in each owning repo: `git -C <repo>` checks its current branch and, under `feature`, creates/switches to the feature branch there if it is on its default branch. Dirty state is checked per repo.
3. **Commands per repo.** Unit / integration / lint / vet are resolved per owning repo ([`command-detection.md`](./command-detection.md); `repos.<path>.cmd_*` in [`settings.md`](./settings.md) overrides) and run with that repo's root (or its worktree) as the working directory. The agents get that directory and those commands in their brief.
4. **Commit per repo.** `git -C <repo> add` / `commit` with the `SDLC-Task` / `SDLC-AC` trailers; a task touching two repos → one commit per repo, same subject and trailers ([`tdd-loop.md`](./tdd-loop.md) §COMMIT).
5. **Worktrees in the code repo.** `isolation: worktree` creates them in the owning repo — `git -C <repo> worktree add <repo>/.worktrees/<agent>` — not in the docs repo. If that repo doesn't already ignore `.worktrees/`, add it to that repo's exclude file — the path `git -C <repo> rev-parse --git-path info/exclude` prints, relative to `<repo>` (local, never committed) — instead of editing its `.gitignore`.
6. **Docs stay in the docs repo.** `tasks/tracker.md` and `tasks.json` edits (status, an escalation split) are written in the docs repo and never staged into a code-repo commit; with `auto_commit` ≠ `off` the engine commits them there (same `SDLC-Task` trailer) after the task's (or phase's) code commits.
