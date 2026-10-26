# Changelog

Формат — [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/), версії — [SemVer](https://semver.org/lang/uk/).
Breaking change → нова major-версія і секція `### Breaking` першою.

## sdlc

### [0.0.1] — 2026-10-26

#### Added

- Плагін `sdlc` у маркетплейсі: форк [genkovich/sdlc](https://github.com/genkovich/sdlc) 4.6.2 (коміт `27cadcb`)
  справжніми файлами в `plugins/sdlc/`, з `LICENSE` автора.
- `generate-data-model` читає `.claude/rules/migrations.md` проєкту на кожному запуску, і той переважує
  дефолти курсу (формат міграцій, PK, CHECK, аудит-колонки).
- `implement-tasks` підтримує вкладені код-репо: гілка, тести, комміт — у репо, якому належать файли задачі;
  новий ключ `repos:` у `.claude/sdlc.local.md`.
- Виправлені посилання на файли; шаблон PR у `ship-feature` без підпису інструмента.

## my-toolkit

### [1.1.0] — 2026-10-26

#### Added

- PreToolUse-хук `guard-rm.py` на `rm`, `unlink`, `find -delete` і `find -exec rm`, також за `sudo`, `bash -c`,
  `cd …&&` і heredoc: шляхи строго в `/tmp` і `$TMPDIR` поза проєктом — без питань; деінде або коли шлях не
  видно до запуску — `ask`; рекурсивно `/`, `~`, корінь проєкту чи вище, вкладене git-репо, сама тимчасова чи
  вільна папка, шаблон у корені проєкту — заборона.
- `.claude/guard-rm.json` проєкту: `{"safe_dirs": [...]}` — папки проєкту, де видалення йде без питань
  (як `art/drafts` у dronehold).
- `test-guard-rm.sh`: 108 перевірок; `/my-toolkit:guard-test` проганяє обидва тести.

#### Changed

- Плагін увімкнений глобально або в проєкті тепер питає дозволу на будь-яке видалення поза тимчасовими й
  вільними папками. Проєкт, якому потрібна своя папка без питань, оголошує її в `.claude/guard-rm.json`.

### [1.0.0] — 2026-10-18

#### Added

- Перший реліз у маркетплейсі `vetaloffline-team`.
- PreToolUse-хук `guard-main.py`: на `main`/`master` тільки читання, `pull`, `fetch` і перехід на іншу гілку;
  push у `main`, `gh pr merge`, зміни `main` через `gh api` — заборонені.
- Skill `/my-toolkit:guard-test`: проганяє тести хука з завантаженої копії плагіна.
- Копія хука і тестів з `vetaloffline/dronehold` (`.agents/hooks/`) справжніми файлами, без symlink.
