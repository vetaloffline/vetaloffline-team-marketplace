# Changelog

Формат — [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/), версії — [SemVer](https://semver.org/lang/uk/).
Breaking change → нова major-версія і секція `### Breaking` першою.

## sdlc

### [0.0.1] — 2026-10-26

#### Added

- Плагін `sdlc` у маркетплейсі: форк [genkovich/sdlc](https://github.com/genkovich/sdlc) 4.6.2, код у
  [vetaloffline/sdlc](https://github.com/vetaloffline/sdlc) (`plugin/`, джерело `git-subdir`).
- `generate-data-model` читає `.claude/rules/migrations.md` проєкту на кожному запуску, і той переважує
  дефолти курсу (формат міграцій, PK, CHECK, аудит-колонки).
- `implement-tasks` підтримує вкладені код-репо: гілка, тести, комміт — у репо, якому належать файли задачі;
  новий ключ `repos:` у `.claude/sdlc.local.md`.
- Виправлені биті посилання в README і скілах; з шаблону PR прибраний підпис «Generated with Claude Code».

## my-toolkit

### [1.0.0] — 2026-10-18

#### Added

- Перший реліз у маркетплейсі `vetaloffline-team`.
- PreToolUse-хук `guard-main.py`: на `main`/`master` тільки читання, `pull`, `fetch` і перехід на іншу гілку;
  push у `main`, `gh pr merge`, зміни `main` через `gh api` — заборонені.
- Skill `/my-toolkit:guard-test`: проганяє тести хука з завантаженої копії плагіна.
- Копія хука і тестів з `vetaloffline/dronehold` (`.agents/hooks/`) справжніми файлами, без symlink.
