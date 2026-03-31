#!/usr/bin/env bash
set -euo pipefail

repo="${1:?usage: github-issue-create.sh OWNER/REPO TITLE BODY}"
title="${2:?usage: github-issue-create.sh OWNER/REPO TITLE BODY}"
body="${3:?usage: github-issue-create.sh OWNER/REPO TITLE BODY}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed in this environment." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh auth is not configured. Run: gh auth login -h github.com" >&2
  exit 1
fi

printf '+'
printf ' %q' gh issue create --repo "$repo" --title "$title" --body "$body"
printf '\n'
gh issue create --repo "$repo" --title "$title" --body "$body"
