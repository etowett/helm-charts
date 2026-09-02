# `.agents/` — shared across agent clients

A small directory for things more than one agent client needs to reach. It holds
no configuration of its own.

## What's here

- **`skills`** — a tracked symlink to `../.claude/skills`. Codex, and any other
  client that scans a skills directory, reads this repo's skills through it, so
  a skill added under `.claude/skills/` is immediately available everywhere with
  no sync step.

That's the whole directory. Client-specific configuration lives with its client:

| Client | Configuration |
|---|---|
| Claude Code | [`.claude/`](../.claude/README.md) — **canonical** |
| Codex CLI | [`.codex/`](../.codex/AGENTS.md) — mirrors `.claude/` |
| any client | [`AGENTS.md`](../AGENTS.md) at the repo root — the brief itself |

## Adding another client

1. Give it its own top-level directory (`.cursor/`, `.antigravity/`, …).
2. Point its skills at `.agents/skills` if it supports a skills directory.
3. Mirror `.claude/settings.json` into whatever format it wants — never the
   other way round; `.claude/` stays canonical.
4. Teach `scripts/doctor.sh` to check the new mirror, so it cannot silently rot.
   `.codex/` is a worked example.
