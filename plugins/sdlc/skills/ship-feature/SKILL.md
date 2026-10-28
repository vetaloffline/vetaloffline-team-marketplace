---
name: ship-feature
model: inherit
effort: medium
agents: []
description: >-
  Use to close the loop after review — verify the feature actually works, write the changelog,
  and open the pull request. Triggers on "ship {slug}", "open a PR for {slug}", "changelog for
  {slug}", "prepare {slug} for merge", "/sdlc:ship-feature {slug}", "відправ фічу {slug}",
  "створи PR для {slug}", "changelog для {slug}". Gate: refuses if
  docs/features/{slug}/_review/review-<date>.md does not show PASS (produced by review-feature).
  Runs the feature end-to-end to confirm it actually works (not just green tests), drafts a
  changelog + PR body that link PRD/ACs/ADRs and the SDLC-Task commit history, detects the git
  forge (gh for GitHub / glab for GitLab) and proposes the right PR-create command. Once the PR
  exists it reads every check of its pipeline, fixes each failing one on the feature branch and
  repeats until all are green, asking the user whenever the cause is unclear (another repo, merge
  order, flaky/infra, PRD/contract, secrets). Then moves the feature to Shipped in docs/roadmap.md.
  Never merges and never turns on auto-merge — merging is the user's call.
  Output: docs/features/{slug}/CHANGELOG.md + PR body + the PR URL with its checks report.
triggers:
  - /sdlc:ship-feature
  - "ship "
  - "open a PR for"
  - "changelog for"
  - "prepare for merge"
  - "відправ фічу"
  - "створи PR для"
  - "changelog для"
stage: "18"
---

# Skill: ship-feature (SDLC stage 18 — terminal)

The closing step. `review-feature` confirmed the change is correct on paper; `ship-feature` confirms it **works in reality** and packages it for merge. The loop ends here: a reviewed, verified change with a changelog and an open PR whose checks are all green — not a merge to main (that stays a human decision).

Forge-agnostic and stack-agnostic: verification commands are detected the same way `implement-tasks` detects them; the PR step targets whatever forge the remote points at (GitHub via `gh`, GitLab via `glab`, or copy-paste).

## Owner

The implementer (drives) + the reviewer who signed off in `review-feature`.

## Inputs

- `<slug>` — feature slug (same one used by every upstream stage).
- **Gate (hard refuse):** `docs/features/<slug>/_review/review-<date>.md` showing `PASS`. If missing or showing `CHANGES REQUESTED` → refuse with: «run `/sdlc:review-feature <slug>` first — ship-feature requires a PASS verdict».
- Read: `docs/features/<slug>/PRD.md` (what to claim in the changelog), `docs/features/<slug>/adr/` (decisions worth recording), the feature's commits (`SDLC-Task` trailer history via `git log --grep SDLC-Task`).

## Protocol

1. **Gate check.** Confirm `docs/features/<slug>/_review/review-<date>.md` exists and its verdict is `PASS` (search for the most recent date). If absent or non-PASS → hard refuse with the pointer above.

2. **Final verification — does it actually work.** Re-run the detected gate (unit + integration where available + lint + vet). Then **run the feature for real** against its acceptance criteria — not just "tests pass": start the app / hit the endpoint / exercise the flow and observe the PRD's outcomes (e.g. the default-on read returns defaults; an invalid value is rejected). If the app cannot be run here (no runtime, no Docker), say so explicitly and record what was verified vs deferred — never claim verified-working when only tests compiled.

3. **Write the changelog.** From [`./templates/changelog.md`](./templates/changelog.md): what changed, why (link `PRD.md` + the key ADRs), any migration/operational note (e.g. "adds migration 000023 — run it on deploy"), and how to use it. Partner-facing if the change is partner-facing. Write to `docs/features/<slug>/CHANGELOG.md`.

4. **Prepare the PR body.** Ensure the work is on a feature branch (not the default branch). Draft the PR body from [`./templates/pr-body.md`](./templates/pr-body.md): summary, the ACs it satisfies, links to PRD/sad/ADRs, the `SDLC-Task` commit list, the test + verification evidence, and any migration/rollback note.

5. **Detect the forge + propose the PR command.** Take the host from the git remote URL and detect the forge as in [`check-pr` → Detect the forge](../check-pr/SKILL.md#detect-the-forge):
   - `github.com`, or a host where `gh auth status --hostname <host>` exits `0` (GitHub Enterprise) → `gh pr create --title "feat(<slug>): <summary>" --body-file docs/features/<slug>/pr-body.md`
   - `gitlab.com`, or a host where `glab auth status --hostname <host>` exits `0` (self-hosted GitLab) → `glab mr create --title "feat(<slug>): <summary>" --description-file docs/features/<slug>/pr-body.md`
   - Any other forge (Bitbucket, Gitea/Forgejo, Azure DevOps…), an unknown host, or an undetectable remote → no command from memory: print the branch name + body for manual PR creation and ask the user for the PR link once it exists (step 6 needs it).
   - Nested code repos → one PR per repo that has feature commits, each with its own remote's command. If one PR needs another merged first (the app's e2e runs against the api's default branch), write that order into both PR bodies.
   **Propose** the command and ask whether to create the PR now. Push the feature branch and create it only on the user's yes (or the user runs it and gives you the URL). Never push to the default branch and never merge.

6. **Read every check — fix until green.** For each PR that now exists, run the [`check-pr`](../check-pr/SKILL.md) skill now, in this session (`/sdlc:check-pr <PR URL>`, with this `<slug>`): it dispatches one `sdlc:pr-fixer` agent per PR, which waits for the PR's pipeline, read every check, and for each failing one read the log, find the root cause, fix it on the feature branch, re-run the local gate, commit, push, and read all checks again — until none is failing. Manual / `allow_failure` / skipped jobs are not failures; list them in the report. When the cause is unclear — another repo or merge/deploy order, a flaky or runner failure, a fix that would change the PRD/AC/contract or weaken a test, missing secrets or CI settings — the agent stops, this session asks with `AskUserQuestion` and resumes the agent with the answer; never guess. No PR created (the user declined) → skip and say so.

7. **Update the roadmap → Shipped.** Move this feature's item from **Now** to **Shipped** in `docs/roadmap.md`: add the date, the outcome one-liner, a link to `docs/features/<slug>/`, and the PR link/command. Remove the item from the Now table. If `docs/roadmap.md` does not exist → skip and note it (roadmap is optional at this stage).

8. **Terminal handoff.** Emit the **stage-handoff block** per [`../_shared/handoff.md`](../_shared/handoff.md) — terminal variant. *What I did* (verification result: verified-working / what was deferred and why; the checks report per PR from step 6 and its end state — all green / waiting on the user / stopped; the roadmap update). *Review* (the changelog path + the PR body path + the fix commits pushed in step 6). *Run next* = **Done** — the PR URL (or the command if the PR was not created); «merging to main is your call». There is no `/sdlc:` successor.

## Definition of Done

- Gate passed: `_review/review-<date>.md` shows PASS — the skill confirmed it before proceeding.
- The gate was re-run and the feature was exercised against its ACs (or the deferral was stated explicitly with the reason).
- `docs/features/<slug>/CHANGELOG.md` exists, linking PRD + load-bearing ADRs and including the operational note (migrations, flags).
- `docs/features/<slug>/pr-body.md` is prepared with the full PR body.
- The forge-appropriate PR command is proposed (work is on a feature branch; main untouched); the PR is created only on the user's yes.
- Every created PR had all its checks read on its latest commit; each failing check was fixed on the feature branch (local gate green, commit pushed) and all checks re-read until none failed — or the loop stopped on an unclear case and the user's question/decision is in the report.
- Manual / `allow_failure` / skipped jobs are listed in the checks report, not counted as failures.
- No test was weakened or skipped, no job was turned off, nothing was merged and auto-merge was not turned on.
- `docs/roadmap.md` updated — feature moved to Shipped (or skip noted if roadmap absent).

## Anti-patterns

- **Shipping without a PASS review.** The gate is unconditional — `review-feature` must confirm correctness before `ship-feature` runs.
- **"Tests pass" ≠ "it works".** Run the actual feature against the PRD's outcomes; green unit tests don't prove the wired system behaves.
- **Claiming verified when you only compiled.** If the runtime/Docker wasn't available, say what was deferred — don't overstate.
- **Auto-merging to main / pushing to a shared remote unasked.** Propose the PR; the merge is the team's call. Green checks are not a reason to merge or to turn on auto-merge.
- **Opening the PR and walking away.** A PR with a red check is not shipped — step 6 runs `check-pr` on every PR created here. Read every check, not only the required ones; the forge's result for the latest commit is the truth, not the local gate.
- **Making a check green by weakening it.** Loosening an assertion, skipping or deleting a test, `allow_failure` / `continue-on-error`, `[skip ci]` — never. If the test looks wrong, ask.
- **Guessing when the cause is not in this branch.** A job that runs against another repo's default branch, a merge/deploy order dependency, a flaky runner, a missing secret — ask the user; don't patch around it or retry in a loop.
- **Fixing only the check you looked at.** Every push starts a new pipeline; read all checks again.
- **A changelog that restates the diff.** Say what changed and why (link the PRD + ADR), plus the operational note (migrations, flags) — not a file list.
- **Forgetting the migration/rollback note** when the change includes one — the deployer needs it.
- **Skipping the roadmap update.** If `docs/roadmap.md` exists, the Shipped move is not optional — delivery itself keeps the roadmap current.

## References & templates

- [`./templates/changelog.md`](./templates/changelog.md) — changelog scaffold.
- [`./templates/pr-body.md`](./templates/pr-body.md) — PR description scaffold (forge-agnostic).
- [`../check-pr/SKILL.md`](../check-pr/SKILL.md) — the read-checks → fix → repeat loop, the exact `gh` / `glab` commands, and the ask-when-unclear cases (step 6).
- [`../_shared/handoff.md`](../_shared/handoff.md) — stage-handoff block format (terminal variant).
