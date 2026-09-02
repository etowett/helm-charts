# `.claude/` — agent tooling for this repo

What's available when working on these Helm charts, for humans and agents alike.

- **How to work in this codebase** → the [root `AGENTS.md`](../AGENTS.md).
  `CLAUDE.md` is a symlink to it, so every client reads the same brief.
- **The Codex CLI mirror** → [`.codex/`](../.codex/AGENTS.md).
- **What's shared across clients** → [`.agents/`](../.agents/AGENTS.md).

`.claude/` is the **source of truth**; `.codex/` is derived from it, and
`make doctor` fails the build when the two drift.

## Skills (`skills/<name>/SKILL.md`)

Auto-activate on a matching request, or invoke explicitly with `/<name>`. Shared
with Codex through the `.agents/skills` symlink — no sync step.

| Skill | Use it to… |
|---|---|
| `chart-change` | change a chart end to end: values, schema, template, example, README, version, changelog |
| `release-chart` | release a chart — what chart-releaser does on merge, and what you must get right in the PR |

Built-in skills also apply: `/code-review`, `/simplify`, `/pr`, `/security-review`.

## Subagents (`agents/<name>.md`)

Delegated through the Agent/Task tool ("use the chart-reviewer on my changes").
Runs in its own context, so a full review pass stays out of the main
conversation. Read-only. Mirrored to `.codex/agents/*.toml`.

| Subagent | Model | Answers |
|---|---|---|
| `chart-reviewer` | opus | is this chart change up to the repo's contract? (run before opening a PR) |

## Hooks (`hooks/*.sh`)

Registered in `settings.json` and mirrored into `.codex/config.toml`. **The
scripts themselves are never duplicated** — `.codex/config.toml` points straight
at `.claude/hooks/*.sh`, which read their payload from stdin and work under
either client. Tested by `scripts/test-hooks.sh`, which CI runs.

| Hook | Event | What it does |
|---|---|---|
| `session-start.sh` | SessionStart | branch, dirty count, missing tools, the gate, the chart contract |
| `guard-main-branch.sh` | PreToolUse (Bash) | **blocks** `git commit` on `main` and any `git push` whose refspec targets it. Follows a leading `cd` and `git -C` so the branch is read from the tree the command actually runs in; judges a push by its refspec, so feature-branch and tag pushes go through from anywhere. Only text a shell would execute is walked — a PR body that discusses committing to main is data, not a violation. Escape hatch: `HELM_CHARTS_ALLOW_MAIN_COMMIT=1` |
| `guard-chart-contract.sh` | PreToolUse (Bash) | **blocks** a commit that changes a chart's `templates/`, `values.yaml`, `values.schema.json` or `Chart.yaml` without both a version bump and a `CHANGELOG.md` entry. Reads what is actually staged, so `git commit -a` and `--amend` are seen correctly. README- and examples-only changes are exempt. Escape hatch: `HELM_CHARTS_SKIP_CONTRACT=1` |
| `ensure-newline.sh` | PostToolUse (Edit/Write) | appends a missing trailing newline |
| `lint-on-stop.sh` | Stop | advisory: names the gate for whatever changed this session |
| `lib.sh` | — | shared payload parsing, root detection, and `hook_command_skeleton` (strips heredoc bodies and quoted spans so only executable text is judged) |

Only the two `guard-*` hooks can block. Everything else always exits 0, so a
hook can never trap a session in a loop.

> **Why `guard-chart-contract.sh` exists.** `ct lint --check-version-increment`
> already enforces half of this rule — but in CI, minutes later, after the PR is
> open. The hook is the same rule four seconds earlier, and it also checks the
> changelog half that CI cannot see. When it fires, it is telling you the
> contract is incomplete, not that it is broken.

## Settings

- **`settings.json`** — committed and shared: hook registrations plus `ask` and
  `deny`. It deliberately carries **no `permissions.allow`**.
- **`settings.local.json`** — personal, **gitignored**. This is where the
  command allow-list lives. `cp .claude/settings.local.json.example
  .claude/settings.local.json` to opt in.

> **What earns a place in `ask`.** An `ask` entry beats auto mode *and* a local
> `allow`, so it fires on every matching command in every session. It has to pay
> for that. The test: **does the command destroy work, or reach the outside
> world, in a way no hook already catches?**
>
> `git commit` and `git push` fail that test — `guard-main-branch.sh` doesn't
> prompt on `main`, it *denies*. A prompt on top could only ever fire on the
> feature-branch commits that were never in scope, and a guard that interrupts
> routine work gets clicked through until it protects nothing. What stays is
> what the hooks have nothing to say about: `git reset --hard` and `git clean`
> throw away uncommitted work; `helm install/upgrade/uninstall`, `kubectl
> apply/delete` and `kind delete` mutate a real cluster; `gh pr merge` is the
> action that actually lands on `main`; `gh release create` and `gh workflow
> run` publish.

> **Why the allow-list is not committed.** An entry like `Bash(make:*)`
> auto-approves, with no prompt, a command whose behaviour is defined by files
> *in the working tree* — the `Makefile` and `scripts/`. Checking out someone
> else's branch to review it and then opening an agent session would hand that
> branch code execution on your machine, silently. Keeping the allow-list local
> makes each maintainer opt in deliberately. **When reviewing a branch you did
> not write**, work without it, or read the diff to `Makefile` and `scripts/`
> before running anything.

## Adding to this setup

- **A new skill** → `skills/<name>/SKILL.md` with `name` and `description`
  frontmatter. Keep the description under ~300 characters: it is a *routing
  hint* loaded into every session for every client, not documentation. The
  how-to goes in the body. `make doctor` fails on a missing or oversized one.
- **A new subagent** → `agents/<name>.md`, narrowest `tools` list that works,
  repo-relative paths only, and a matching `.codex/agents/<name>.toml`.
- **A new hook** → a script here, registered in `settings.json` **and**
  `.codex/config.toml` (pointing at this directory, never a copy), with a case
  added to `scripts/test-hooks.sh`. Read the payload from stdin and exit 0 by
  default — only a deliberate policy violation may exit 2.

Then run `make doctor`. CI runs it too, so a stale mirror fails the PR.
