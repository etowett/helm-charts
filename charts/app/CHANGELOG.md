# Changelog

All notable changes to this Helm chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-06-24

### Added
- `startupProbe` support on the main container and the optional `sidecarimage` container. Use this for slow-starting apps (JVM, Next.js, Rails eager-load) so the liveness probe — and the HPA's "Ready" gate — do not run during the boot window. Closes the long-standing `Future Plans` item.
- `autoscaling.behavior` exposes the HorizontalPodAutoscaler v2 `behavior` block (`scaleUp` / `scaleDown` policies and `stabilizationWindowSeconds`). Without it, a single boot CPU burst against a small request can cascade into runaway scale-up. Mirrored on `celery.worker.autoscaling.behavior`.
- `autoscaling.metrics` accepts a raw list of HPAv2 metric specs that is appended to the generated `metrics:` list. Use for absolute (`averageValue`) targets, Pods/Object/External metrics. Mirrored on `celery.worker.autoscaling.metrics`.
- `topologySpreadConstraints` on the main deployment and on each celery deployment (`celery.worker`, `celery.beat`, `celery.flower`). String fields are processed through `tpl`, so `{{ .Release.Name }}` and similar template references resolve correctly. Closes the `Future Plans` item; preferred over `podAntiAffinity` since k8s 1.19 (default-on since 1.25).
- New examples:
  - `examples/with-startup-probe.yaml` — slow-booting app pattern.
  - `examples/with-topology-spread.yaml` — modern node/zone spread.
- `examples/with-autoscaling.yaml` extended to demonstrate `autoscaling.behavior`, `autoscaling.metrics`, and `topologySpreadConstraints`.

### Changed
- `autoscaling.targetCPUUtilizationPercentage` and `autoscaling.targetMemoryUtilizationPercentage` schema `maximum` raised from `100` to `1000` (and same for `celery.worker.autoscaling.*`). Utilization is a percentage of the container's resource *request*, and values above 100 are valid — common when the request is intentionally small and you want to absorb short bursts above the request before scaling out. Existing values are unchanged.

### Notes
All v1.5.0 additions are opt-in and default to empty/zero values, so existing values files render the same Kubernetes manifests as on 1.4.0. No migration is required.

## [1.4.0] - 2026-05-20

### Changed (breaking)
- Bumped `kubeVersion` from `>=1.19.0-0` to `>=1.29.0-0` to align with currently-supported upstream Kubernetes releases. Helm will refuse to install on older clusters; pin to an earlier chart release if you need pre-1.29 support.
- Renamed `pvc.created` to `pvc.create`. The old key was a typo and never matched the PVC template, so the template was effectively dead.

### Fixed
- Fixed bug in deployment.yaml where livenessProbe was incorrectly referencing `readinessProbe.httpHeaders` instead of `livenessProbe.httpHeaders`
- Added missing `service.protocol` default (`TCP`) to prevent invalid manifests when neither `port.protocol` nor `service.protocol` is set
- Corrected `hookVolumes` and `hookVolumeMounts` types from object (`{}`) to array (`[]`) to match the Kubernetes Pod spec rendered by the hook template
- Aligned the `externalSecrets` example in `values.yaml` with the keys actually consumed by the external-secrets template
- Removed `ExternalName` from the `service.type` schema enum since the Service template does not render `externalName`
- PVC template now renders successfully: keys (`pvc.create`, `pvc.claimName`, `pvc.size`, `pvc.accessModes`, `pvc.storageClassName`, `pvc.annotations`) are wired through and validated by the schema
- ConfigMap template now emits proper `---` separators between resources and standard `app.kubernetes.io/*` labels
- Removed unreachable pre-1.19 branches from both Ingress templates (the old `extensions/v1beta1` / `networking.k8s.io/v1beta1` fall-throughs and the conditional `pathType`)

### Added
- Comprehensive README.md with detailed documentation
- values.schema.json for values validation
- Enhanced Chart.yaml with metadata (keywords, home, sources, maintainers)
- kubeVersion constraint (>=1.19.0-0)
- Detailed comments and examples in values.yaml
- Examples directory with 7 common deployment scenarios:
  - Basic web application
  - Web application with ingress and TLS
  - Application with Celery workers (worker, beat, flower)
  - Application with init container
  - Application with pre-install hooks
  - Application with autoscaling and PDB
  - Application with sidecar container
- .helmignore file for cleaner chart packaging
- This CHANGELOG.md to track version history

### Documentation
- Added comprehensive parameter documentation
- Added troubleshooting section
- Added upgrade guide
- Added contributing guidelines
- Added practical usage examples

## [1.3.0] - Previous Release

### Added
- Rolling update strategy with configurable maxUnavailable and maxSurge

### Fixed
- Fixed rolling strategy to allow recreate strategy

## [1.2.0] - Previous Release

### Added
- Native Celery support in the charts
  - Celery worker deployment with autoscaling
  - Celery beat deployment
  - Celery Flower monitoring deployment with ingress support
- Line endings fix for consistency

## [1.1.0] - Previous Release

### Added
- Pod Disruption Budget (PDB) support
- Horizontal Pod Autoscaling (HPA)
- External Secrets integration
- Init container support
- Sidecar container support
- Pre-install/pre-upgrade hooks
- Additional environment variables support from secrets

### Changed
- Improved deployment flexibility with custom commands and args
- Enhanced probe configuration

## [1.0.0] - Initial Release

### Added
- Basic Kubernetes Deployment
- Service configuration
- Ingress support
- ConfigMap
- ServiceAccount
- PVC support
- Resource limits and requests
- Node selector, tolerations, and affinity
- Volume and volume mount support
- Basic liveness and readiness probes

---

## Migration Guides

### Migrating to 1.4.0

This release contains two intentional breaking changes:

- `kubeVersion` is now `>=1.29.0-0`. Helm will refuse `install`/`upgrade` on older clusters. If you need to deploy to a cluster on 1.28 or earlier, pin to a `1.3.x` release.
- `pvc.created` has been renamed to `pvc.create`. The old key was a typo and the PVC template never rendered with it. If you had `pvc.created: true` in your values, change it to `pvc.create: true` and review the new `pvc.size` / `pvc.accessModes` / `pvc.storageClassName` defaults.

Other changes you should know about:

- `service.protocol` now defaults to `TCP`. If you previously relied on the protocol being empty, set `service.protocol: ""` explicitly.
- `hookVolumes` and `hookVolumeMounts` are now typed as arrays (`[]`). If you set them as maps in your values file, convert them to lists.
- `service.type: ExternalName` is no longer accepted by the schema. The Service template never supported it.
- The previously-undocumented `configMaps` value is now in the schema and `values.yaml`. Existing values continue to work.

**Recommended Actions:**
1. Review the new examples in the `examples/` directory
2. Consider adding resource limits if not already configured
3. Review the comprehensive README for best practices

### Migrating to 1.3.0

The default deployment strategy is now RollingUpdate with `maxUnavailable: 1` and `maxSurge: 0`. If you want to use the Recreate strategy, explicitly set:

```yaml
strategy:
  type: Recreate
```

### Migrating to 1.2.0

Celery support is opt-in via `celery.enabled: false` by default. No changes required unless you want to enable Celery.

---

## Breaking Changes

### 1.4.0

- `kubeVersion` bumped to `>=1.29.0-0`. Older clusters will be refused at install time.
- `pvc.created` renamed to `pvc.create`. The old key never worked because the template referenced `pvc.create`.

All changes in 1.0.0 through 1.3.x were backward compatible.

---

## Deprecations

### None at this time

---

## Future Plans

- NetworkPolicy template
- ServiceMonitor template for Prometheus Operator
- Support for multiple init containers
- Support for ephemeral containers
