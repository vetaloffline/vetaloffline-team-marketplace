# Changelog

Формат — [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/), версії — [SemVer](https://semver.org/lang/uk/).
Breaking change → нова major-версія і секція `### Breaking` першою.

## my-toolkit

### [1.0.0] — 2026-10-18

#### Added

- Перший реліз у маркетплейсі `vetaloffline-team`.
- PreToolUse-хук `guard-main.py`: на `main`/`master` тільки читання, `pull`, `fetch` і перехід на іншу гілку;
  push у `main`, `gh pr merge`, зміни `main` через `gh api` — заборонені.
- Skill `/my-toolkit:guard-test`: проганяє тести хука з завантаженої копії плагіна.
- Копія хука і тестів з `vetaloffline/dronehold` (`.agents/hooks/`) справжніми файлами, без symlink.
