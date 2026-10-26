---
name: guard-test
description: Прогнати тести хуків guard-main.py і guard-rm.py з плагіна my-toolkit і показати, з якого шляху плагін завантажився. Тільки коли людина сама набрала /my-toolkit:guard-test.
argument-hint: "| --help"
disable-model-invocation: true
---

# /my-toolkit:guard-test — тести guard-main.py і guard-rm.py

Вхід: `$ARGUMENTS` = `--help` або `-h` → крок 0. Інше або порожньо → крок 1.

## Крок 0. Довідка

Вивести блок нижче дослівно і завершити skill.

```
/my-toolkit:guard-test

Проганяє тести guard-main.py (test-guard-main.sh) і guard-rm.py (test-guard-rm.sh) з тієї копії плагіна,
яку завантажив Claude Code, і показує шлях до неї. Нічого не змінює: тести працюють у тимчасових
git-репо в $TMPDIR.

  -h, --help   ця довідка
```

## Крок 1. Шлях плагіна

`ROOT` = `${CLAUDE_PLUGIN_ROOT}` (Claude Code підставляє шлях при завантаженні skill).
Виконати `ls -la "${CLAUDE_PLUGIN_ROOT}/hooks"`. Нема `guard-main.py`, `guard-rm.py` або `hooks.json` → вивести
вивід і СТОП.

## Крок 2. Тести

Виконати в sandbox, кожен окремо:

- `bash "${CLAUDE_PLUGIN_ROOT}/hooks/test-guard-main.sh"; echo "exit=$?"`
- `bash "${CLAUDE_PLUGIN_ROOT}/hooks/test-guard-rm.sh"; echo "exit=$?"`

## Крок 3. Звіт

Вивести:

```
Плагін: my-toolkit, шлях: <ROOT>
guard-main: <рядок pass=… fail=…>, exit=<код>
guard-rm:   <рядок pass=… fail=…>, exit=<код>
<рядки FAIL, якщо є>
```

Пройшов, якщо в обох `exit=0` і `fail=0`. Інакше — написати «тести не пройшли» і рядки `FAIL` з виводу.
