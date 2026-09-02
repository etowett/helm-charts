#!/usr/bin/env bash
#
# SessionStart — a few lines of orientation printed into the agent's context:
# where we are in git, whether the toolchain the gate needs is installed, and
# the one command that is the gate.
#
# Deliberately terse: this is a standing context cost on every session.
set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The tree we are actually in, not the project the client was opened on —
# inside a `git worktree` those differ and the branch below would be wrong.
cd "$(hook_worktree_root)" 2>/dev/null || exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

missing=""
for tool in helm ct kind; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done

printf 'helm-charts · branch %s · %s uncommitted file(s)\n' "$branch" "$dirty"
case "$branch" in
  main | master)
    printf 'On %s — branch before committing; guard-main-branch.sh enforces it.\n' "$branch"
    ;;
esac
[ -n "$missing" ] && printf 'Missing from PATH:%s — parts of the gate will not run (see Makefile).\n' "$missing"
printf 'Gate: make check (lint + render every example) · make validate (kubeconform) · make doctor (config drift).\n'
printf 'Chart contract: templates/values/schema change ⇒ bump Chart.yaml version AND add a CHANGELOG.md entry. Read AGENTS.md.\n'

exit 0
