# `.codex/` — Codex CLI configuration

This directory makes the Codex CLI a first-class client here: the same command
permissions, the same hooks, and the same subagents as Claude Code.

**Claude Code is the source of truth.** `.claude/` is canonical; everything here
is derived from it. Read [`.claude/README.md`](../.claude/README.md) for what
the tooling does, and the [root `AGENTS.md`](../AGENTS.md) for how to actually
work in this repo.

## Getting started

Project-scoped config only loads once you trust the project, so the first run
needs a one-time acknowledgement:

```bash
cd /path/to/helm-charts
codex           # accept the trust prompt
codex doctor    # shows the resolved config
```

If Codex isn't picking anything up, the trust prompt is almost always why.

## What's here

| File | What it does |
|---|---|
| `config.toml` | sandbox + approval policy, and the `[hooks]` table (mirrors `.claude/settings.json`) |
| `rules/allowlist.rules` | command permissions, mirroring `.claude/settings.json` |
| `agents/*.toml` | subagents, mirroring `.claude/agents/*.md` |

Everything else Codex writes into `.codex/` is local session state and is
gitignored.

## What mirrors what

| Canonical | Mirror here | Checked by |
|---|---|---|
| `.claude/settings.json` (`hooks`) | `config.toml` (`[hooks]`) | `make doctor` |
| `.claude/settings.json` (`permissions`) | `rules/allowlist.rules` | by hand |
| `.claude/agents/*.md` | `agents/*.toml` | `make doctor` |
| `.claude/skills/` | `.agents/skills` symlink | automatic — nothing to do |

Run `make doctor` after changing anything on the left. CI runs it too, so a
stale mirror fails the PR.

## Codex-specific notes

**Hook scripts are not duplicated.** `[hooks]` points at `.claude/hooks/*.sh`
through a `bash -c 'exec "$(git rev-parse --show-toplevel)/…"'` wrapper. Codex
hook commands are plain shell strings with no project-directory variable, and an
absolute path here would break for every other contributor and in every git
worktree — hence the wrapper. `make doctor` fails on both a duplicated script
(`.codex/hooks/`) and an absolute path.

**Permission decisions don't use Claude's vocabulary.** Codex rules take
`allow`, `prompt` and `forbidden`, which map onto Claude's `allow`, `ask` and
`deny`. When several rules match, the most restrictive wins
(`forbidden` > `prompt` > `allow`), so `rules/allowlist.rules` allows a binary
broadly and then narrows it with `prompt` rules for the destructive subcommands
— which is why it does not read as a line-for-line copy of `settings.json`.

**Compound commands need no special handling.** Codex splits on `&&`, `||`, `;`
and `|` itself and evaluates each segment against the rules.

**`pattern` is an exact prefix over the argument list**, and any element may be
a union of literals — `pattern=["helm", ["lint", "template"]]` matches
`helm lint` and `helm template`.
