#!/usr/bin/env bash
# Статична перевірка маркетплейсу без Claude Code: JSON читається, кожен запис plugins[] має папку з
# plugin.json, name і version у записі й у plugin.json однакові, у plugins/ нема symlink.
# Запуск з кореня репо: bash scripts/check-marketplace.sh
# Вивід: по рядку на помилку + підсумок. Exit 0 — помилок нема, 1 — є, 2 — нема jq або marketplace.json.
set -u
M=.claude-plugin/marketplace.json
command -v jq >/dev/null || { echo "нема jq"; exit 2; }
[ -f "$M" ] || { echo "нема $M (запускати з кореня репо)"; exit 2; }
err=0
fail() { echo "ПОМИЛКА: $*"; err=$((err+1)); }

while IFS= read -r -d '' f; do
  jq empty "$f" 2>/dev/null || fail "$f: невалідний JSON"
done < <(find . -name '*.json' -not -path './.git/*' -print0)

n=$(jq '.plugins | length' "$M")
for i in $(seq 0 $((n-1))); do
  name=$(jq -r ".plugins[$i].name" "$M")
  src=$(jq -r ".plugins[$i].source | if type == \"string\" then . else \"\" end" "$M")
  ver=$(jq -r ".plugins[$i].version // \"\"" "$M")
  [ -n "$src" ] || { echo "plugins[$i] $name: source не відносний шлях, пропускаю"; continue; }
  pj="$src/.claude-plugin/plugin.json"
  [ -f "$pj" ] || { fail "plugins[$i] $name: нема $pj"; continue; }
  pname=$(jq -r '.name' "$pj")
  pver=$(jq -r '.version // ""' "$pj")
  [ "$pname" = "$name" ] || fail "plugins[$i]: name у marketplace.json \"$name\", у $pj \"$pname\""
  [ "$pver" = "$ver" ] || fail "plugins[$i] $name: version у marketplace.json \"$ver\", у $pj \"$pver\""
  echo "ok: $name $ver ($src)"
done

links=$(find plugins -type l 2>/dev/null)
[ -z "$links" ] || fail "symlink у plugins/ (при встановленні Claude Code пропускає ті, що ведуть за межі маркетплейсу): $links"

echo "помилок: $err"
[ "$err" = 0 ]
