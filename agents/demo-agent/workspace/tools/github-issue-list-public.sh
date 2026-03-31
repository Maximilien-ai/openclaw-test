#!/usr/bin/env bash
set -euo pipefail

repo="${1:-openclaw/openclaw}"
count="${2:-5}"
api_url="https://api.github.com/repos/${repo}/issues?state=open&per_page=${count}"

printf '+ %s\n' "curl -fsSL -H 'Accept: application/vnd.github+json' ${api_url}"
curl -fsSL -H 'Accept: application/vnd.github+json' "$api_url" | python3 - "$repo" <<'PY'
import json
import sys

repo = sys.argv[1]
issues = json.load(sys.stdin)
print(f"repo={repo}")
for issue in issues:
    if "pull_request" in issue:
        continue
    number = issue.get("number")
    title = issue.get("title", "").strip()
    state = issue.get("state", "unknown")
    url = issue.get("html_url", "")
    print(f"#{number}\t{state}\t{title}\t{url}")
PY
