#!/usr/bin/env bash
#
# PreToolUse(Bash) guard — the chart contract, enforced at commit time.
#
# AGENTS.md states it and CI enforces it with `ct lint --check-version-increment`,
# but CI is minutes away and the failure arrives after the PR is already open.
# This is the same rule, four seconds earlier: a commit that changes a chart's
# rendered output must also bump `Chart.yaml` version and record the change in
# that chart's CHANGELOG.md.
#
# What counts as "changes rendered output": templates/, values.yaml,
# values.schema.json, Chart.yaml (anything but the version line), .helmignore.
# README and examples edits alone do not — examples are CI-validated but do not
# ship in the package, and a docs-only fix should not force a release.
#
# Judged against what is actually STAGED, read from git, not from the command
# text — so `git commit -a`, `git commit --amend` and a pre-staged index are all
# seen correctly. Only text a shell would execute is inspected, so a PR body
# that discusses committing is data, not a violation.
#
# Escape hatch: HELM_CHARTS_SKIP_CONTRACT=1, exported or as a command prefix.
set -uo pipefail
set -f

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ "${HELM_CHARTS_SKIP_CONTRACT:-0}" = "1" ] && exit 0
[ -t 0 ] && exit 0

input="$(cat)"
cmd="$(hook_json_field "$input" '.tool_input.command')"
[ -n "$cmd" ] || exit 0

hook_cwd="$(hook_json_field "$input" '.cwd')"
current_dir="${hook_cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}"

resolve_dir() {
  # shellcheck disable=SC2088 # these are match patterns for literal input,
  # not a tilde we expect the shell to expand — $HOME is substituted by hand.
  case "$1" in
    /*) printf '%s' "$1" ;;
    "~") printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *) printf '%s/%s' "$current_dir" "$1" ;;
  esac
}

# --- find a `git commit` in the command, and the tree it runs in -------------

commit_dir=""
amend=0
stage_all=0
segments="$(hook_command_segments "$cmd")"

while IFS= read -r seg; do
  seg="${seg#"${seg%%[![:space:]]*}"}"
  [ -z "$seg" ] && continue
  # shellcheck disable=SC2086
  set -- $seg
  [ $# -eq 0 ] && continue

  while [ $# -gt 0 ]; do
    case "$1" in
      HELM_CHARTS_SKIP_CONTRACT=1) exit 0 ;;
      [A-Za-z_]*=*) shift ;;
      sudo | command | env | time | nohup) shift ;;
      *) break ;;
    esac
  done
  [ $# -eq 0 ] && continue

  if [ "$1" = "cd" ]; then
    # Only follow a `cd` that would succeed; otherwise the shell stays put and
    # so must we. Believing an unusable directory makes every git read below
    # fail, and the hook then exits 0 — failing open.
    if [ -n "${2:-}" ] && [ "$2" != "-" ]; then
      candidate="$(resolve_dir "$2")"
      [ -d "$candidate" ] && current_dir="$candidate"
    fi
    continue
  fi

  [ "$1" = "git" ] || continue
  shift

  target_dir="$current_dir"
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        shift
        [ $# -gt 0 ] && {
          candidate="$(resolve_dir "$1")"
          [ -d "$candidate" ] && target_dir="$candidate"
          shift
        }
        ;;
      -c | --git-dir | --work-tree | --namespace | --exec-path)
        shift
        [ $# -gt 0 ] && shift
        ;;
      --*=* | -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || continue
  [ "$1" = "commit" ] || continue
  shift

  commit_dir="$target_dir"
  for tok in "$@"; do
    case "$tok" in
      --amend) amend=1 ;;
      --all) stage_all=1 ;;
      --) break ;;
      --*) ;;
      # -a hides inside combined short flags: -am, -va, -sam. Long options are
      # excluded above so `--amend` is not read as one of them.
      -*a*) stage_all=1 ;;
    esac
  done
done <<EOF
$segments
EOF

[ -n "$commit_dir" ] || exit 0
git -C "$commit_dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0

# --- what does this commit actually change? ----------------------------------

# `--amend` re-writes the previous commit, so its files are in scope too.
# `-a`/`-am` stages every tracked modification, so compare against the worktree.
diff_base="--cached"
[ "$amend" -eq 1 ] && diff_base="--cached HEAD~1"
changed="$(
  {
    # shellcheck disable=SC2086
    git -C "$commit_dir" diff --name-only $diff_base 2>/dev/null
    [ "$stage_all" -eq 1 ] && git -C "$commit_dir" diff --name-only HEAD 2>/dev/null
  } | sort -u
)"
[ -n "$changed" ] || exit 0

# Charts whose PACKAGED content changed.
#
# An allowlist of known paths (templates/, values.yaml, …) misses whatever the
# next chart adds — `crds/`, a vendored subchart under `charts/`, a `files/`
# directory read by `.Files`. So this is an EXEMPTION list instead: everything
# inside a chart ships unless it is named here.
#
#   README.md    documentation; not worth a release on its own
#   CHANGELOG.md packaged, but requiring a bump for touching it is circular
#   examples/    CI-validated, but excluded from the package by .helmignore
packaging_changed="$(
  printf '%s\n' "$changed" |
    grep -E '^charts/[^/]+/' |
    grep -vE '^charts/[^/]+/(README\.md|CHANGELOG\.md|examples/)' |
    sed -E 's#^charts/([^/]+)/.*#\1#' | sort -u
)"
[ -n "$packaging_changed" ] || exit 0

# chart_version <ref-or-index> <chart> — the TOP-LEVEL `version:` from a
# Chart.yaml, or nothing. Anchored to column 0 so a nested `version:` (under
# `annotations:`, or inside a dependency entry) cannot masquerade as the chart
# version, which a `git diff | grep '^+.*version:'` happily would.
chart_version() {
  local spec="$1" chart="$2"
  if [ "$spec" = ":" ]; then
    git -C "$commit_dir" show ":charts/$chart/Chart.yaml" 2>/dev/null
  elif [ "$spec" = "worktree" ]; then
    cat "$commit_dir/charts/$chart/Chart.yaml" 2>/dev/null
  else
    git -C "$commit_dir" show "$spec:charts/$chart/Chart.yaml" 2>/dev/null
  fi | sed -nE 's/^version:[[:space:]]*"?([^"[:space:]]+)"?[[:space:]]*$/\1/p' | head -1
}

# The commit this one is measured against: its parent for an --amend, HEAD
# otherwise. The new content is the index, or the worktree under `commit -a`.
base_ref="HEAD"
[ "$amend" -eq 1 ] && base_ref="HEAD~1"
new_spec=":"
[ "$stage_all" -eq 1 ] && new_spec="worktree"

violations=()
for chart in $packaging_changed; do
  old_version="$(chart_version "$base_ref" "$chart")"
  new_version="$(chart_version "$new_spec" "$chart")"

  missing=""
  if [ -z "$new_version" ]; then
    # Unreadable Chart.yaml — a brand-new chart, or a parse failure. Say so
    # rather than passing silently.
    missing="a readable top-level version: in Chart.yaml"
  elif [ -n "$old_version" ] && [ "$old_version" = "$new_version" ]; then
    missing="a Chart.yaml version bump (still $old_version)"
  elif [ -n "$old_version" ] &&
    [ "$(printf '%s\n%s\n' "$old_version" "$new_version" | sort -V | head -1)" != "$old_version" ]; then
    # A version that moves DOWN is not a bump. `ct lint --check-version-increment`
    # rejects it in CI; catching it here saves the round trip, and a decrement is
    # almost always a bad merge resolution rather than an intent.
    missing="an INCREASING Chart.yaml version ($old_version -> $new_version goes backwards)"
  fi

  # The changelog must mention the version actually being released — not merely
  # have been touched, which any unrelated edit satisfies.
  if [ -n "$new_version" ]; then
    changelog="$(
      if [ "$stage_all" -eq 1 ]; then
        cat "$commit_dir/charts/$chart/CHANGELOG.md" 2>/dev/null
      else
        git -C "$commit_dir" show ":charts/$chart/CHANGELOG.md" 2>/dev/null
      fi
    )"
    printf '%s' "$changelog" | grep -qF "$new_version" ||
      missing="${missing:+$missing and }a CHANGELOG.md entry for $new_version"
  fi

  [ -n "$missing" ] && violations+=("$chart: needs $missing")
done

[ "${#violations[@]}" -eq 0 ] && exit 0

details=()
for v in "${violations[@]}"; do details+=("• $v"); done
details+=(
  ""
  "The chart contract (AGENTS.md → The one rule): everything inside a chart"
  "ships in the package, so a change to it needs a bumped top-level version in"
  "Chart.yaml AND a CHANGELOG.md entry naming that exact version. CI enforces"
  "the version half via 'ct lint --check-version-increment' — this catches"
  "both, now, and reads the real version rather than any line saying 'version:'."
  ""
  "Exempt, and never reaching this hook: README.md, CHANGELOG.md, examples/."
  "Override a genuine exception with HELM_CHARTS_SKIP_CONTRACT=1."
)
hook_deny "chart change without a version bump and changelog entry." "${details[@]}"
