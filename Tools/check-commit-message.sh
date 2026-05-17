#!/bin/sh
# Validate Conventional Commits subject line (matches .claude/settings.json Bash hook).
set -eu

MSG_FILE="${1:?usage: check-commit-message.sh <commit-msg-file>}"

if [ -n "${GIT_DIR:-}" ] && { [ -f "$GIT_DIR/MERGE_HEAD" ] || [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; }; then
  exit 0
fi

SUBJECT=""
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    \#*) continue ;;
    "") [ -n "$SUBJECT" ] && break; continue ;;
    *)
      SUBJECT="$line"
      break
      ;;
  esac
done < "$MSG_FILE"

if [ -z "$SUBJECT" ]; then
  echo "error: empty commit message" >&2
  exit 1
fi

if printf '%s\n' "$SUBJECT" | grep -qE '^(feat|fix|refactor|test|docs|chore|style|perf)(\([^)]+\))?: .+'; then
  exit 0
fi

cat >&2 <<EOF
error: commit message must follow Conventional Commits:

  <type>(<scope>): <subject>

Valid types: feat, fix, refactor, test, docs, chore, style, perf

Example:
  feat(entry-view): implement double-tap to restore last weight

Your subject:
  $SUBJECT
EOF
exit 1
