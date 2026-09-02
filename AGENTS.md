# AGENTS.md

The brief for anyone working in this repository — agents and humans alike.
`CLAUDE.md` is a symlink to this file, so every client reads it.

## What this repo is

A collection of personal Helm charts, published to
`https://etowett.github.io/helm-charts`.

- **`charts/app`** — a flexible application chart: Deployment, Service, Ingress,
  HPA, PDB, PVC, hooks, init containers, sidecars, and optional Celery
  worker/beat/flower components.
- **`charts/cron`** — scheduled jobs. One release defines many CronJobs from a
  `cronjobs` map: top-level keys are shared defaults and each entry deep-merges
  its own overrides on top. Sidecars render as **native sidecars** (init
  containers with `restartPolicy: Always`) — the only pattern that lets a Job
  with a helper container ever complete.

Charts are the product. Everything else in the repo exists to keep them correct.

## The one rule

**A change that ships inside the package needs a version bump and a changelog
entry.** That means `templates/`, `values.yaml`, `values.schema.json`,
`Chart.yaml`. Users install by version; a changed chart at an unchanged version
is a lie about what they are getting.

`README.md` and `examples/` are exempt — CI validates them, but they do not ship.

This is enforced three times over, deliberately, at increasing distance:
`.claude/hooks/guard-chart-contract.sh` refuses the commit, the PR template asks
for it, and `ct lint --check-version-increment` fails the build.

## Layout

```
charts/                          Helm charts (each self-contained)
  app/
  cron/
    Chart.yaml                   version, kubeVersion, maintainers
    values.yaml                  documented with @param comments
    values.schema.json           part of the contract — must match values.yaml
    templates/                   Helm templates
    examples/                    concrete values files, all CI-validated
    README.md                    parameter table and usage
    CHANGELOG.md                 per-chart, Keep a Changelog
.github/
  workflows/ci.yaml              meta lint, ct lint, kubeconform, kind install
  workflows/release.yml          chart-releaser on merge to main
  ct.yaml                        chart-testing configuration
  dependabot.yml                 weekly grouped action-pin updates
scripts/
  doctor.sh                      config drift checker (make doctor)
  test-hooks.sh                  tests for the blocking hooks
.claude/                         agent config — CANONICAL (see .claude/README.md)
.codex/                          Codex CLI mirror of .claude/
.agents/                         cross-client shared bits (skills symlink)
Makefile                         the local gate (`make help`)
AGENTS.md                        this file · CLAUDE.md is a symlink to it
```

## The gate

```sh
make check       # helm lint + render every chart with every examples/*.yaml
make validate    # kubeconform -strict against every supported k8s version
make doctor      # tool-version lockstep and agent-config mirrors
make test-hooks  # only if you touched .claude/hooks/
```

`make check` is the fast pre-push gate. Run `make validate` before opening the
PR. CI runs all four plus a real `kind` install on three Kubernetes versions.

Nothing here needs a cluster except `make ct-install`, which needs
`make kind-up` first.

## Conventions

- **Bump the chart version** in `Chart.yaml` for any packaged change, and match
  the bump to the blast radius: a removed or renamed values key, a changed
  default that alters a running workload, or a raised `kubeVersion` floor is a
  **major**, however small the diff.
- **Update that chart's `CHANGELOG.md`.** Keep a Changelog format. Lead with a
  "Changed (breaking)" section when users must edit their values.
- **`values.schema.json` is part of the contract**, not documentation. A key
  `values.yaml` allows but the schema omits breaks `helm install --validate` for
  users. `charts/cron` sets top-level `additionalProperties: false` so a gap
  fails immediately; `charts/app` does not, so a gap there fails silently in
  someone else's cluster.
- **`@param` doc comments in `values.yaml`** are the source of truth for
  user-visible parameters. Mirror them in the chart README's parameter table.
- **Examples are the regression tests.** Every new capability gets at least one
  `examples/<scenario>.yaml`; CI renders and kubeconform-validates each one
  against every supported Kubernetes version.
- **`kubeVersion`** is a promise Helm enforces at install time. Don't widen the
  floor speculatively, and don't raise it without a chart major.
- **Tool versions are pinned twice**, in `Makefile` and
  `.github/workflows/ci.yaml`. `make doctor` fails when they disagree — bump
  both in one commit.

## Pitfalls

- **Don't use `kubeval`** — unmaintained since 2020 and unaware of recent
  Kubernetes APIs. CI and the Makefile use `kubeconform`.
- **Don't pin bare-minor `kindest/node:vX.Y` tags.** kind ships specific patch
  tags only, and the node images are digest-pinned to the set built for the
  pinned kind release. Take both tag and digest from that kind release's notes.
- **Don't pass `command:` / `config:` to `helm/chart-testing-action`** — those
  inputs were removed. Run `ct lint` / `ct install` as `run:` steps.
- **Don't edit `_helpers.tpl` and only render the scenario you were working on.**
  It is shared by every template in the chart; `make check` is what catches the
  rest.
- **Don't add a plain sidecar to a Job or CronJob.** The Job will never
  complete. Native sidecars only.
- **Don't hand-create a `<chart>-<version>` tag or GitHub release.**
  chart-releaser owns both, and a hand-made tag makes it skip that chart
  permanently.
- **Don't add features beyond the task.** A bug fix doesn't need surrounding
  cleanup; a one-shot operation doesn't need a helper.

## Tool versions

Pinned in `.github/workflows/ci.yaml` (env block) and `Makefile` (variables at
the top). `make doctor` enforces the lockstep, so this table is documentation,
not the source of truth.

| Tool | Version | Why this one |
|---|---|---|
| Helm | v4.2.4 | current stable; chart `apiVersion: v2` is still supported |
| kind | v0.33.0 | latest; node images up to k8s 1.37 |
| kubeconform | v0.8.0 | latest; schemas cover k8s 1.37 |
| chart-testing | 3.14.0 | via `helm/chart-testing-action` |

Kubernetes: kubeconform validates against **1.34 – 1.37**; `kind` installs on
**1.35, 1.36, 1.37**. Both charts declare `kubeVersion: ">=1.29.0-0"` — the
floor is 1.29 because native sidecars stabilised there.

## Working with agents

Read [`.claude/README.md`](.claude/README.md) for the full setup: skills,
the `chart-reviewer` subagent, the hooks, and why the command allow-list is not
committed. In short:

- **Two hooks can block you.** `guard-main-branch.sh` refuses a commit on `main`
  or a push to it — branch first. `guard-chart-contract.sh` refuses a chart
  change without a version bump *and* a changelog entry. Both have documented
  escape hatches; if you reach for one, say why in the PR.
- **`/chart-change`** walks the six coupled files a chart edit touches.
- **`/release-chart`** covers what merging actually publishes.
- **Run `chart-reviewer` on the diff before opening the PR.**
- Both guards are covered by `scripts/test-hooks.sh`, which CI runs — if you
  change a guard, add the case that proves the new behaviour.

## When adding a new chart

1. `cp -r charts/app charts/<new>` and rename inside `Chart.yaml`.
2. Reset `CHANGELOG.md`, clear `examples/`, rewrite `README.md`.
3. `make lint template` to confirm it renders.
4. Add at least one `examples/*.yaml`.
5. Update the chart table in the root `README.md`.

## Where to learn the domain

- Chart docs: [`charts/app/README.md`](charts/app/README.md) ·
  [`charts/cron/README.md`](charts/cron/README.md)
- Changelogs: [`charts/app/CHANGELOG.md`](charts/app/CHANGELOG.md) ·
  [`charts/cron/CHANGELOG.md`](charts/cron/CHANGELOG.md)
- CronJob concepts: https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
- Helm chart best practices: https://helm.sh/docs/chart_best_practices/
- chart-testing: https://github.com/helm/chart-testing
- kubeconform: https://github.com/yannh/kubeconform
