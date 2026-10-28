---
name: check-pr
model: inherit
effort: medium
agents: []
description: >-
  Use right after a pull request (GitHub) or merge request (GitLab) is created — by ship-feature,
  by another skill, or by hand with `gh pr create` / `glab mr create` — and whenever a PR/MR has a
  red or pending check. Waits for the PR's pipeline, reads EVERY check, and for each failing one
  reads the log, finds the root cause, fixes it on the PR's feature branch, re-runs the local gate,
  commits, pushes, and reads all checks again — until none is failing. Manual / allow_failure /
  skipped jobs are reported, not fixed. Stops and asks when the cause is unclear: another repo or
  merge/deploy order, flaky or runner failure, a fix that would change the PRD/AC/contract or weaken
  a test, missing secrets or CI settings, a cancelled check. GitHub (gh) and GitLab (glab, incl.
  self-hosted); any other forge (Bitbucket, Gitea/Forgejo, Azure DevOps…) → asks the user how to read
  the checks, never guesses commands. Never weakens a test, never merges, never turns on auto-merge. Triggers on "check PR {url}", "check the checks", "why is the pipeline
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
- Nested code repos (docs in the root repo, code in sub-repos with their own `.git`) → one PR per repo.
  Run the loop for **each**, in the repo's directory (or with `-R <repo>`).

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

The `PostToolUse` hook fires only on `gh pr create` / `glab mr create`; on other forges this skill runs
when called (`/sdlc:check-pr <url>`) or from `ship-feature` step 6.

## Commands (checked against `gh` 2.85 / `glab` 1.89 `--help` and live PRs/MRs)

| Step | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| The PR's pipeline | `gh pr checks <n>` reads the PR's checks directly | `glab mr view <iid> -F json` → `head_pipeline.id`, `.status`, `.sha` |
| Wait until finished | `gh pr checks <n> --watch` (without `--watch`, exit code `8` = still pending) | `glab ci status --live -b <source_branch>`, then re-read `head_pipeline.status` from `glab mr view` — the MR's pipeline is what counts |
| Every check + state | `gh pr checks <n> --json name,state,bucket,link,workflow` | `glab ci get -p <pipeline-id> -d -F json` → `jobs[]`: `id`, `name`, `stage`, `status`, `allow_failure` |
| A failing check's log | `gh run view <run-id> --log-failed`; `<run-id>` is the number after `/runs/` in the check's `link` | `glab ci trace <job-id>` (prints the finished log and exits) or `glab api projects/:id/jobs/<job-id>/trace` |
| Re-run one check | `gh run rerun <run-id> --failed` | `glab ci retry <job-id>` |

`:id` in `glab api` is filled from the repo of the current directory. Use the same `gh`/`glab`
account the PR was created with. A check whose `link` is not a GitHub Actions run (an external app)
has no log through `gh` — give the user the link and ask.

## Classify every check

| Forge state | Counts as | Action |
|---|---|---|
| GitHub `bucket: pass` · GitLab `status: success` | green | — |
| GitHub `bucket: pending` · GitLab `created` / `pending` / `running` / `waiting_for_resource` / `preparing` | not finished | wait, then re-read |
| GitHub `bucket: fail` · GitLab `failed` with `allow_failure: false` | **failing** | fix (Protocol step 4) |
| GitLab `failed` with `allow_failure: true` | not failing | list in the report with the failure reason |
| GitLab `manual` / `skipped` / `scheduled` · GitHub `bucket: skipping` | not failing | list in the report («manual, not run») |
| GitHub `bucket: cancel` · GitLab `canceled` | unclear | ask the user — someone stopped it on purpose or the runner did |
| The pipeline did not start, or has `yaml_errors` / no jobs | unclear | ask — it is a CI-config problem, not the feature |

The loop ends when no check is **failing** and none is **not finished**. Every check counts, not only
the required ones.

## Protocol

1. **Find the PR and its pipeline** with the commands above. Note the head commit SHA — the checks
   must belong to the PR's latest commit.
2. **Wait** until the pipeline is finished. Run the waiting command in the background where the
   harness supports it.
3. **Read every check and classify it** with the table. Nothing failing and nothing pending → go to
   step 6.
4. **Fix each failing check**, one at a time:
   1. **Read the log.** Find the first real error, not the last line (`ERROR: Job failed: exit code 1`
      is only the summary).
   2. **Find the root cause** and say it in one sentence with the evidence (the log line,
      `file:line`). If it is one of the [ask cases](#ask-when-it-is-not-clear) → stop and ask. Do not
      guess.
   3. **Reproduce locally** where you can: the same command or the same test the job ran.
   4. **Fix it on the PR's feature branch**, in the repo that owns the failing code. Production code
      or a broken fixture/setup — never by making a test assert less.
   5. **Re-run the local gate.** Red → keep fixing, do not push.
   6. **Commit and push** to the PR's source branch: `fix(<slug>): <what> — CI <check name>`
      (`fix: …` without a slug), staging only the files you changed. Pushing to the PR's own branch is
      part of this loop; never push to the default branch, never force-push over commits you did not
      write.
5. **Back to step 2** — a push starts a new pipeline; read every check again, not only the one you
   fixed. **Stop and ask** when the same check is still failing after **3** fix attempts, or two
   fixes pull against each other.
6. **Report** (below) and end with the handoff.

## Ask when it is not clear

Stop the loop and ask the user with `AskUserQuestion`, in the shape of
[`../_shared/ask-style.md`](../_shared/ask-style.md): what failed, the log line, what you think the
cause is, and what each option will do. Never pick for them. At least these cases:

| Case | How it looks | What to offer |
|---|---|---|
| **The cause is in another repo, or in merge/deploy order** | The job checks out or calls another repo's default branch, which does not have this feature yet. Real case: the app MR's `e2e` job cloned the api repo's `main`, so the new family specs failed until the api MR was merged. | «You merge the api MR first; I re-run the job (`glab ci retry` / `gh run rerun`) and read the checks again» · «Leave it red; I write the merge order into both PR bodies». Never change the job to point at the feature branch without asking — that is a CI-config change. |
| **Flaky test or infra/runner failure** | Runner lost, out of disk, network/registry timeout, image pull failed; the test passes locally on the same SHA; the failure moves between runs. | «Re-run the job once» · «Treat it as a real failure and investigate». No silent retry loops. |
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
- **Trusting the local gate.** Green is what the forge shows for the PR's latest commit.
- **Making a check green by weakening it.** Loosening an assertion, skipping or deleting a test,
  `xfail`, `allow_failure` / `continue-on-error`, `[skip ci]`, turning a job off — never. If the test
  looks wrong, ask.
- **Guessing when the cause is not in this branch.** A job that runs against another repo's default
  branch, a merge/deploy order dependency, a flaky runner, a missing secret — ask; don't patch around
  it or retry in a loop.
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
