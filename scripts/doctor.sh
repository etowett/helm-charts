#!/usr/bin/env bash
#
# Config drift checker. Run by `make doctor` and by CI.
#
# Two kinds of drift rot silently in this repo, and both used to be enforced
# only by a sentence in AGENTS.md:
#
#   1. Tool versions pinned in BOTH the Makefile and .github/workflows/ci.yaml.
#      Bump one, forget the other, and CI stops testing what you develop against.
#   2. Agent configuration mirrored between .claude/ (canonical) and .codex/.
#      A hook registered for one client and not the other silently stops
#      guarding half the sessions.
#
# Exits non-zero on any finding, so CI fails the PR.
set -uo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$0")")" || exit 1

fail=0
note() { printf '  %s\n' "$1"; }
bad() {
  printf '✘ %s\n' "$1"
  fail=1
}
ok() { printf '✔ %s\n' "$1"; }

# ---------------------------------------------------------------- versions ---
# The Makefile and the workflow each pin the same three tools. Read both and
# compare, rather than trusting a comment that says "keep in lockstep".
# Both files are read with awk, not a regex with lazy quantifiers — BSD sed
# (macOS) rejects those, and this script has to run on a maintainer's laptop as
# well as on ubuntu-latest.
mk_var() { awk -v k="$1" '$1 == k && ($2 == "?=" || $2 == "=") { $1=""; $2=""; sub(/^ +/,""); sub(/ *#.*$/,""); print; exit }' Makefile; }
wf_var() { awk -v k="$1:" '$1 == k { v=$2; gsub(/^['"'"'"]|['"'"'"]$/,"",v); print v; exit }' .github/workflows/ci.yaml; }

versions_ok=1
for pair in "HELM_VERSION:HELM_VERSION" "KIND_VERSION:KIND_VERSION" "KUBECONFORM_VERSION:KUBECONFORM_VERSION"; do
  mk_name="${pair%%:*}"
  wf_name="${pair##*:}"
  mk_val="$(mk_var "$mk_name")"
  wf_val="$(wf_var "$wf_name")"
  if [ -z "$mk_val" ] || [ -z "$wf_val" ]; then
    bad "$mk_name: not found in both Makefile ('$mk_val') and ci.yaml ('$wf_val')"
    versions_ok=0
  elif [ "$mk_val" != "$wf_val" ]; then
    bad "$mk_name drifted: Makefile=$mk_val ci.yaml=$wf_val"
    note "Bump both, or the gate you run locally is not the gate CI runs."
    versions_ok=0
  fi
done
[ "$versions_ok" -eq 1 ] && ok "tool versions in lockstep (Makefile ⇄ ci.yaml)"

# Kubernetes validation matrix: Makefile KUBE_VERSIONS vs the ci.yaml matrix.
mk_k8s="$(mk_var KUBE_VERSIONS | tr -s ' ' '\n' | sed '/^$/d' | sort | tr '\n' ' ')"
wf_k8s="$(awk '/^  validate-manifests:/,/^  install-chart:/' .github/workflows/ci.yaml |
  awk '$1 == "-" { v=$2; gsub(/['"'"'"]/,"",v); if (v ~ /^[0-9]+\.[0-9]+\.[0-9]+$/) print v }' |
  sort | tr '\n' ' ')"
if [ "$mk_k8s" = "$wf_k8s" ] && [ -n "$mk_k8s" ]; then
  ok "kubeconform k8s matrix in lockstep ($mk_k8s)"
else
  bad "KUBE_VERSIONS drifted: Makefile='$mk_k8s' ci.yaml validate matrix='$wf_k8s'"
fi

# ------------------------------------------------------------------- links ---
if [ -L CLAUDE.md ] && [ "$(readlink CLAUDE.md)" = "AGENTS.md" ] && [ -f CLAUDE.md ]; then
  ok "CLAUDE.md → AGENTS.md (one brief for every client)"
else
  bad "CLAUDE.md must be a symlink to AGENTS.md (found: $(readlink CLAUDE.md 2>/dev/null || echo 'not a symlink'))"
fi

if [ -L .agents/skills ] && [ -d .agents/skills ]; then
  ok ".agents/skills → $(readlink .agents/skills)"
else
  bad ".agents/skills must be a symlink resolving to .claude/skills"
fi

# ------------------------------------------------------------------- hooks ---
# Every script in .claude/hooks (bar the sourced library) must be registered in
# BOTH clients, and .codex must point at the shared script rather than copy it.
hooks_ok=1
for hook in .claude/hooks/*.sh; do
  name="$(basename "$hook")"
  [ "$name" = "lib.sh" ] && continue
  [ -x "$hook" ] || {
    bad "$hook is not executable"
    hooks_ok=0
  }
  grep -q "$name" .claude/settings.json || {
    bad "$name is not registered in .claude/settings.json"
    hooks_ok=0
  }
  grep -q "$name" .codex/config.toml || {
    bad "$name is not registered in .codex/config.toml"
    hooks_ok=0
  }
done
# ...and nothing may be registered that does not exist.
for name in $(grep -oE '[a-z-]+\.sh' .claude/settings.json | sort -u); do
  [ -f ".claude/hooks/$name" ] || {
    bad ".claude/settings.json registers .claude/hooks/$name, which does not exist"
    hooks_ok=0
  }
done
if [ -d .codex/hooks ]; then
  bad ".codex/hooks/ exists — hook scripts must not be duplicated; .codex/config.toml points at .claude/hooks/"
  hooks_ok=0
fi
[ "$hooks_ok" -eq 1 ] && ok "hooks registered for both clients, scripts shared not copied"

# --------------------------------------------------------------- subagents ---
agents_ok=1
for md in .claude/agents/*.md; do
  [ -e "$md" ] || continue
  name="$(basename "$md" .md)"
  [ -f ".codex/agents/$name.toml" ] || {
    bad "subagent '$name' has no .codex/agents/$name.toml mirror"
    agents_ok=0
  }
done
for toml in .codex/agents/*.toml; do
  [ -e "$toml" ] || continue
  name="$(basename "$toml" .toml)"
  [ -f ".claude/agents/$name.md" ] || {
    bad ".codex/agents/$name.toml has no canonical .claude/agents/$name.md"
    agents_ok=0
  }
done
[ "$agents_ok" -eq 1 ] && ok "subagents mirrored to .codex/agents/"

# ------------------------------------------------------------ absolute paths --
# An absolute path in agent config breaks for every other contributor and in
# every git worktree.
abs="$(grep -rnE '(/Users/|/home/[a-z])' .claude .codex .agents 2>/dev/null |
  grep -v 'settings.local.json' || true)"
if [ -n "$abs" ]; then
  bad "absolute paths in agent config:"
  printf '%s\n' "$abs" | sed 's/^/    /'
else
  ok "no absolute paths in agent config"
fi

# ------------------------------------------------------------------ skills ---
skills_ok=1
for skill in .claude/skills/*/SKILL.md; do
  [ -e "$skill" ] || continue
  head -1 "$skill" | grep -q '^---$' || {
    bad "$skill has no frontmatter"
    skills_ok=0
  }
  grep -q '^description:' "$skill" || {
    bad "$skill has no 'description:' — the model cannot route to it"
    skills_ok=0
  }
  # The description is a standing context cost in every session, for every
  # client sharing .claude/skills. Keep it a routing hint, not documentation.
  len="$(sed -nE 's/^description:[[:space:]]*//p' "$skill" | head -1 | wc -c | tr -d ' ')"
  [ "$len" -gt 400 ] && {
    bad "$skill description is ${len} chars — keep it under ~300, the body is for the how-to"
    skills_ok=0
  }
done
[ "$skills_ok" -eq 1 ] && ok "skills have routable frontmatter"

echo
if [ "$fail" -eq 0 ]; then
  echo "doctor: all checks passed."
else
  echo "doctor: FAILED — fix the ✘ lines above."
fi
exit "$fail"
