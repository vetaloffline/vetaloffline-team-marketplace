#!/usr/bin/env bash
# Тести guard-rm.py: pass — пропустити без питань, ask — спитати людину (JSON permissionDecision "ask"),
# deny — заборонити (exit 2). Наприкінці — чи хук підключений у hooks.json плагіна.
# Запуск: bash plugins/my-toolkit/hooks/test-guard-rm.sh
# Потрібні: python3, git, jq. Усе відбувається в тимчасовій папці, вона прибирається на виході.
D="$(cd "$(dirname "$0")" && pwd)"
H="$D/guard-rm.py"
T=$(mktemp -d "${TMPDIR:-/tmp}/guardrm.XXXXXX")
T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
# repo  — проєкт: два вкладені репо (api, app), вільна папка art/drafts через .claude/guard-rm.json;
# plain — проєкт без конфігу; tmp — тимчасова папка (GUARD_RM_TEMP_DIRS); other — ні те, ні те.
mkdir -p "$T/repo/.claude" "$T/repo/api/app" "$T/repo/app/src" "$T/repo/docs" "$T/repo/game" "$T/repo/art/objects" \
  "$T/repo/art/drafts/sess/x" "$T/repo/art/drafts/old" "$T/repo/art/drafts/with space" \
  "$T/plain/art/drafts/old" "$T/tmp/sess/x" "$T/tmp/old" "$T/tmp/with space" "$T/other"
for r in repo repo/api repo/app plain; do git -C "$T/$r" init -q; done
printf '{"safe_dirs": ["art/drafts", "../other", "/etc", "", "."]}\n' >"$T/repo/.claude/guard-rm.json"
ln -s "$T/repo/app" "$T/tmp/link"
ln -s "$T/repo/game" "$T/repo/art/drafts/link"
pass=0; fail=0
run() {  # $1 = stdin JSON, $2 = проєкт від $T (repo за замовчуванням) → "pass" | "ask" | "deny" | "rc=N"
  local out rc
  out=$(printf '%s' "$1" | CLAUDE_PROJECT_DIR="$T/${2:-repo}" GUARD_RM_TEMP_DIRS="$T/tmp" python3 "$H" 2>&1); rc=$?
  if [ "$rc" = 2 ]; then echo deny
  elif [ "$rc" = 0 ] && printf '%s' "$out" | grep -q '"permissionDecision": "ask"'; then echo ask
  elif [ "$rc" = 0 ] && [ -z "$out" ]; then echo pass
  else echo "rc=$rc:$out"; fi
}
check() {  # $1 очікуване, $2 отримане, $3 опис
  if [ "$2" = "$1" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL exp=$1 got=$2 :: $3"; fi
}
t() {  # $1 очікуване, $2 cwd від $T, $3 команда, $4 проєкт від $T (необов'язково)
  check "$1" "$(run "$(jq -n --arg c "$3" --arg d "$T/$2" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}')" "${4:-repo}")" "[$2] $3"
}

# === pass: тимчасова папка поза проєктом — без питань
t pass repo "rm -rf $T/tmp/old"
t pass repo "rm -rf $T/tmp/sess $T/tmp/old"
t pass repo "rm -r -f $T/tmp/sess/x"
t pass repo "rm -fr -- $T/tmp/old"
t pass repo "rm -Rf $T/tmp/old"
t pass repo "rm --recursive --force $T/tmp/old"
t pass repo "rm -rf \"$T/tmp/with space\""
t pass repo "rm -rf $T/tmp/sess/*"
t pass repo "rm $T/tmp/sess/a.png"
t pass repo "unlink $T/tmp/sess/a.png"
t pass tmp 'rm -rf old'
t pass tmp 'rm -rf ./old sess'
t pass repo "cd $T/tmp && rm -rf old"
t pass tmp 'rm -rf link'
t pass repo "rm -rf $T/tmp/old 2>/dev/null"
t pass repo "rm -rf $T/tmp/old; echo done"
t pass repo "bash -c \"rm -rf $T/tmp/old\""
t pass repo "nohup rm -rf $T/tmp/old"
t pass repo "sudo rm -rf $T/tmp/old"
t pass repo "find $T/tmp/old -name '*.png' -delete"
t pass repo "find $T/tmp/sess -type f -exec rm {} +"
# === pass: вільна папка проєкту з .claude/guard-rm.json — без питань
t pass repo 'rm -rf art/drafts/old'
t pass repo 'rm -rf art/drafts/sess art/drafts/old'
t pass repo 'rm -rf "art/drafts/with space"'
t pass repo 'rm -rf art/drafts/*'
t pass repo 'rm art/drafts/sess/a.png'
t pass repo/art/drafts 'rm -rf old sess'
t pass repo 'cd art/drafts && rm -rf old'
t pass repo 'rm -rf art/drafts/link'
t pass repo 'find art/drafts -type f -exec rm {} +'
t pass repo 'find art/drafts/old -name "*.png" -delete'
# === pass: не видалення — хук мовчить
t pass repo 'echo "rm -rf /"'
t pass repo "git commit -m 'rm -rf app'"
t pass repo 'git rm -r docs'
t pass repo 'ls -la'
t pass repo 'grep -rn "rm" docs'
t pass repo 'find . -name "*.md"'
t pass repo 'rmdir docs'
check pass "$(run '{"tool_name":"Edit","tool_input":{"file_path":"x"},"cwd":"/"}')" "не Bash"
check pass "$(run 'not json')" "битий JSON на вході"
check pass "$(run '{"tool_name":"Bash","tool_input":{},"cwd":"/"}')" "Bash без команди"

# === ask: деінде, у проєкті поза вільною папкою або шлях не видно — з дозволу людини
t ask repo 'rm docs/a.md'
t ask repo 'rm README.md'
t ask repo 'unlink docs/a.md'
t ask repo 'rm -rf docs'
t ask repo 'rm -rf api/app'
t ask repo 'rm -f app/src/x.ts'
t ask repo 'cd api && rm -rf app'
t ask repo 'rm -rf art/objects'
t ask repo 'rm -rf art/drafts/../objects'
t ask repo 'rm -rf art/drafts/old game'
t ask repo 'rm -rf art/dr*'
t ask repo 'rm -rf art/drafts/link/../../game'
t ask repo "rm -rf $T/other"
t ask repo "rm -rf $T/tmp/../other"
t ask repo "rm -rf $T/tmp/old docs"
t ask repo "rm -rf $T/tmp/*"
t ask repo 'rm -rf docs/a*'
t ask repo 'rm -rf $HOME/x'
t ask repo 'rm -rf ${TMPDIR}/x'
t ask repo 'rm -rf `pwd`/docs'
t ask repo 'rm -rf $(pwd)/docs'
t ask repo 'echo $(rm -rf docs)'
t ask repo '(rm -rf docs)'
t ask repo 'cd $X && rm -rf old'
t ask repo 'ls && rm -rf docs'
t ask repo 'bash -c "rm -rf docs"'
t ask repo 'zsh -c "rm docs/a.md"'
t ask repo 'FOO=1 rm -rf docs'
t ask repo 'env rm -rf docs'
t ask repo '/bin/rm -rf docs'
t ask repo 'sudo -u root rm docs/a.md'
t ask repo 'find . -name x | xargs rm -rf'
t ask repo 'find docs -name "*.tmp" -delete'
t ask repo 'find art/drafts/.. -delete'
t ask repo "rm -rf $T/tmp/link/../../repo/docs"
t ask repo "bash <<'EOF'
rm -rf docs
EOF"
# === ask: без конфігу art/drafts — звичайна папка; конфіг поза проєктом ігнорується
t ask plain 'rm -rf art/drafts/old' plain
t ask repo "rm -rf $T/other/x"
t ask repo 'rm /etc/hosts'

# === deny: катастрофічне — навіть з дозволом ні
t deny repo 'rm -rf .'
t deny repo 'rm -rf ..'
t deny repo 'rm -rf /'
t deny repo 'rm -rf /*'
t deny repo 'rm -rf do*'
t deny repo 'rm -rf ~'
t deny repo 'rm -rf ~/'
t deny repo "rm -rf $T/repo"
t deny repo "rm -rf $T"
t deny repo 'rm -rf api'
t deny repo 'rm -rf ./app/'
t deny repo/app 'rm -rf ../api'
t deny repo/api 'rm -rf ../..'
t deny repo 'rm -rf art/drafts'
t deny repo 'rm -rf art/drafts/'
t deny repo 'rm -rf ./art/drafts/.'
t deny repo/art/drafts 'rm -rf ../..'
t deny repo "rm -rf $T/tmp"
t deny repo "rm -rf $T/tmp/"
t deny repo "find $T/tmp -delete"
t deny repo "rm -rf $T/tmp/old && rm -rf ."
t deny repo 'sudo rm -rf /'
t deny repo 'find . -delete'
t deny repo 'find -delete'
t deny repo 'find . -type f -exec rm {} \;'
t deny repo 'bash -c "rm -rf ~"'
t deny plain 'rm -rf .' plain

# === підключення в hooks.json плагіна
J="$D/hooks.json"
check yes "$(jq -r '[.hooks.PreToolUse[] | select(.matcher=="Bash") | .hooks[].command | test("guard-rm\\.py")] | any | if . then "yes" else "no" end' "$J")" "hooks.json: guard-rm.py у PreToolUse Bash"

echo "guard-rm tests: pass=$pass fail=$fail"
[ "$fail" = 0 ]
