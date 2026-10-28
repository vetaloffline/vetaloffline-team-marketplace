---
name: check-pr
model: inherit
effort: medium
agents: [pr-fixer]
description: >-
  Use right after a pull request (GitHub) or merge request (GitLab) is created — by ship-feature,
  by another skill, or by hand with `gh pr create` / `glab mr create` — and whenever a PR/MR has a
  red or pending check. Dispatches one sdlc:pr-fixer agent per PR; the agent waits for the PR's
  pipeline, reads EVERY check, and for each failing one reads the log, fixes the root cause on the
  PR's branch, re-runs the local gate, commits, pushes, and reads all checks again — until none is
  failing. Manual / allow_failure / skipped jobs are reported, not fixed. When the cause is unclear
  (another repo or merge/deploy order, flaky or runner failure, a fix that would change the
  PRD/AC/contract or weaken a test, missing secrets or CI settings, a cancelled check) the agent
  stops, the session asks the user and resumes the agent with the answer. GitHub (gh) and GitLab
  (glab, incl. self-hosted); any other forge (Bitbucket, Gitea/Forgejo, Azure DevOps…) → asks the
  user how to read the checks, never guesses commands. Never weakens a test, never merges, never
  turns on auto-merge. Triggers on "check PR {url}", "check the checks", "why is the pipeline
  red", "fix CI for {PR}", "/sdlc:check-pr {url-or-number}", "перевір PR", "перевір чеки",
  "перевір мердж-реквест", "чому впав пайплайн". Output: a checks report per PR + fix commits on
  the PR's branch.
triggers:
  - /sdlc:check-pr
  - "check PR"
  - "check the checks"
  - "fix CI for"
  - "why is the pipeline red"
  - "перевір PR"
  - "перевір чеки"
  - "перевір мердж-реквест"
  - "чому впав пайплайн"
stage: "util"
---

# Skill: check-pr (SDLC utility — read every PR check, fix until green)

A PR is not shipped while one of its checks is red. Opening it and walking away is the failure this
skill exists for. Real case: `ship-feature` opened two GitLab MRs (api, app); the app MR's `e2e` job
then failed 22 specs because it cloned api `main`, which did not have the feature yet — and nothing
looked at the checks.

"PR" below means a GitHub pull request or a GitLab merge request. Works for any PR — inside the SDLC
pipeline or not.

## When it runs

- **Right after a PR/MR is created**, once per PR:
  - `ship-feature` step 6 runs this skill for every PR it created;
  - the plugin's `PostToolUse` hook (`hooks/pr-created.py`) adds a note after any successful
    `gh pr create` / `glab mr create` in the session, naming the PR URL — run this skill on it;
  - the user asks («перевір PR», `/sdlc:check-pr <url>`).
- **On an existing PR** with red or pending checks.
- Nested code repos (docs in the root repo, code in sub-repos with their own `.git`) → one PR per repo,
  one `sdlc:pr-fixer` agent per PR, each in its repo's directory.

## Who does what

| Who | Does |
|---|---|
| **This session** (the skill) | finds the PR(s), detects the forge (unknown forge → asks here), resolves the local gate, dispatches one `sdlc:pr-fixer` agent per PR, waits for them, asks the user whatever an agent hands back, resumes that agent with the answer, prints the final report |
| **`sdlc:pr-fixer`** ([`../../agents/pr-fixer.md`](../../agents/pr-fixer.md)) | runs [The loop](#the-loop-run-by-sdlcpr-fixer) for its one PR: wait → read every check → log → fix → gate → commit → push → again, until none fails. It cannot ask the user (`AskUserQuestion` is not available to agents): on an unclear case it stops and returns `PRFIX_NEEDS_USER` |

## Inputs

- The PR: URL, number, or nothing (= the PR of the current branch). Several PRs → each one in turn.
- Optional `<slug>` — when the PR ships an SDLC feature: used in the fix commit subject and to read
  `docs/features/<slug>/PRD.md` (ACs) and `contracts/` when deciding whether a fix changes them.
- The local gate: the unit / integration / lint / vet commands, detected per repo as in
  [`../implement-tasks/references/command-detection.md`](../implement-tasks/references/command-detection.md)
  (settings override `.claude/sdlc.local.md` → Makefile → package scripts → language manifests).
- **Refuse** if the PR cannot be found or `gh` / `glab` is not authenticated for its host — say which
  one and how to log in; do not guess the state from the local gate.

## Detect the forge

Take the host from the PR URL, or from `git remote get-url origin` of the PR's repo. Then:

| Check | Forge | Next |
|---|---|---|
| host is `github.com`, or `gh auth status --hostname <host>` exits `0` (GitHub Enterprise) | GitHub | the `gh` column below |
| host is `gitlab.com`, or `glab auth status --hostname <host>` exits `0` (self-hosted GitLab) | GitLab | the `glab` column below |
| anything else — `bitbucket.org`, `dev.azure.com`, Gitea / Forgejo (`codeberg.org`…), an unknown host, or a GitHub/GitLab host the CLI is not logged in to | other / unknown | **stop and ask** (below) |

A host name alone is not proof: a `gitlab` in the name with no `glab` login is still "unknown".

**Other or unknown forge → ask, never guess.** This skill has commands checked only for `gh` and
`glab`; writing another forge's CLI/API calls from memory is how a wrong command gets run. Ask with
`AskUserQuestion` (shape per [`../_shared/ask-style.md`](../_shared/ask-style.md)), naming the host and
the PR link. Options:
- **«You read the checks, I fix»** — you open the PR, paste the list of failing checks and their logs;
  from there the loop runs as usual (fix → gate → push), and you re-read the checks after each push.
- **«Use a tool you name»** — you name the CLI or API this forge uses (e.g. the forge's own CLI, or its
  REST endpoint for pipeline status); I read its `--help` / docs first, write the exact commands into
  the report, and only then run the loop with them.
- **«Skip the checks for this PR»** — I record «checks not read — <forge> not supported» in the report
  as the end state; nothing is claimed green.

With the first option this session runs the fix steps of [The loop](#the-loop-run-by-sdlcpr-fixer)
itself on the logs you paste (no agent — it could not read the checks either). With the second, the
agent's prompt carries the commands you named and verified.

The `PostToolUse` hook fires only on `gh pr create` / `glab mr create`; on other forges this skill runs
when called (`/sdlc:check-pr <url>`) or from `ship-feature` step 6.

## Commands (checked against `gh` 2.85 / `glab` 1.89 `--help` and live PRs/MRs)

`<repo>` is `OWNER/REPO` for `gh`, `GROUP/…/REPO` for `glab` (from the PR URL).

| Step | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| The PR's pipeline | `gh pr checks <n> -R <repo>` reads the PR's checks directly | `glab mr view <iid> -R <repo> -F json` → `head_pipeline.id`, `.status`, `.sha` |
| Wait until finished | `gh pr checks <n> -R <repo> --watch` (without `--watch`, exit code `8` = still pending) | `glab ci status --live -b <source_branch> -R <repo>`, then re-read `head_pipeline.status` from `glab mr view` — the MR's pipeline is what counts |
| Every check + state | `gh pr checks <n> -R <repo> --json name,state,bucket,link,workflow` | `glab ci get -p <pipeline-id> -R <repo> -d -F json` → `jobs[]`: `id`, `name`, `stage`, `status`, `allow_failure` |
| A failing check's log | `gh run view <run-id> -R <repo> --log-failed`; `<run-id>` is the number after `/runs/` in the check's `link` | `glab ci trace <job-id> -R <repo>` (prints the finished log and exits) |
| Re-run one check | `gh run rerun <run-id> -R <repo> --failed` | `glab ci retry <job-id> -R <repo>` |
| Local git | `git -C <repo dir> <status / switch / add / commit / push …>` | same |

Use the account `gh` / `glab` is logged in with. A check whose `link` is not a GitHub Actions run (an
external app) has no log through `gh` — give the user the link and ask.

### How to write the commands (so they can run without prompts)

Claude Code asks before a Bash command unless every part of it matches an allow rule. A background
agent's prompt lands in the user's session and stalls the loop; in a headless run it is simply
denied. So:

- **One command per Bash call**, written as in the table. A pipe only into `jq` (to pick fields from
  `-F json` / `--json`).
- **Point at the repo with flags, never with `cd`:** `git -C <repo dir> …`, `gh … -R <repo>`,
  `glab … -R <repo>`. `cd <dir> && git …` always prompts — git in another directory can run that
  directory's hooks.
- **No shell loops or polling** (`for` / `while` / `until`, `sleep`): Claude Code cannot check a loop
  before it runs, so it always prompts. Wait with the *Wait until finished* command.
- **No `$(…)` and no env prefixes** like `GH_TOKEN=$(gh auth token …) gh …` — they match no allow rule.
  If the logged-in account cannot read the PR or push, stop and ask.
- **Gate commands** run exactly as resolved (`.claude/sdlc.local.md` `cmd_*` / `repos.<path>.cmd_*`).
  When a command needs the repo as its working directory, `cd <repo dir> && <command>` is fine — the
  prompt rule above is only about `cd` followed by `git`.

### Permissions — what to allow for an unattended run

Plugin agents cannot carry their own permissions (Claude Code ignores `permissionMode` for them), so
the allow rules live in the user's or project's settings (`permissions.allow`). With these, the loop
runs without a single prompt:

```json
"Bash(gh pr checks *)", "Bash(gh pr view *)", "Bash(gh run view *)", "Bash(gh run rerun *)",
"Bash(glab mr view *)", "Bash(glab ci get *)", "Bash(glab ci status *)", "Bash(glab ci trace *)",
"Bash(glab ci retry *)", "Bash(jq *)", "Bash(git -C *)"
```

plus the project's gate commands (e.g. `"Bash(npx jest *)"`, `"Bash(npm run lint)"`). `Bash(git -C *)`
covers every git command in a named directory, `push` included — this skill never pushes to the
default branch; add a deny rule such as `"Bash(git -C * push * main)"` if you want that enforced.
Checked live: with exactly these rules a headless run executed `git -C <dir> status`,
`glab mr view … | jq …` and `glab ci get … | jq …` without prompts.

## Classify every check

| Forge state | Counts as | Action |
|---|---|---|
| GitHub `bucket: pass` · GitLab `status: success` | green | — |
| GitHub `bucket: pending` · GitLab `created` / `pending` / `running` / `waiting_for_resource` / `preparing` | not finished | wait, then re-read |
| GitHub `bucket: fail` · GitLab `failed` with `allow_failure: false` | **failing** | fix (The loop, step 3) |
| GitLab `failed` with `allow_failure: true` | not failing | list in the report with the failure reason |
| GitLab `manual` / `skipped` / `scheduled` · GitHub `bucket: skipping` | not failing | list in the report («manual, not run») |
| GitHub `bucket: cancel` · GitLab `canceled` | unclear | ask the user — someone stopped it on purpose or the runner did |
| The pipeline did not start, or has `yaml_errors` / no jobs | unclear | ask — it is a CI-config problem, not the feature |

The loop ends when no check is **failing** and none is **not finished**. Every check counts, not only
the required ones.

## Protocol (this session)

1. **Find the PR(s).** URL, number, or the PR of the current branch; with nested repos, every PR of
   this feature. For each: the forge ([Detect the forge](#detect-the-forge) — unknown → ask now), the
   repo directory, the source branch, the `<repo>` path for `-R`. A PR that is already **merged or
   closed** gets no agent: read its last pipeline once, report it, and stop — there is no branch left
   to fix.
2. **Resolve the local gate** per repo ([`command-detection.md`](../implement-tasks/references/command-detection.md)).
3. **Dispatch `sdlc:pr-fixer`**, one per PR — in parallel when the PRs are in different repos, one at
   a time when two PRs share a repo. Fallback when the agent is not available: the general-purpose
   agent with the text of [`../../agents/pr-fixer.md`](../../agents/pr-fixer.md) + the same prompt.
   The prompt carries: the PR URL, the forge, the `<repo>` path, the absolute repo directory, the
   source branch, the gate commands, the `<slug>` (if any), and the absolute path of this
   `SKILL.md`. If a PR depends on another one's merge (the "Merge order" line of the PR body), say so
   in both prompts.
4. **Wait for every agent.** Its result arrives as a notification that wakes this session, so ending
   the turn while an agent works is fine. What is not: reporting the PR as done, handing off, or
   telling the user to "check later" before every agent has returned.
   **`PRFIX_STOPPED reason=permission-denied`** → tell the user the exact allow rule(s) missing (from
   [Permissions](#permissions--what-to-allow-for-an-unattended-run)), then run [The loop](#the-loop-run-by-sdlcpr-fixer)
   in this session yourself, from where the agent stopped — here the user can answer the prompts.
5. **`PRFIX_NEEDS_USER` → ask, then resume.** Ask with `AskUserQuestion` (see
   [Ask when it is not clear](#ask-when-it-is-not-clear)), built from the agent's `case`, `check`,
   `log`, `cause` and `options`. Send the answer to **the same agent** with `SendMessage`
   (`to` = its id): `DECISION: <what the user chose>`. Back to step 4. If the agent cannot be
   resumed, dispatch a new one with the decision and the previous agent's table.
6. **All agents returned** `PRFIX_GREEN` or `PRFIX_STOPPED` → merge their tables into the
   [Report](#report) and end with the handoff.

## The loop (run by `sdlc:pr-fixer`)

1. **Find the PR's pipeline** with the commands above. Note the head commit SHA — the checks must
   belong to the PR's latest commit.
2. **Wait** until the pipeline is finished: the wait command in the background, or in the foreground
   with the longest timeout and run again if it times out. Never return while a check is pending.
   No job started after 30 minutes (`created` / `pending`, no runner) → `PRFIX_NEEDS_USER case=infra`.
3. **Read every check and classify it** with the table. Nothing failing and nothing pending → step 5.
   For each failing check, one at a time:
   1. **Read the log.** Find the first real error, not the last line (`ERROR: Job failed: exit code 1`
      is only the summary).
   2. **Find the root cause** and say it in one sentence with the evidence (the log line,
      `file:line`). Looks flaky or infra-caused and this check was not re-run yet → re-run it once
      (the *Re-run one check* command) and go back to step 2 — no question. Any other
      [ask case](#ask-when-it-is-not-clear), or the same flaky error after that re-run → stop and
      return `PRFIX_NEEDS_USER`. Do not guess.
   3. **Reproduce locally** where you can: the same command or the same test the job ran.
   4. **Fix it on the PR's feature branch**, in the repo that owns the failing code. Production code
      or a broken fixture/setup — never by making a test assert less.
   5. **Re-run the local gate.** Red → keep fixing, do not push.
   6. **Commit and push** to the PR's source branch: `fix(<slug>): <what> — CI <check name>`
      (`fix: …` without a slug), staging only the files you changed. Pushing to the PR's own branch is
      part of this loop; never push to the default branch, never force-push over commits you did not
      write.
4. **Back to step 2** — a push starts a new pipeline; read every check again, not only the one you
   fixed. **Stop and return `PRFIX_NEEDS_USER case=cap`** when the same check is still failing after
   **3** fix attempts, or two fixes pull against each other.
5. **Return** `PRFIX_GREEN` with the [Report](#report) table (sentinel format in
   [`../../agents/pr-fixer.md`](../../agents/pr-fixer.md)).

## Ask when it is not clear

The agent stops the loop and returns `PRFIX_NEEDS_USER`; this session asks the user with
`AskUserQuestion`, in the shape of [`../_shared/ask-style.md`](../_shared/ask-style.md): what failed,
the log line, what the cause looks like, and what each option will do. Never pick for them. At least
these cases:

| Case | How it looks | What to offer |
|---|---|---|
| **The cause is in another repo, or in merge/deploy order** | The job checks out or calls another repo's default branch, which does not have this feature yet. Real case: the app MR's `e2e` job cloned the api repo's `main`, so the new family specs failed until the api MR was merged. | «You merge the api MR first; I re-run the job (`glab ci retry` / `gh run rerun`) and read the checks again» · «Leave it red; I write the merge order into both PR bodies». Never change the job to point at the feature branch without asking — that is a CI-config change. |
| **Flaky test or infra/runner failure — after one automatic re-run** | Runner lost, out of disk, network/registry timeout, image pull failed; the test passes locally on the same SHA; the failure moves between runs. **The first time the agent does not ask:** it re-runs that job once itself (`gh run rerun <run-id> --failed` / `glab ci retry <job-id>`) and reads the checks again. Only when the same error comes back after that re-run does it become a question. | «Treat it as a real failure and investigate» · «Re-run once more» · «Leave it red; you look at the runner». No more than one automatic re-run per check. |
| **The fix would change the PRD, an AC or the contract** | The test is right about the code but the AC/OpenAPI says something else, or the AC turns out to be wrong. | Stop. That is a `/sdlc:clarify-prd` or `/sdlc:api-forge` change with the user in the loop, not a CI fix. |
| **The fix would weaken a test** | The only way to green is to loosen an assertion, skip/delete a test, raise a timeout to hide slowness, or mark the job `allow_failure` / `continue-on-error`. | Do not do it. Show the conflict (the assertion, the AC) and ask what is wrong — the code, the test or the AC. |
| **The fix needs secrets or CI settings** | A missing CI variable or secret, a protected-branch or runner setting, a token scope, a change to `.gitlab-ci.yml` / `.github/workflows/` that is not part of the feature. | Name exactly what is missing and where it is set; the user changes it. Never put a secret in the repo or a commit. |
| **Cancelled check, pipeline that did not start, no access to the log** | See the classification table. | Ask what happened before doing anything. |

After the answer, record the decision in the report and continue the loop from where it stopped.

## Report

Print one table per PR (it also goes into `ship-feature`'s handoff *What I did*):

| Check | Final state | What happened |
|---|---|---|
| `test` | success | green on the first run |
| `e2e` | success | failed: `<root cause>`; fixed in `<short sha>` |
| `e2e-realtime` | manual | not run (manual job) |
| `lint` | failed (allow_failure) | `<reason>` — not blocking |
| `deploy-preview` | waiting | your decision: `<the question asked>` |

End state is one of: **all green** · **waiting on the user** (name the question) · **stopped** (name
the check and why).

## Definition of Done

- The forge was detected from the host (GitHub / GitLab by `gh` / `glab` login); on any other forge the
  user was asked how to read the checks and the answer is in the report.
- One `sdlc:pr-fixer` agent ran per PR (or the general-purpose fallback); the session reported
  nothing as done before every agent returned. A permission-denied stop named the missing allow rules
  and the session finished the loop itself.
- Every command was a single call with `-R` / `git -C` — no `cd … && git`, no shell loops, no `$(…)`.
- Every `PRFIX_NEEDS_USER` was asked with `AskUserQuestion` and the answer sent back to the same agent
  (or a new one) — or the user's decision ended the loop, and that is in the report.
- Every check of each PR was read on the PR's latest commit — not only the required ones.
- Each failing check was fixed on the feature branch (local gate green, commit pushed) and all checks
  were re-read until none failed — or the loop stopped on an ask case and the question/decision is in
  the report.
- Manual / `allow_failure` / skipped jobs are listed in the report, not counted as failures.
- No test was weakened or skipped, no job was turned off, nothing was merged, auto-merge was not
  turned on.
- The report states the end state per PR.

## Anti-patterns

- **Opening the PR and walking away.** A PR with a red check is not shipped.
- **Reporting "the pipeline is running, check later"** or handing off while an agent works. Ending
  the turn to wait for its notification is fine; declaring a result is not.
- **Commands that always prompt:** `cd <dir> && git …`, `for` / `while` / `until` polling, `sleep`,
  `GH_TOKEN=$(…)` prefixes. Use `git -C`, `-R` and the wait commands from the table.
- **Answering the agent's question yourself.** A `PRFIX_NEEDS_USER` goes to the user; the session
  does not pick an option for them.
- **Trusting the local gate.** Green is what the forge shows for the PR's latest commit.
- **Making a check green by weakening it.** Loosening an assertion, skipping or deleting a test,
  `xfail`, `allow_failure` / `continue-on-error`, `[skip ci]`, turning a job off — never. If the test
  looks wrong, ask.
- **Guessing when the cause is not in this branch.** A job that runs against another repo's default
  branch, a merge/deploy order dependency, a missing secret — ask; don't patch around it.
- **Asking about a one-off flake, or retrying in a loop.** A failure that looks flaky or infra-caused
  gets exactly one automatic re-run; the same error again → ask. Never a second silent re-run.
- **Fixing only the check you looked at.** Every push starts a new pipeline; read all checks again.
- **Guessing another forge's commands.** Bitbucket, Gitea, Azure DevOps… are not `gh` / `glab`; ask
  how to read their checks instead of writing CLI/API calls from memory.
- **Merging when green.** Green checks do not mean "merge"; no `gh pr merge --auto`, no GitLab "merge
  when pipeline succeeds". Merging stays the user's call.

## Stage handoff

End with the **stage-handoff block** per [`../_shared/handoff.md`](../_shared/handoff.md) — utility
variant. *What I did* = the report table(s) + end state + the fix commits pushed. *Review* = the fix
commits (`<repo> <short sha> <subject>`). *Run next* = **Done** — «all green; merging is your call»,
or the open question / the stopped check. Called from `ship-feature` → return to its step 7 instead.
