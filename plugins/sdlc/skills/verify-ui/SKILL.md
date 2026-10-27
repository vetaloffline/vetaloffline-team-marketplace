---
name: verify-ui
model: sonnet
effort: medium
agents: []
description: >-
  Use to verify a UI surface's acceptance criteria through a LIVE browser run — open the
  running app, drive the scenario, read the real page state (DOM, computed styles, storage),
  and return a per-AC pass/fail with evidence. This is the browser feedback channel: it catches
  what compiles and "passes the logic" but is visually or behaviourally broken. Triggers on
  "verify ui for {slug}", "verify {story} in the browser", "перевір UI {story}",
  "прокликай {story} у браузері", "verify AC through the UI", "/sdlc:verify-ui {slug-or-story}".
  CLI-first (token-efficient `playwright-cli` in bash, the default for loops/CI); Playwright MCP
  stays available for live stateful debugging. Reads the AC from the feature/story file, never
  invents criteria, never fixes code — it only renders a verdict. Hard-refuses if no dev server
  is reachable.
triggers:
  - /sdlc:verify-ui
  - "verify ui for"
  - "verify in the browser"
  - "перевір UI"
  - "прокликай"
  - "verify AC through the UI"
stage: "util"
---

# Skill: verify-ui (SDLC utility — the browser feedback channel)

`verify-ui` is the **live-run** verification channel for a UI surface. Where the deterministic
gate (types + tests) is powerless — it compiles, «the logic passes», but the button doesn't click, the field
doesn't accept input, the padding has shifted, the state is lost after a reload — **only** a real
run in the browser catches it. The skill takes the feature's/story's acceptance criteria (AC), runs the scenario
against the running application, reads the **real page state** and gives a discrete verdict
per AC.

This is a channel for **verifying the result**, not for writing code: the skill doesn't «fix» anything — it only
renders a verdict with evidence. The fix is a separate step (`implement-tasks`).

The surface decides whether this channel applies: `verify-ui` works only when `sad.md`
`target_surfaces` contains `web-frontend` (or another UI slice) → [`../_shared/surfaces.md`](../_shared/surfaces.md).
For a backend-only feature the browser channel gives no signal — there it's tests/contracts/logs.

## CLI by default, MCP for live debugging

The channel's canonical tool is **Playwright**, but in two forms:

- **`playwright-cli` (default).** Bash commands, token-efficient: they don't load huge tool schemas
  and full accessibility trees into the context. This is the default for loops and CI, because
  the scenario is fixed and has to be run cheaply many times. The vendor (Microsoft) explicitly
  recommends the CLI for coding agents.
- **Playwright MCP** — for a narrow case: live exploration with preserved state, when you don't yet
  know what is broken and the agent has to click and react in real time. Keeping MCP in a loop for
  hundreds of iterations is the fastest way to burn the token budget.

> `playwright-cli` is young (pre-1.0, early 2026), but first-party and vendor-sanctioned. Before
> a run, check the current command syntax (`playwright-cli --help`).

### Installation (one-time)

```bash
npm install -g @playwright/cli@latest   # CLI for agents
npx playwright install chromium          # browser
playwright-cli install --skills          # give the agent the CLI «skills» (SKILL.md from Playwright)
```

## Precondition (GATE)

The application must be up (dev server). If `playwright-cli open <url>` fails to connect —
**don't invent the state**; first start the server (`npm run dev` / `make dev`) and retry. Without a live
application the skill hard-refuses.

## Steps

1. **Find the ACs.** Read the feature/story file (`docs/features/<slug>/PRD.md` §5, or `tasks/<story>.md`)
   — extract the Given/When/Then blocks. Check **only** what is there.
2. **Open the application.** `playwright-cli open <url>` (e.g. `http://localhost:5173`).
3. **Read the initial state.** `playwright-cli snapshot` — returns not a picture but a text
   tree of elements with refs (`e21` etc.). Pick the elements the ACs refer to.
4. **Reproduce the scenario.** For each AC run the When via the CLI: `click <ref>`, `type <text>`,
   `fill <ref> <text>`, `press <key>`, `select <ref> <val>`. Then **read the real state** for the
   Then: `snapshot` (DOM), `eval "<js>"` (computed styles/values — e.g. `getComputedStyle`),
   `localstorage-get <key>` (persistence), `reload` (does the state survive a reload).
5. **Record the evidence.** `playwright-cli screenshot` saves a snapshot as the run's artifact.

## Output — a discrete verdict per AC (evidence-before-assertion)

```
<story> · verify-ui
  AC-1  FAIL — the «Cancel» button padding is 8px, reference 12px (getComputedStyle padding-x = 8px)
  AC-2  PASS — the form saves and closes; the card in the list is updated
  AC-3  SKIP — unreachable while AC-1 is red
Summary: FAIL (1/3). Evidence: tmp/<story>-after.png
```

- Every FAIL comes with the **expected vs actual** value, read from the page (not «it seems»).
- The verdict is tied to concrete ACs from the story file, not a general «works/doesn't».
- There is a link to the screenshot evidence.

## Design→code on input (Figma) — a separate, input channel

If the ACs refer to a mockup, the agent reads the design's **structure** via the official **Figma Dev Mode
MCP** (node tree, layout, tokens, components) — not a flat picture. But this is an **input** channel
(how the agent *reads* the design); checking the *result* still goes through `verify-ui` in the browser. So
the Figma MCP doesn't replace the browser channel, it complements it.

## Acceptance criteria of this skill

- A verdict for every AC from the story/PRD, with the actual value from the live page state.
- The run goes through `playwright-cli` by default (MCP only if live debugging is explicitly needed).
- There is screenshot evidence of the run.

## Anti-patterns

- **Don't invent ACs** — check only what is in the story/PRD.
- **Don't substitute a unit test for the browser** — the point of the channel is the real DOM/behaviour.
- **Don't «fix» code here** — the skill only gives a verdict; the fix is a separate step (`implement-tasks`).
- **Don't report PASS without a read state** — «looks right» without `snapshot`/`eval` is
  not evidence but a guess.
- **Don't keep MCP in a long loop** for convenience — it's a token sink; the loop = CLI.

## References

- [`../_shared/surfaces.md`](../_shared/surfaces.md) — the `target_surfaces` taxonomy; this channel
  applies only to UI surfaces.
- [`../_shared/handoff.md`](../_shared/handoff.md) — the stage-handoff block format.
- [`review-feature`](../review-feature/SKILL.md) — an independent clean-context reviewer of the diff against the
  ACs; `verify-ui` is its browser helper on a UI surface (the reviewer looks at the diff, verify-ui
  looks at the live screen).

## Stage handoff

> **verify-ui → implement-tasks / review-feature.** If there is a FAIL, return the concrete ACs to
> `implement-tasks` with actual vs expected; if everything is PASS on the UI surface, hand over to
> `review-feature` for an independent review of the diff. Add the evidence (screenshot + verdict lines) to
> `docs/features/<slug>/_review/`.
