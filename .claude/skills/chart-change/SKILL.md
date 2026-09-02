---
name: chart-change
description: The end-to-end contract for changing a Helm chart in this repo — add or change a value, edit a template, or fix a bug. Use whenever a change touches charts/<name>/templates/, values.yaml or values.schema.json, so the six coupled files stay in sync and CI's version-increment check passes first try.
---

# Changing a chart

A chart change is never one file. Six things move together, and CI fails on any
one of them being skipped. Work down the list; skip a step only when the rule
beside it says it does not apply.

## 1. `values.yaml` — the parameter and its `@param` comment

`@param` doc comments are the source of truth for user-visible parameters. A new
key without one is undocumented by definition.

```yaml
## @param sidecars[].restartPolicy  Set to `Always` to render as a native sidecar
```

## 2. `values.schema.json` — the same key, described

**This is part of the chart's contract, not documentation.** A key that
`values.yaml` allows but the schema omits breaks `helm install --validate` for
users. `charts/cron` sets top-level `additionalProperties: false`, so a missing
schema entry there is an immediate hard failure; `charts/app` does not (yet), so
there it fails silently until someone hits it.

## 3. `templates/` — the behaviour

Anything in `_helpers.tpl` is shared by every template in the chart, so a change
there is a change to every scenario, not just the one in front of you. Step 5
is what catches that.

## 4. `examples/<scenario>.yaml` — at least one, for anything new

Every example is rendered *and* kubeconform-validated by CI, against every
supported Kubernetes version. An example is the cheapest regression test this
repo has. Extend an existing one only if the scenario genuinely is the same.

## 5. Render everything, not just what you touched

```sh
make check      # helm lint + render every chart with every examples/*.yaml
make validate   # kubeconform -strict against each supported k8s version
```

`make check` is the fast gate; run `make validate` before opening the PR. If you
changed `_helpers.tpl`, treat a passing `make check` as the *point* of the step,
not a formality.

## 6. `Chart.yaml` version **and** `CHANGELOG.md` — both, always

```sh
# charts/<name>/Chart.yaml
version: "1.5.2"     # semver; breaking values change ⇒ major
```

`CHANGELOG.md` is Keep a Changelog. Lead with a **Changed (breaking)** section
when the change requires users to edit their values.

`ct lint --check-version-increment` fails the PR without the bump, and
`.claude/hooks/guard-chart-contract.sh` refuses the commit without both. If the
hook fires, it is telling you step 6 is missing — not that it is broken.

**Exempt:** a change to only `README.md` or `examples/` does not ship in the
package and needs neither a bump nor a changelog entry.

## 7. Mirror the parameter into the chart README

The README's parameter table mirrors the `@param` comments. Same names, same
defaults, same descriptions — one source of truth, written twice.

## Before the PR

```sh
make check && make validate && make doctor
```

`kubeVersion` in `Chart.yaml` is a promise Helm enforces at install time. Only
move it when the change genuinely requires a newer (or permits an older) API —
never speculatively.
