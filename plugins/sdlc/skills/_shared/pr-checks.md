# PR checks — read every check, fix, repeat until green

> **Reference-only.** Not a skill. Any skill that creates a pull request (GitHub) or merge request
> (GitLab) — today `ship-feature` — runs this loop right after the PR/MR exists. "PR" below means
> either. A PR is not shipped while one of its checks is red; opening it and walking away is the
> failure this loop exists for.

## When it runs

- Once per PR this skill created, or the user created from the proposed command and confirmed.
- Nested code repos (docs in the root repo, code in sub-repos with their own `.git`) → one PR per repo
  that has feature commits. Run the loop for **each**, in the repo's directory (or with `-R <repo>`).
- The user declined to create the PR → skip the loop and say so in the handoff: «checks not read —
  no PR yet».

## Commands (checked against `gh` 2.85 / `glab` 1.89 `--help`)

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
| GitHub `bucket: fail` · GitLab `failed` with `allow_failure: false` | **failing** | fix (below) |
| GitLab `failed` with `allow_failure: true` | not failing | list in the report with the failure reason |
| GitLab `manual` / `skipped` / `scheduled` · GitHub `bucket: skipping` | not failing | list in the report («manual, not run») |
| GitHub `bucket: cancel` · GitLab `canceled` | unclear | ask the user — someone stopped it on purpose or the runner did |
| The pipeline did not start, or has `yaml_errors` / no jobs | unclear | ask — it is a CI-config problem, not the feature |

The loop ends when no check is **failing** and none is **not finished**. Every check counts, not only
the required ones.

## Fix a failing check

For each failing check, one at a time:

1. **Read the log** with the command above. Find the first real error, not the last line
   (`ERROR: Job failed: exit code 1` is only the summary).
2. **Find the root cause** and say it in one sentence with the evidence (the log line, `file:line`).
   If the cause is one of the [ask cases](#ask-when-it-is-not-clear) → stop and ask. Do not guess.
3. **Reproduce locally** where you can: run the same command or the same test the job ran.
4. **Fix it on the PR's feature branch**, in the repo that owns the failing code. Production code
   or a broken test fixture/setup — never by making a test assert less.
5. **Re-run the local gate** — the same detected unit / integration / lint / vet commands the skill
   used before the PR (`implement-tasks/references/command-detection.md`). Red → keep fixing, do not push.
6. **Commit and push** to the PR's source branch: `fix(<slug>): <what> — CI <check name>`, staging only
   the files you changed. Pushing new commits to the PR's own branch is part of this loop; never push
   to the default branch, never force-push over commits you did not write.
7. **Back to "Wait"** — a push starts a new pipeline; read every check again, not only the one you fixed.

**Stop and ask** when the same check is still failing after **3** fix attempts, or a fix makes a
different check fail and the two pull against each other.

## Ask when it is not clear

Stop the loop and ask the user with `AskUserQuestion`, in the shape of
[`ask-style.md`](./ask-style.md): what failed, the log line, what you think the cause is, and what each
option will do. Never pick for them. At least these cases:

| Case | How it looks | What to offer |
|---|---|---|
| **The cause is in another repo, or in merge/deploy order** | The job checks out or calls another repo's default branch, which does not have this feature yet. Real case: the app MR's `e2e` job cloned the api repo's `main`, so the new family specs failed until the api MR was merged. | «You merge the api MR first; I re-run the job (`glab ci retry` / `gh run rerun`) and read the checks again» · «Leave it red; I write the merge order into both PR bodies». Never change the job to point at the feature branch without asking — that is a CI-config change. |
| **Flaky test or infra/runner failure** | Runner lost, out of disk, network/registry timeout, image pull failed; the test passes locally on the same SHA; the failure moves between runs. | «Re-run the job once» · «Treat it as a real failure and investigate». No silent retry loops. |
| **The fix would change the PRD, an AC or the contract** | The test is right about the code but the AC/OpenAPI says something else, or the AC turns out to be wrong. | Stop. That is a `/sdlc:clarify-prd` or `/sdlc:api-forge` change with the user in the loop, not a CI fix. |
| **The fix would weaken a test** | The only way to green is to loosen an assertion, skip/delete a test, raise a timeout to hide slowness, or mark the job `allow_failure` / `continue-on-error`. | Do not do it. Show the conflict (the assertion, the AC) and ask what is wrong — the code, the test or the AC. |
| **The fix needs secrets or CI settings** | A missing CI variable or secret, a protected-branch or runner setting, a token scope, a change to `.gitlab-ci.yml` / `.github/workflows/` that is not part of the feature. | Name exactly what is missing and where it is set; the user changes it. Never put a secret in the repo or a commit. |
| **Cancelled check, pipeline that did not start, no access to the log** | See the classification table. | Ask what happened before doing anything. |

After the answer, record the decision in the report and continue the loop from where it stopped.

## Never

- Weaken, skip, delete or `xfail` a test; add `allow_failure` / `continue-on-error`; push with
  `[skip ci]`; turn a job off to make the PR green.
- Merge the PR, or turn on auto-merge (`gh pr merge --auto`, GitLab "merge when pipeline succeeds").
  Green checks do not mean "merge" — merging stays the user's call.
- Claim green from the local gate. Green is what the forge shows for the PR's latest commit.

## Report

Print one table per PR (and put it in the handoff's *What I did*):

| Check | Final state | What happened |
|---|---|---|
| `test` | success | green on the first run |
| `e2e` | success | failed: `<root cause>`; fixed in `<short sha>` |
| `e2e-realtime` | manual | not run (manual job) |
| `lint` | failed (allow_failure) | `<reason>` — not blocking |
| `deploy-preview` | waiting | your decision: `<the question asked>` |

End state is one of: **all green** · **waiting on the user** (name the question) · **stopped** (name
the check and why).
