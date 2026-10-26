# my-toolkit

## Purpose

Два запобіжники для агента:

- **guard-main** — не дає змінювати `main`/`master` напряму. На `main` дозволені тільки читання, `pull`, `fetch`
  і перехід на іншу гілку. Зміни йдуть через гілку й PR.
- **guard-rm** — не дає видаляти просто так. Тимчасові папки (`/tmp`, `$TMPDIR`) — без питань, решта — з дозволу
  людини, а рекурсивно знести `/`, `~`, проєкт, вкладене git-репо чи саму тимчасову папку не можна навіть з дозволом.

## Install

```bash
claude plugin marketplace add vetaloffline/vetaloffline-team-marketplace
claude plugin install my-toolkit@vetaloffline-team
```

Перевірити: `claude plugin list` → `my-toolkit@vetaloffline-team`, `Status: ✔ enabled`.

Разовий запуск з клону цього репо, без маркетплейсу (id буде `my-toolkit@inline`):

```bash
claude --plugin-dir ./plugins/my-toolkit
```

Потрібні на машині: `python3` (хук), `git`, `jq` (тести хука).

## Skills

| Виклик | Що робить |
|---|---|
| `/my-toolkit:guard-test` | проганяє `test-guard-main.sh` і `test-guard-rm.sh` з тієї копії плагіна, яку завантажив Claude Code, і показує її шлях |

Тільки ручний виклик (`disable-model-invocation: true`).

## Hooks

| Подія | Matcher | Команда | Що робить |
|---|---|---|---|
| `PreToolUse` | `Bash` | `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/guard-main.py"` | exit 2 (заборона з причиною в stderr) для змін main/master: commit/push/merge на main, push у main з гілки, `gh pr merge`, зміни main через `gh api`; exit 0 — решта |
| `PreToolUse` | `Bash` | `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/guard-rm.py"` | для `rm`, `unlink`, `find -delete`, `find -exec rm` (також за `sudo`, `bash -c`, `cd …&&`, heredoc): exit 0 без виводу — усі шляхи у вільних папках; `permissionDecision: "ask"` — деінде або шлях не видно (`$X`, бектики, `xargs rm`); exit 2 — рекурсивно `/`, `~`, корінь проєкту чи вище, вкладене репо, сама тимчасова чи вільна папка, шаблон у корені проєкту |

Хуки не межа безпеки: скрипти, alias, бектики, `python -c`, `mv` у кошик вони не розбирають. Гарантію для `main`
дає захист гілки на сервері.

### guard-rm: вільні папки

Без питань видаляється:

- усе строго всередині `/tmp` і `$TMPDIR` (на macOS — `/private/tmp`, `/private/var/folders/…`), якщо це не
  частина проєкту (проєкт чи його worktree теж буває в `/tmp`);
- усе строго всередині папок, які проєкт оголосив у `.claude/guard-rm.json`:

```json
{"safe_dirs": ["art/drafts"]}
```

Шляхи — відносно кореня проєкту (`$CLAUDE_PROJECT_DIR`). Запис поза проєктом, абсолютний шлях, сам корінь або
битий JSON ігноруються: вільних папок стає менше, не більше. Сама вільна папка рекурсивно не видаляється.

Вкладені репо — папки першого рівня проєкту з власним `.git` (workspace з кількох репо); їх хук знаходить сам.

Хук сумісний з правилами `permissions`, але deny/ask на `Bash(rm …)` сильніші за нього: з ними «без питань»
не спрацює.

## Тести

```bash
bash plugins/my-toolkit/hooks/test-guard-main.sh
bash plugins/my-toolkit/hooks/test-guard-rm.sh
```

Пройшли, якщо останній рядок кожного `pass=N fail=0` і exit 0.

## Звідки код

`hooks/guard-main.py` і `hooks/test-guard-main.sh` — копії з репо
[vetaloffline/dronehold](https://github.com/vetaloffline/dronehold) (`.agents/hooks/`). Правка в одному місці
не переноситься в інше сама.

`hooks/guard-rm.py` і `hooks/test-guard-rm.sh` виросли з dronehold (`.claude/hooks/guard-rm.py`, де без питань
видалялась лише `art/drafts/`): тут вільні — тимчасові папки, а папки проєкту задає `.claude/guard-rm.json`.
