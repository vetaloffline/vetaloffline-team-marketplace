# Fixture: classify-size / 01-classify-s

## Scenario

A feature on the XS/S border: 1 API endpoint + 1 week + an internal-only breaking change. Expected classification: `S`.

## Pre-existing

```
delivery/rate-limit-headers/idea-brief.md
```

The idea-brief has §Rough size = `S` (as a hint, not authoritative).

## User input

```
/sdlc-classify-size rate-limit-headers
```

## Expected behavior

1. Skill reads idea-brief.md §Rough size = `S` (starting hint).
2. No `.size` file exists → continue.
3. Q1 PR count: user → `2-5 PR`.
4. Q2 time: user → `1 week`.
5. Q3 new module/API/migration: user → `Yes, one of the three` (1 new header in the API).
6. Q4 breaking changes: user → `Yes, internal only`.
7. Classify → `S` (matches: 2-5 PR + 1 week + 1 of 3 + internal).
8. Skill confirms: «Classifying as `S`. Record it?» User: «Yes».
9. Write `delivery/rate-limit-headers/.size` → `S` (single line, no trailing newline issues).
10. PRD.md doesn't exist → skip sync.
11. Commit `size: rate-limit-headers classified as S`.

## Expected files

```
delivery/rate-limit-headers/
├── idea-brief.md   # UNCHANGED
└── .size           # NEW — single line: S
```

## Score against rubric.md

D1: the `.size` file exists, a single letter `S`.
D2: all 4 questions asked; user confirm; not silent write.
D3: `.size` is one-liner (no frontmatter, no comments).
D4: commit prefix `size:`, slug + size match.

## Edge case caught

If the skill classifies automagically and writes without AskUserQuestion → catches the silent-classify regression.
If the skill writes `S\n\n` or multi-line → the wrappers' grep logic fails.
