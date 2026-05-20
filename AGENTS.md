# AGENTS.md

Operational guide for AI agents working in this repository. Conventions below apply to humans too.

## What this repo is

A small collection of personal Helm charts. Today the only chart is `charts/app` — a flexible application chart with optional Celery worker/beat/flower components, hooks, init containers, sidecars, HPA, PDB, and ingress.

## Layout

```
charts/                          Helm charts (each is self-contained)
  app/
    Chart.yaml                   Version, kubeVersion, maintainers
    values.yaml                  Documented with @param doc comments
    values.schema.json           Must stay in sync with values.yaml
    templates/                   Helm templates
    examples/                    Concrete values files (CI-validated)
    README.md                    Chart-level documentation
    CHANGELOG.md                 Per-chart changelog (Keep a Changelog)
.github/
  workflows/ci.yaml              CI: lint, render, kubeconform, kind install
  ct.yaml                        chart-testing configuration
Makefile                         Local dev shortcuts (`make help`)
AGENTS.md                        This file
README.md                        Repo overview
```

## Run before opening a PR

```sh
make lint              # helm lint every chart
make template-examples # render every chart with each examples/*.yaml
make ct-lint           # chart-testing lint (matches CI)
make validate          # kubeconform validate against k8s 1.33–1.36
```

`make check` is a shortcut for `lint + template-examples` and is the fastest pre-push gate.

CI runs the same checks plus a real `kind` install on k8s 1.33, 1.34, and 1.35.

## Conventions

- **Bump the chart version** in `Chart.yaml` for any chart change. CI enforces this via `check-version-increment: true` in `.github/ct.yaml`.
- **Update `CHANGELOG.md`** for the affected chart. Keep a Changelog format. Lead with a "Changed (breaking)" section if the change requires user action.
- **`values.schema.json` is part of the contract.** New value keys → new schema entries. A key allowed by `values.yaml` but absent from the schema breaks `helm install` with `--validate`.
- **`@param` doc comments in `values.yaml`** are the source of truth for user-visible parameters. Mirror them in the chart README's parameter table.
- **Examples are CI-validated.** Every new feature gets at least one `examples/<scenario>.yaml`; CI renders and kubeconform-validates each one.
- **`kubeVersion`** in `Chart.yaml` should match what CI exercises. Don't widen the floor speculatively — Helm enforces this at install time.

## Pitfalls to avoid

- **Don't use `kubeval`** — unmaintained since 2020 and unaware of recent Kubernetes APIs. CI and the Makefile use `kubeconform` instead.
- **Don't pin bare-minor `kindest/node:vX.Y` tags.** Kind only ships specific patch tags (e.g. `v1.35.0`, not `v1.35`). The current set lives in `.github/workflows/ci.yaml` and `Makefile`.
- **Don't pass `command:` / `config:` to `helm/chart-testing-action@v2.7.0`** — those inputs were removed. Run `ct lint` / `ct install` as `run` steps.
- **Don't add templates without rendering all examples.** A change in `_helpers.tpl` can silently break unrelated scenarios.
- **Don't reach for sub-minute polling loops** when CI exposes an `outputs` field or a `needs:` dependency; use the dependency graph.
- **Don't add features beyond the task.** Bug fixes don't need surrounding cleanup; one-shot operations don't need helpers.

## Tool versions

Tool versions are pinned both in `.github/workflows/ci.yaml` (env vars at the top) and in `Makefile` (variables at the top). Keep them in lockstep when bumping.

| Tool         | Version (current) | Why pinned                           |
|--------------|-------------------|--------------------------------------|
| Helm         | v3.16.4           | Matches CI; covers all current APIs  |
| kind         | v0.31.0           | Latest with node images up to 1.35   |
| kubeconform  | v0.7.0            | Latest; schemas cover k8s 1.36       |
| chart-testing| latest (action)   | Pinned via `helm/chart-testing-action` tag |

## When adding a new chart

1. `cp -r charts/app charts/<new>` and rename inside `Chart.yaml`.
2. Reset `CHANGELOG.md`, clear `examples/`, rewrite `README.md`.
3. Run `make lint template` to confirm it renders.
4. Add at least one entry to `examples/`.
5. Update the chart list in the repo root `README.md`.

## CI details

- Triggers on PRs touching `charts/**`, the workflow itself, or `.github/ct.yaml`.
- Three jobs:
  - `lint-chart` — `ct lint` + render defaults + render every example.
  - `validate-manifests` — `kubeconform -strict` against k8s 1.33, 1.34, 1.35, 1.36.
  - `install-chart` — real `kind` cluster install on k8s 1.33, 1.34, 1.35. Gated on `lint-chart.outputs.changed` so unrelated workflow edits don't spin up clusters.
- Tool versions are env vars at the top of the workflow.
- Concurrency cancels duplicate runs on the same PR.

## Where to learn the domain

- Chart-specific docs: [`charts/app/README.md`](charts/app/README.md)
- Per-chart changelog: [`charts/app/CHANGELOG.md`](charts/app/CHANGELOG.md)
- Helm chart best practices: https://helm.sh/docs/chart_best_practices/
- chart-testing: https://github.com/helm/chart-testing
- kubeconform: https://github.com/yannh/kubeconform
