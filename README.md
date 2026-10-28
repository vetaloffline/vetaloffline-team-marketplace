# vetaloffline-team-marketplace

## Що це

Маркетплейс плагінів [Claude Code](https://code.claude.com/docs/en/plugin-marketplaces): git-репо з каталогом
`.claude-plugin/marketplace.json` і плагінами в `plugins/`. Ім'я маркетплейсу — `vetaloffline-team`. Сервера
нема: Claude Code клонує цей репо і бере плагіни з нього.

## Як додати у Claude Code

У shell:

```bash
claude plugin marketplace add vetaloffline/vetaloffline-team-marketplace
claude plugin install my-toolkit@vetaloffline-team
```

Або в сесії Claude Code: `/plugin marketplace add vetaloffline/vetaloffline-team-marketplace`, потім
`/plugin install my-toolkit@vetaloffline-team`.

Перевірити: `claude plugin list` показує `my-toolkit@vetaloffline-team` зі `Status: ✔ enabled`, а в сесії
працює `/my-toolkit:guard-test`.

Підключити всім, хто працює в одному репо (пише в `.claude/settings.json` цього репо, його треба закомітити):

```bash
claude plugin marketplace add vetaloffline/vetaloffline-team-marketplace --scope project
```

Оновити: `/plugin marketplace update vetaloffline-team` у сесії або `claude plugin update my-toolkit@vetaloffline-team`
у shell. Автооновлення вмикається в `/plugin` → Marketplaces → `vetaloffline-team` → Enable auto-update.

Нема SSH-ключа для GitHub → задати `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`, тоді клон іде через HTTPS.

Політика організації (`strictKnownMarketplaces` у managed settings) може не пускати цей маркетплейс:
`claude plugin marketplace add` тоді пише `blocked by enterprise policy`. Це вирішує адміністратор організації.

## Список плагінів

| Плагін | Версія | Що робить | Деталі |
|---|---|---|---|
| `my-toolkit` | 1.1.0 | PreToolUse-хуки: `guard-main.py` — на `main`/`master` тільки читання, `pull`, `fetch`, зміни через гілку й PR; `guard-rm.py` — видалення в тимчасових папках без питань, деінде з дозволу людини, знести проєкт, вкладене репо, `~` чи `/` не можна. Skill `/my-toolkit:guard-test` проганяє тести хуків | [plugins/my-toolkit/README.md](plugins/my-toolkit/README.md) |
| `sdlc` | 0.0.6 | Форк [genkovich/sdlc](https://github.com/genkovich/sdlc) 4.6.2: SDLC-пайплайн від ідеї до релізу (PRD, SAD, ADR, дані, API, задачі, TDD, ревʼю). Скіли слухають `.claude/rules/` проєкту і працюють з вкладеними код-репо | [plugins/sdlc/README.md](plugins/sdlc/README.md) |

## Супровідники

| Хто | Що веде |
|---|---|
| [@vetaloffline](https://github.com/vetaloffline) | маркетплейс і всі плагіни (`.github/CODEOWNERS`) |

## Як контриб'ютити

1. Гілка від `main`, зміни, PR. Пряма робота в `main` — тільки через PR.
2. Новий плагін: `plugins/<назва>/` з `.claude-plugin/plugin.json` + запис у `.claude-plugin/marketplace.json`
   (`name`, `source: "./plugins/<назва>"`, `description`, `version`, `category`, `tags`, `strict`).
3. `name` у записі маркетплейсу = `name` у `plugin.json`. `version` — однакова в обох файлах (CI це перевіряє).
4. Справжні файли, не symlink: symlink на файл поза плагіном Claude Code при встановленні пропускає.
5. Перед PR:
   ```bash
   claude plugin validate . --strict
   claude plugin validate ./plugins/<назва> --strict
   ```
6. Реліз: підняти `version` в обох файлах (breaking change → major), запис у `CHANGELOG.md`, мердж, потім тег з
   папки плагіна: `claude plugin tag --push` (створює тег `<назва>--v<версія>`). Без зміни `version`
   користувачі нового коду не отримають.
7. Зміни хуків, MCP-серверів, мережевих викликів — пройти чекліст безпеки з шаблону PR і [SECURITY.md](SECURITY.md).

## Контакти

- Питання і баги: [GitHub Issues](https://github.com/vetaloffline/vetaloffline-team-marketplace/issues)
- Вразливості: не в issues, а як у [SECURITY.md](SECURITY.md)
- Пошта: 1990vetalb1990@gmail.com
