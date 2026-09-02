#!/usr/bin/env bash
#
# Tests for the two blocking hooks. Run by `make test-hooks` and by CI.
#
# A guard that silently stops guarding is worse than no guard: the habit of
# trusting it survives, the protection does not. These are the assertions that
# make that impossible — every case that must block, and every case that must
# NOT (the false positives are what get a guard disabled).
#
# Each case builds a throwaway git repo in $TMPDIR, feeds the hook a client
# payload on stdin, and asserts the exit status. Exit 2 = blocked.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/.claude/hooks"
pass=0
fail=0

# The hooks read the checked-out branch from disk, so the cases need a real repo.
setup_repo() {
  local dir
  dir="$(mktemp -d)"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name test
  mkdir -p "$dir/charts/app/templates" "$dir/charts/app/examples"
  echo 'version: "1.0.0"' >"$dir/charts/app/Chart.yaml"
  echo 'replicaCount: 1' >"$dir/charts/app/values.yaml"
  echo '{}' >"$dir/charts/app/values.schema.json"
  echo '# Changelog' >"$dir/charts/app/CHANGELOG.md"
  echo 'kind: Deployment' >"$dir/charts/app/templates/deployment.yaml"
  echo '# readme' >"$dir/charts/app/README.md"
  echo 'a: 1' >"$dir/charts/app/examples/basic.yaml"
  git -C "$dir" add -A
  git -C "$dir" commit -qm init
  printf '%s' "$dir"
}

# run_hook <script> <repo-dir> <command> -> exit status
run_hook() {
  local script="$1" dir="$2" cmd="$3"
  python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "cwd": sys.argv[1], "tool_input": {"command": sys.argv[2]}}))
' "$dir" "$cmd" | (cd "$dir" && "$HOOKS/$script" >/dev/null 2>&1)
  printf '%s' "$?"
}

check() {
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    printf '  ✔ %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '  ✘ %s (want exit %s, got %s)\n' "$label" "$want" "$got"
    fail=$((fail + 1))
  fi
}

# ------------------------------------------------------- guard-main-branch ---
echo "guard-main-branch.sh"
repo="$(setup_repo)"

check "blocks commit on main" 2 \
  "$(run_hook guard-main-branch.sh "$repo" 'git commit -m "wip"')"
check "blocks bare push while on main" 2 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push')"
check "blocks explicit push to main" 2 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push origin main')"
check "blocks push HEAD:main" 2 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push origin HEAD:main')"
check "blocks push --all" 2 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push --all origin')"
check "allows a branch created earlier in the same chain" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'git switch -c feat/x && git commit -m "wip"')"
check "allows pushing a feature branch from main" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push origin feat/x')"
check "allows pushing a tag from main" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push origin refs/tags/app-1.0.0')"
check "allows a branch whose name merely starts with main" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push origin maintenance')"
check "does not fire on a quoted mention of committing to main" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'gh issue create --body "never git commit on main"')"
check "does not fire on a heredoc body mentioning a push to main" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'gh pr create --body-file - <<EOF
git push origin main is forbidden
EOF')"
check "honours the documented escape hatch as a prefix" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'HELM_CHARTS_ALLOW_MAIN_COMMIT=1 git commit -m "wip"')"
check "ignores a non-git command" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'make check')"
check "sees a commit inside a command substitution" 2 \
  "$(run_hook guard-main-branch.sh "$repo" 'echo $(git commit -m wip)')"
check "sees a push inside a subshell" 2 \
  "$(run_hook guard-main-branch.sh "$repo" '(git push origin main)')"

git -C "$repo" switch -qc feat/y
check "allows commit on a feature branch" 0 \
  "$(run_hook guard-main-branch.sh "$repo" 'git commit -m "wip"')"
check "still blocks an explicit push to main from a feature branch" 2 \
  "$(run_hook guard-main-branch.sh "$repo" 'git push origin feat/y:main')"
rm -rf "$repo"

# ---------------------------------------------------- guard-chart-contract ---
echo "guard-chart-contract.sh"
repo="$(setup_repo)"
git -C "$repo" switch -qc feat/chart # the other guard is not under test here

# A template change with neither a version bump nor a changelog entry.
echo 'kind: Deployment # changed' >"$repo/charts/app/templates/deployment.yaml"
git -C "$repo" add charts/app/templates/deployment.yaml
check "blocks a template change with no bump and no changelog" 2 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -m "tweak"')"

# Changelog alone is not enough.
echo '## 1.0.1' >>"$repo/charts/app/CHANGELOG.md"
git -C "$repo" add charts/app/CHANGELOG.md
check "blocks when only the changelog moved" 2 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -m "tweak"')"

# Version bump too — now the contract is satisfied.
echo 'version: "1.0.1"' >"$repo/charts/app/Chart.yaml"
git -C "$repo" add charts/app/Chart.yaml
check "allows once both version and changelog moved" 0 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -m "tweak"')"

# A Chart.yaml edit that does not touch the version line is not a bump.
git -C "$repo" commit -qm "release 1.0.1"
echo 'kind: Deployment # again' >"$repo/charts/app/templates/deployment.yaml"
printf 'version: "1.0.1"\ndescription: new words\n' >"$repo/charts/app/Chart.yaml"
echo '## unreleased' >>"$repo/charts/app/CHANGELOG.md"
git -C "$repo" add -A
check "blocks a Chart.yaml edit that leaves the version line alone" 2 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -m "docs"')"
git -C "$repo" reset -q --hard

# Docs and examples are exempt: they do not ship in the package.
echo '# more readme' >>"$repo/charts/app/README.md"
echo 'b: 2' >>"$repo/charts/app/examples/basic.yaml"
git -C "$repo" add -A
check "allows a README + examples change with no bump" 0 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -m "docs"')"
git -C "$repo" reset -q --hard

# Nothing staged at all, and non-chart files, are not the hook's business.
check "ignores a commit with nothing staged" 0 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -m "empty"')"
echo 'x' >"$repo/Makefile"
git -C "$repo" add Makefile
check "ignores a change outside charts/" 0 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -m "tooling"')"
git -C "$repo" reset -q --hard

# `git commit -a` stages tracked modifications that are not in the index yet.
echo 'replicaCount: 2' >"$repo/charts/app/values.yaml"
check "sees an unstaged values.yaml change behind 'git commit -a'" 2 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -am "bump replicas"')"
check "escape hatch overrides the contract" 0 \
  "$(run_hook guard-chart-contract.sh "$repo" 'HELM_CHARTS_SKIP_CONTRACT=1 git commit -am "bump replicas"')"
check "sees -a hidden in a combined short flag (-va)" 2 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit -va -m "bump replicas"')"
check "does not read --amend as -a" 0 \
  "$(run_hook guard-chart-contract.sh "$repo" 'git commit --amend --no-edit')"
git -C "$repo" reset -q --hard
rm -rf "$repo"

echo
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
