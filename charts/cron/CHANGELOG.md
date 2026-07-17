# Changelog

All notable changes to this Helm chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-17

### Added
- Initial release of the `cron` chart.
- Define many Kubernetes CronJobs from a single release via a `cronjobs` map of `<name>` -> overrides. Top-level keys act as shared defaults; each entry deep-merges its overrides on top (per-job value wins; maps merge key-by-key, lists are replaced). Each entry renders one CronJob named `<release-fullname>-<name>`.
- Full CronJob scheduling control: `schedule`, `timeZone`, `concurrencyPolicy`, `suspend`, `startingDeadlineSeconds`, and successful/failed job history limits.
- Full Job control under `job`: `restartPolicy`, `backoffLimit`, `ttlSecondsAfterFinished`, `activeDeadlineSeconds`, `parallelism`, `completions`, `completionMode`, `backoffLimitPerIndex`, `maxFailedIndexes`, `podReplacementPolicy`, and `podFailurePolicy`.
- Full pod spec control: image, command/args, `env`/`secretEnv`/`envFrom`, resources, security contexts, volumes/mounts, lifecycle, node selector, tolerations, affinity, topology spread, priority class, runtime class, and termination grace period.
- One-shot init container and **native sidecars** (rendered as init containers with `restartPolicy: Always`) so long-running helpers don't block Job completion.
- Release-scoped helper resources: ServiceAccount, optional RBAC Role/RoleBinding, ConfigMaps, External Secrets, PersistentVolumeClaim, and NetworkPolicy.
- `values.schema.json` (JSON Schema Draft 7) validated at lint/template/install time. The schema is closed at the top level, so a typo'd key fails rendering rather than being silently ignored.
- Examples: single cron, multi-cron with shared defaults, an Indexed parallel job with a native sidecar, a pod failure policy, and a security-hardened configuration. A Helm test confirms the configured image is pullable and runnable.
- Targets Kubernetes 1.29+.

### Notes
- Cronjob map keys are normalized to DNS-1123 labels (e.g. `Nightly_Cleanup` -> `nightly-cleanup`) for resource names, container names, and label values.
- Each cron's resources carry `app.kubernetes.io/component: <name>` alongside the standard labels, so a single cron's jobs and pods can be selected independently of the rest of the release.
- Sidecars require an explicit `image.repository` and `image.tag`, and accept `commands` (matching the main container) as well as `command`.
- Every entry under `cronjobs` must resolve to a non-empty `schedule` — set it per-job or as a shared default. Rendering fails with a named error otherwise.
