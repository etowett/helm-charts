#!/usr/bin/env bash
#
# Stop — advisory reminder of what to run, based on what changed this session.
#
# ADVISORY ONLY: prints and always exits 0, so it can never trap the session in
# a loop. The real gate is `make check` / `make validate` and CI.
set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$(hook_worktree_root)" 2>/dev/null || exit 0

changed="$(git status --porcelain 2>/dev/null | sed 's/^...//')"
[ -n "$changed" ] || exit 0

said=0
if printf '%s\n' "$changed" | grep -qE '^charts/'; then
  echo "charts/ changed — run: make check    (helm lint + render every examples/*.yaml)"
  echo "                and: make validate   (kubeconform against every supported k8s)"
  said=1
fi
if printf '%s\n' "$changed" | grep -qE '^(\.github/workflows/|Makefile$|scripts/|\.claude/|\.codex/|\.agents/)'; then
  echo "tooling changed — run: make doctor    (version lockstep + agent-config drift)"
  said=1
fi
[ "$said" -eq 1 ] && echo "(advisory only — CI runs the same checks)"
exit 0
