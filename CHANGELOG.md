# Changelog

Формат — [Keep a Changelog](https://keepachangelog.com/uk/1.1.0/), версії — [SemVer](https://semver.org/lang/uk/).
Breaking change → нова major-версія і секція `### Breaking` першою.

## sdlc

### [0.0.2] — 2026-10-27

#### Changed

- `complete-sequence-diagrams` питає не «які флоу мають бути», а чи правильно згенеровані флоу: інвентар
  (крок 2), кожна діаграма (крок 6) і N/A-рядки покриття (крок 7) подаються як рев'ю з рядком «Джерела: …»
  (US/AC, розділ `sad` чи ADR, `file:line` у коді). Опції — «Все вірно, апрув» / «Є розбіжність з джерелом —
  виправити» / «Відкласти в OQ» / «Прибрати». Owner: Tech Lead перевіряє технічну правильність, PM на цій
  стадії нічого нового не вирішує.
- Нове правило джерел: поведінку, якої нема в PRD, SAD чи коді, скіл не домальовує і не просить вигадати —
  позначає `source gap` у блоці, пише у `**Flags:**` і в handoff відправляє в `/sdlc:clarify-prd` (продукт)
  чи `/sdlc:architecture-design` (техніка).
- `_shared/diagram-presentation.md`: питання-підтвердження діаграми — опис прозою + рядок «Джерела: …»,
  сформульоване як рев'ю. `_shared/ask-style.md`: нова секція «Review of a derived artifact» з канонічним
  набором опцій рев'ю.

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
