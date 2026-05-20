# Helm Charts

[![CI](https://github.com/etowett/helm-charts/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/etowett/helm-charts/actions/workflows/ci.yaml)

Personal collection of Helm charts. Each chart lives under `charts/` and ships with its own README, schema-validated `values.yaml`, ready-to-use examples, and CHANGELOG.

## Charts

| Chart | Description | Docs |
|-------|-------------|------|
| [`app`](charts/app) | Flexible application chart with optional Celery (worker/beat/flower), hooks, init containers, sidecars, HPA, PDB, and ingress | [README](charts/app/README.md) · [CHANGELOG](charts/app/CHANGELOG.md) · [Examples](charts/app/examples) |

## Quick start

```sh
helm install my-app ./charts/app -f my-values.yaml
```

See the chart's [README](charts/app/README.md) for parameters and the [`examples/`](charts/app/examples) directory for ready-to-use values files covering basic web apps, ingress + TLS, Celery, init containers, hooks, autoscaling, and sidecars.

## Repository layout

```
charts/                  Helm charts
.github/workflows/       CI: lint, kubeconform validate, kind install
.github/ct.yaml          chart-testing configuration
Makefile                 Local development shortcuts (run `make help`)
AGENTS.md                Operational guide for AI agents (and humans)
README.md                You are here
```

## Development

Run `make help` to list available targets. The common ones:

| Target | Purpose |
|--------|---------|
| `make check` | `lint` + render every example (fastest pre-push gate) |
| `make lint` | `helm lint` every chart |
| `make template` | Render every chart with default values |
| `make template-examples` | Render every chart with each `examples/*.yaml` |
| `make validate` | `kubeconform` validation against Kubernetes 1.33–1.36 |
| `make ct-lint` | Run chart-testing lint locally (matches CI) |
| `make kind-up` / `make kind-down` | Local kind cluster for install tests |
| `make ct-install` | Run chart-testing install against the local cluster |
| `make package` | Package every chart into `dist/` |

Tool prerequisites are documented in the Makefile and checked at runtime (`helm`, `kind`, `ct`). `make install-kubeconform` will fetch `kubeconform` into `./bin/` if it is missing.

## CI

Every PR runs three jobs across multiple Kubernetes versions:

- **Lint and render** — `ct lint` plus full render of every example values file.
- **Validate (k8s 1.33–1.36)** — `kubeconform -strict` against each k8s release.
- **Install (k8s 1.33–1.35)** — real `kind` cluster install via `ct install`.

See [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml) for the full pipeline.

## Contributing

Bump the chart version in `Chart.yaml` and update the chart's `CHANGELOG.md` for any change — chart-testing enforces version increments. Keep `values.schema.json` in sync with `values.yaml`, and add or extend an example under `examples/` for any new behaviour.

See [`AGENTS.md`](AGENTS.md) for the full conventions guide.

## Kubernetes compatibility

The `app` chart currently targets Kubernetes 1.29 and newer. CI validates manifest rendering up to the latest stable Kubernetes release and installs on the most recent versions that `kind` ships node images for. Each chart's `CHANGELOG.md` records the supported floor per release.

## License

To be added.
