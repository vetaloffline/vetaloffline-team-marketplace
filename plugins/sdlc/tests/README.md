# sdlc plugin tests

Manual test fixtures for high-blast-radius skills. No automated runner for v3.0 — each fixture is run by hand and diffed against the expected output. A CI runner is backlog.

## Structure

```
tests/
├── README.md               # this file
├── rubric.md               # eval criteria (DoD checks per skill)
└── fixtures/
    ├── intake/
    │   ├── 01-rate-limit/   # full intake flow with ADR + CONTEXT
    │   ├── 02-typo-fix/     # XS feature — minimal brief
    │   └── 03-multi-context/  # multi-context repo with CONTEXT-MAP.md
    ├── propose-adr/
    │   ├── 01-pass-mp/      # 3/3 PASS → ADR stub
    │   └── 02-fail-mp/      # MP fail → refuse with reason
    ├── classify-size/
    │   └── 01-classify-s/   # an M scenario moves down to S
    └── prep-review/
        └── 01-review-25/    # ≤25 actionable items with WHERE-context
```

Each fixture directory has:
- `input.md` — user message + (optional) pre-existing artefacts.
- `expected/` — a directory with the expected created/changed files.
- `notes.md` — (optional) key edge cases the skill must catch.

## Running a fixture manually

```bash
# 1. Preparation — copy pre-existing artefacts (if any)
SLUG=rate-limit-test
mkdir -p delivery/$SLUG
cp -r plugin/tests/fixtures/intake/01-rate-limit/pre-existing/* delivery/$SLUG/ 2>/dev/null

# 2. Read input.md and run the skill
cat plugin/tests/fixtures/intake/01-rate-limit/input.md
# Open Claude Code, paste input as user message, observe behavior.

# 3. Diff the output against expected
diff -r delivery/$SLUG/ plugin/tests/fixtures/intake/01-rate-limit/expected/

# 4. Score by rubric.md
```

## Scoring per fixture

Use `rubric.md` to score:
- ✅ Output exists in `docs/features/<slug>/`.
- ✅ DoD checked (per skill's `## Definition of Done`).
- ✅ No anti-patterns triggered.
- ✅ Commit proposed correctly (right message format).

Pass = all 4. A fail on any of them — the fixture caught a regression.

## Adding a new fixture

1. Pick critical skill (intake / propose-adr / classify-size / prep-review).
2. Define scenario name (kebab-case, descriptive): `04-conflict-term-resolution`, `02-fail-mp-no-finalists`.
3. Create `fixtures/<skill>/<scenario>/`:
   - `input.md` — user message + (optional) list of pre-existing artefacts.
   - `expected/` — copy from manual run that you trust.
   - `notes.md` — what edge case this catches.
4. Update this README's structure tree.

## Why not automate?

Skills use AskUserQuestion and LLM generation, which are not deterministic. Snapshot testing needs a mock LLM or record-replay. Backlog: explore `claude --eval` mode when it becomes available; meanwhile a manual diff is enough for regressions of critical flows.

## Coverage

| Skill | Fixtures | High-blast-radius reason |
|-------|---------:|---------------------------|
| intake | 3 | Composite — a bug in §A affects §B, §C, §D, §E |
| propose-adr | 2 | The MP threshold is subjective → a false PASS can spam ADRs |
| classify-size | 1 | Wrong size → wrong skip-matrix in 4 wrappers |
| prep-review | 1 | GATE 16 — without a checklist the review is uneven |
