#!/usr/bin/env bash
set -euo pipefail

MSG="$*"
if [ -z "$MSG" ]; then
  echo "Usage: $0 \"message\""
  exit 1
fi

author="$(git config user.name || echo unknown)"
now="$(date --utc +"%Y-%m-%dT%H:%M:%SZ")"

echo "- $now: $MSG (by $author)" >> "$(dirname "$0")/../docs/build-log.md"

echo "Appended to docs/build-log.md"
