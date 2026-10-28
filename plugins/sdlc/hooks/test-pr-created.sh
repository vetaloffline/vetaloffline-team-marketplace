#!/usr/bin/env bash
# Tests for pr-created.py: "none" — no output; otherwise the additionalContext text it printed.
# At the end — whether the hook is wired in the plugin's hooks.json.
# Run: bash plugins/sdlc/hooks/test-pr-created.sh
# Needs: python3, jq.
D="$(cd "$(dirname "$0")" && pwd)"
H="$D/pr-created.py"
pass=0; fail=0
run() {  # $1 = stdin JSON → "none" | additionalContext | "rc=N:<output>"
  local out rc
  out=$(printf '%s' "$1" | python3 "$H" 2>&1); rc=$?
  if [ "$rc" != 0 ]; then echo "rc=$rc:$out"
  elif [ -z "$out" ]; then echo none
  else printf '%s' "$out" | jq -r 'select(.hookSpecificOutput.hookEventName == "PostToolUse") | .hookSpecificOutput.additionalContext'; fi
}
check() {  # $1 = expected substring ("none" = no output), $2 = got, $3 = description
  if { [ "$1" = none ] && [ "$2" = none ]; } || { [ "$1" != none ] && [[ "$2" == *"$1"* ]]; }; then
    pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL exp=$1 got=$2 :: $3"; fi
}
t() {  # $1 = expected, $2 = command, $3 = stdout, $4 = tool name (Bash by default)
  check "$1" "$(run "$(jq -n --arg c "$2" --arg o "$3" --arg n "${4:-Bash}" \
    '{tool_name:$n,tool_input:{command:$c},tool_response:{stdout:$o,stderr:"",interrupted:false,isImage:false}}')")" "$2"
}

GH=https://github.com/acme/api/pull/12
GL=https://gitlab.com/acme/app/-/merge_requests/3

# === PR/MR created → note with the URL
t "PR/MR created: $GH." 'gh pr create --title "feat: x" --body-file pr.md' "$GH"
t "/sdlc:check-pr $GH" 'gh pr create --fill' "$GH"
t "PR/MR created: $GL." 'glab mr create --title "feat: x" --description-file pr.md' "Creating merge request
$GL"
t "PR/MR created: $GL." 'cd app && glab mr create --fill --yes' "$GL"
t "PR/MR created: $GH." 'GH_TOKEN=$(gh auth token --user x) gh pr create --fill' "$GH
$GH"
t "$GH, $GL" 'gh pr create --fill && (cd app && glab mr create --fill)' "$GH $GL"

# === create command without a URL in stdout → note without a URL
t "shows no PR URL" 'gh pr create --web' ""
t "/sdlc:check-pr <url>" 'glab mr create --fill' "error: no commits"

# === anything else → nothing
t none 'gh pr view 12' "$GH"
t none 'gh pr checks 12' "$GH"
t none 'glab mr view 3' "$GL"
t none 'git push -u origin feat/x' "$GH"
t none 'echo gh pr creates' ""
t none 'gh pr create --fill' "$GH" Write
check none "$(run 'not json')" "invalid JSON"
check none "$(run '[]')" "JSON array"
check none "$(run '{"tool_name":"Bash"}')" "no tool_input"
check "$GH" "$(run "$(jq -n --arg c 'gh pr create --fill' --arg o "$GH" '{tool_name:"Bash",tool_input:{command:$c},tool_response:$o}')")" "tool_response as a string"

# === wiring in the plugin's hooks.json
J="$D/hooks.json"
check yes "$(jq -r '[.hooks.PostToolUse[] | select(.matcher=="Bash") | .hooks[].command | test("pr-created\\.py")] | any | if . then "yes" else "no" end' "$J")" "hooks.json: pr-created.py in PostToolUse Bash"

echo "pr-created tests: pass=$pass fail=$fail"
[ "$fail" = 0 ]
