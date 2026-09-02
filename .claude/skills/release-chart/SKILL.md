---
name: release-chart
description: Cut a release of one chart in this repo — what chart-releaser does automatically on merge to main, what a maintainer must do first, and how to verify the release landed on gh-pages and as a GitHub release. Use when asked to release, publish, or ship a chart version.
---

# Releasing a chart

Releases are **automatic**. `.github/workflows/release.yml` runs
`helm/chart-releaser-action` on every push to `main` that touches `charts/**`.
For each chart whose `Chart.yaml` `version` does not yet have a matching git
tag, it packages the chart, creates a GitHub release named `<chart>-<version>`,
and updates `index.yaml` on the `gh-pages` branch.

**So the release is decided in the PR, by the version you write in `Chart.yaml`.**
There is nothing to run afterwards, and nothing to tag by hand.

## Before merging

1. `Chart.yaml` `version` is bumped, and follows semver against what is already
   released — check with `gh release list`.
   - **major** — a values key was removed or renamed, a default changed in a way
     that alters a running deployment, or `kubeVersion`'s floor moved up.
   - **minor** — new values key, new template, new capability. Backwards
     compatible.
   - **patch** — bug fix, no interface change.
2. `CHANGELOG.md` has an entry for exactly that version, dated, in Keep a
   Changelog form. A breaking change leads with **Changed (breaking)**.
3. `make check && make validate` pass.
4. `appVersion` reflects the upstream application version if the chart tracks
   one. It does not need to move when only the templates change.

## After merging

```sh
gh run list --workflow=release.yml --limit 3     # the release run
gh release list --limit 5                        # <chart>-<version> should be there
helm repo add etowett https://etowett.github.io/helm-charts && helm repo update
helm search repo etowett/<chart> --versions | head -5
```

If the release run is green but no release appeared, the version in `Chart.yaml`
already had a tag — chart-releaser skips those silently. Bump again and merge.

## Never

- Do not create the `<chart>-<version>` tag or GitHub release by hand;
  chart-releaser owns both, and a hand-made tag makes it skip the chart forever.
- Do not rewrite `gh-pages`. It is generated.
- Do not re-release a version that shipped. Bump the patch instead — users may
  already have the old digest cached.
