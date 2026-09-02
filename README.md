# Helm Charts

[![CI](https://github.com/etowett/helm-charts/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/etowett/helm-charts/actions/workflows/ci.yaml)

Personal collection of Helm charts. Each chart lives under `charts/` and ships with its own README, schema-validated `values.yaml`, ready-to-use examples, and CHANGELOG.

## Charts

| Chart | Description | Docs |
|-------|-------------|------|
| [`app`](charts/app) | Flexible application chart with optional Celery (worker/beat/flower), hooks, init containers, sidecars, HPA, PDB, and ingress | [README](charts/app/README.md) · [CHANGELOG](charts/app/CHANGELOG.md) · [Examples](charts/app/examples) |
| [`cron`](charts/cron) | Scheduled jobs — many CronJobs per release sharing a common pod spec, with per-job overrides, native sidecars, and full Job control | [README](charts/cron/README.md) · [CHANGELOG](charts/cron/CHANGELOG.md) · [Examples](charts/cron/examples) |

## Quick start

```sh
helm install my-app ./charts/app -f my-values.yaml
helm install my-crons ./charts/cron -f my-cron-values.yaml
```

See each chart's README for parameters and its `examples/` directory for ready-to-use values files: [`app`](charts/app/README.md) covers basic web apps, ingress + TLS, Celery, init containers, hooks, autoscaling, and sidecars ([examples](charts/app/examples)); [`cron`](charts/cron/README.md) covers single and multi-cron releases, Indexed parallel jobs, pod failure policies, and security hardening ([examples](charts/cron/examples)).

## Repository layout

```
charts/                  Helm charts
.github/workflows/       CI: tooling lint, ct lint, kubeconform validate, kind install
.github/ct.yaml          chart-testing configuration
.github/dependabot.yml   Weekly grouped action-pin updates
scripts/                 doctor.sh (config drift) and test-hooks.sh
Makefile                 Local development shortcuts (run `make help`)
AGENTS.md                The brief for agents and humans (CLAUDE.md symlinks to it)
.claude/ .codex/ .agents/  Agent tooling — see .claude/README.md
README.md                You are here
```

## Development

Run `make help` to list available targets. The common ones:

| Target | Purpose |
|--------|---------|
| `make check` | `lint` + render every example (fastest pre-push gate) |
| `make doctor` | Config drift: tool versions (Makefile ⇄ CI) and the agent-config mirrors |
| `make test-hooks` | Tests for the repo's blocking agent hooks |
| `make lint` | `helm lint` every chart |
| `make template` | Render every chart with default values |
| `make template-examples` | Render every chart with each `examples/*.yaml` |
| `make validate` | `kubeconform` validation against Kubernetes 1.33–1.36 |
| `make ct-lint` | Run chart-testing lint locally (matches CI) |
| `make kind-up` / `make kind-down` | Local kind cluster for install tests |
| `make ct-install` | Run chart-testing install + upgrade against the local cluster |
| `make package` | Package every chart into `dist/` |

Tool prerequisites are documented in the Makefile and checked at runtime (`helm`, `kind`, `ct`). `make install-kubeconform` will fetch `kubeconform` into `./bin/` if it is missing. Versions are pinned in both the `Makefile` and `.github/workflows/ci.yaml`; `make doctor` fails if the two ever disagree.

## CI

Every PR runs four jobs across multiple Kubernetes versions:

- **Lint tooling** — `actionlint`, `shellcheck`, `make doctor` (tool-version and
  agent-config drift) and the agent hook tests.
- **Lint and render** — `ct lint` plus full render of every example values file.
- **Validate (k8s 1.34–1.37)** — `kubeconform -strict` against each k8s release.
- **Install (k8s 1.35–1.37)** — real `kind` cluster install *and upgrade from the
  previously released chart version* via `ct install --upgrade`.

Every action is pinned to a full commit SHA; Dependabot moves those pins weekly.

See [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml) for the full pipeline.

## Contributing

Bump the chart version in `Chart.yaml` and update the chart's `CHANGELOG.md` for any change — chart-testing enforces version increments. Keep `values.schema.json` in sync with `values.yaml`, and add or extend an example under `examples/` for any new behaviour.

See [`AGENTS.md`](AGENTS.md) for the full conventions guide.

## Kubernetes compatibility

The `app` and `cron` charts target Kubernetes 1.29 and newer — 1.29 is the floor because native sidecars stabilised there. CI validates rendered manifests against k8s 1.34–1.37 and installs on 1.35–1.37, the versions `kind` v0.33.0 ships node images for. Each chart's `CHANGELOG.md` records the supported floor per release.

## License

[MIT](LICENSE) © Eutychus Towett.
