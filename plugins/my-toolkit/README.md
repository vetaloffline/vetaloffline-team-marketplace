# my-toolkit

## Purpose

Не дає агенту змінювати `main`/`master` напряму. На `main` дозволені тільки читання, `pull`, `fetch` і перехід
на іншу гілку. Зміни йдуть через гілку й PR.

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
| `/my-toolkit:guard-test` | проганяє `test-guard-main.sh` з тієї копії плагіна, яку завантажив Claude Code, і показує її шлях |

Тільки ручний виклик (`disable-model-invocation: true`).

## Hooks

| Подія | Matcher | Команда | Що робить |
|---|---|---|---|
| `PreToolUse` | `Bash` | `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/guard-main.py"` | exit 2 (заборона з причиною в stderr) для змін main/master: commit/push/merge на main, push у main з гілки, `gh pr merge`, зміни main через `gh api`; exit 0 — решта |

Хук не межа безпеки: скрипти, alias і бектики він не розбирає. Гарантію дає захист гілки на сервері.

## Тести

```bash
bash plugins/my-toolkit/hooks/test-guard-main.sh
```

Пройшли, якщо останній рядок `pass=N fail=0` і exit 0.

## Звідки код

`hooks/guard-main.py` і `hooks/test-guard-main.sh` — копії з репо
[vetaloffline/dronehold](https://github.com/vetaloffline/dronehold) (`.agents/hooks/`). Правка в одному місці
не переноситься в інше сама.
