#!/usr/bin/env python3
"""PostToolUse hook: after `gh pr create` / `glab mr create`, point Claude at the check-pr skill.

Bash only. When the command creates a PR/MR, prints hookSpecificOutput.additionalContext with the
PR URLs found in the command's stdout (tool_response.stdout), or a note without a URL when stdout
has none. Any other command, or input it cannot parse, prints nothing.

Always exit 0: the tool already ran, this hook only adds context and never blocks.
"""
import json
import re
import sys

CREATE = re.compile(r"\b(gh\s+pr\s+create|glab\s+mr\s+create)\b")
PR_URL = re.compile(r"https?://[^\s'\"<>]+/(?:pull/\d+|-/merge_requests/\d+)")


def stdout_of(response):
    if isinstance(response, dict):
        return str(response.get("stdout") or "")
    return str(response or "")


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if not isinstance(data, dict) or data.get("tool_name") != "Bash":
        return
    command = str((data.get("tool_input") or {}).get("command") or "")
    if not CREATE.search(command):
        return
    urls = list(dict.fromkeys(PR_URL.findall(stdout_of(data.get("tool_response")))))
    if urls:
        what = "PR/MR created: " + ", ".join(urls) + "."
        run = " ".join("/sdlc:check-pr " + u for u in urls)
    else:
        what = "A PR/MR create command ran; its output shows no PR URL."
        run = "/sdlc:check-pr <url>"
    context = (
        what + " In the sdlc plugin every new PR/MR gets all its checks read and fixed until green"
        " with the sdlc:check-pr skill (" + run + "). ship-feature runs it as its step 6;"
        " outside ship-feature it is the next step after creating the PR."
    )
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": context}}))


if __name__ == "__main__":
    main()
