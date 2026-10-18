## Що змінено

-

## Версія

- [ ] `version` піднята в `plugins/<назва>/.claude-plugin/plugin.json` і в `.claude-plugin/marketplace.json` (однаково)
- [ ] Breaking change → major-версія, секція `### Breaking` у `CHANGELOG.md`
- [ ] Запис у `CHANGELOG.md`

## Безпека (див. SECURITY.md)

- [ ] Хуки: matcher вузький, команда зрозуміла, без мережі
- [ ] MCP-сервери: джерело коду і змінні середовища перевірені
- [ ] Виконувані файли: усі в репо, нічого не завантажується під час роботи
- [ ] Не читає секретів, які йому не потрібні
- [ ] Мережеві виклики: нема, або описано куди і навіщо
- [ ] Залежності: версії зафіксовані, без відомих CVE

## Перевірки

- [ ] `claude plugin validate . --strict`
- [ ] `claude plugin validate ./plugins/<назва> --strict`
- [ ] Тести плагіна (для `my-toolkit`: `bash plugins/my-toolkit/hooks/test-guard-main.sh`)
