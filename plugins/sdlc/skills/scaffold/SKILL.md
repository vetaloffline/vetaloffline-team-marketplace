---
name: scaffold
model: inherit
effort: medium
agents: []
description: >-
  Use to materialize a new full-stack project from the base-tpl template with a
  subtractive battery interview. Triggers on "scaffold a new project",
  "/sdlc:scaffold", "заскафолдь проєкт", "новий проєкт з темплейта",
  "розгорни проєкт з base-tpl", "scaffold from template" — typically right after
  /sdlc:interview produced docs/idea-brief.md in an empty folder. Reads the brief
  (name/context), asks stack + battery questions (web frontend, deploy, CI,
  Prometheus+Grafana observability, freshness bump), then runs base-tpl's
  scaffold.sh: full template copy with unselected batteries physically removed.
  "Yes to everything" reproduces the template byte-for-byte. Not the same as
  /sdd:scaffold (which materializes a skeleton planned by /sdd:survey inside an
  SDD flow) — this one copies a ready-made template into an empty folder.
triggers:
  - /sdlc:scaffold
  - scaffold a new project
  - scaffold from template
  - заскафолдь проєкт
  - новий проєкт з темплейта
  - розгорни проєкт з base-tpl
---

# Skill: scaffold (new project from base-tpl)

Materializes a new project from the **base-tpl** template subtractively: the full
filled path is copied, and the batteries not chosen are **physically removed** (folders, compose services,
CI jobs, README lines). «Yes to everything» = the template byte for byte. The cutting mechanics live
in `scaffold.sh` at the root of base-tpl and are tested by the base-tpl CI matrix — this skill only
collects the answers and calls the engine.

## Template source

1. If the env `SDLC_BASE_TPL` is set — use that path (a local clone of base-tpl).
2. Otherwise — a fresh shallow clone of the public repo:
   ```bash
   git clone --depth 1 https://github.com/genkovich/base-tpl /tmp/base-tpl-$$
   ```
   The clone is one-off; it can be deleted after the scaffold.

## Steps

### 1. Context: idea-brief

If the current folder has `docs/idea-brief.md` (the output of `/sdlc:interview` in greenfield mode) —
read it: the product name (kebab-case slug) and the gist come from there, don't ask for the name
(only confirm the slug in one line in the first question of step 2). If there is no brief —
ask for the project name (kebab-case slug) before the tech interview.

The scaffold target is **the current folder** if it is empty or contains only `docs/` with the brief;
otherwise — a new folder `./<slug>`.

### 2. Tech interview — call A (stack)

One AskUserQuestion with four questions; the recommended option first:

1. **Backend language:** Go (Recommended) / PHP / Python / TypeScript
2. **Architecture:** Modular monolith (Recommended) / Microservices
3. **Frontend:** React + FSD (Recommended) / No frontend / Flat React
4. **Auth:** Google OAuth (Recommended) / No auth / Email + password

**Honesty about what base-tpl contains.** The filled paths right now:

| Choice | State |
|---|---|
| Go + monolith | ✅ `templates/go-react` |
| React + FSD | ✅ (the same path) |
| **No frontend** | ✅ real subtraction (`--no-web`) |
| Google OAuth | ✅ built into the template |
| PHP / Python / TypeScript | 🔒 not filled yet |
| Microservices | 🔒 not filled yet |
| Flat React | 🔒 not filled yet |
| No auth / Email + password | 🔒 not filled yet (auth is built into the template) |

Choosing a 🔒 option → stop and say it plainly: «this path in base-tpl is not filled yet —
fill `templates/<stack>` in base-tpl or choose a filled option». Don't generate
stubs in place of the template.

### 3. Tech interview — call B (batteries)

A second AskUserQuestion: one multiSelect question about batteries + one about freshness:

1. **Batteries** (multiSelect, all on by default — Enter keeps everything):
   - **Deploy** — `deploy/` (Caddy auto-TLS, prod compose) + a deploy workflow (GHCR → VPS → health gate)
   - **CI** — `.github/workflows/ci.yml` (the same checks as `make check`)
   - **Monitoring** — Prometheus + Grafana locally and in prod (the `/metrics` endpoint in the api always stays)
2. **Freshness** — update the infrastructure pins to fresh versions? Yes (Recommended) / No.

A battery not chosen physically disappears: the folder, compose services, CI jobs, README lines.

### 4. Calling the engine

```bash
BASE_TPL=${SDLC_BASE_TPL:-/tmp/base-tpl-$$}   # see «Template source»
OWNER=$(gh api user -q .login 2>/dev/null || echo example)
"$BASE_TPL/scaffold.sh" "$TARGET" "$SLUG" "$OWNER" \
  [--no-web] [--no-deploy] [--no-ci] [--no-observability] \
  [--brief docs/idea-brief.md] \
  [--no-git]   # only if freshness was chosen — git init happens after the bumps
```

`scaffold.sh` itself: copies the template's tracked files, cuts the batteries not chosen by
the `battery:<name>` markers, renames the brand (`myapp` → slug, `MyApp` → Display,
`example/myapp` → owner/slug), copies `api/.env.example` → `api/.env`,
puts the brief into `docs/idea-brief.md` and does `git init` + the t0 commit.

### 5. Freshness (if chosen)

After the subtraction, before git init (hence `--no-git` in step 4):

1. Collect the stack surface pins: the Go toolchain and base images in `api/Dockerfile`,
   `GO_VERSION`/`NODE_VERSION` in the workflows, docker tags (`postgres`, `prom/prometheus`,
   `grafana/grafana`, `caddy`, `nginx`), GitHub Actions versions.
2. Get fresh versions via **context7** (`resolve-library-id` → `query-docs`);
   for docker tags and Actions that context7 doesn't know — WebSearch or the registry
   (hub.docker.com, github releases). If no tool is available —
   honestly skip freshness with a report; don't block the scaffold.
3. Apply the bumps → gate: `make check` (with `--no-web` — `make api-check`).
   Red → roll back the bumps (the scaffold is handed over green, with a report of what was rolled back and why).
4. Finish: `git init -b main && git add -A && git commit -m "t0: scaffold <slug> from base-tpl (go-react)"`.

What gets bumped is the **infrastructure pins**, not `go.mod`/`package-lock.json` (code dependencies
are updated in their own cycle inside the project).

### 6. Final message

- **`/init`** — the template deliberately has no root CLAUDE.md; generate it now
  with the project's context (`api/CLAUDE.md`, `web/CLAUDE.md` and the path rules came with the template).
- `make check` — the end-to-end check.
- `make up` → the full local stack (ports — in the project README).
- Google login needs real `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` in `api/.env` (one env pair: the committed `api/.env.example` → the gitignored `api/.env`; both the local dev loop and compose read it).
- Next in the SDLC: features via `/sdlc:interview <slug>` (feature mode) in the new repo.

## Common mistakes

- The skill starts «helping» by hand after scaffold.sh (editing files, tweaking) —
  no: the scaffold ends with the t0 commit; everything else is separate steps inside the project.
- A 🔒 option was chosen and the skill generated a stub itself — forbidden; refuse honestly.
- Freshness bumped go.mod/package-lock — roll back: those are code pins, not infra.
- Forgot `--no-git` with freshness → the bumps get smeared across the history after t0.
