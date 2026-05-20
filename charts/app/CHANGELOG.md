# Changelog

All notable changes to this Helm chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-02-02

### Fixed
- Fixed bug in deployment.yaml where livenessProbe was incorrectly referencing `readinessProbe.httpHeaders` instead of `livenessProbe.httpHeaders`
- Added missing `service.protocol` default (`TCP`) to prevent invalid manifests when neither `port.protocol` nor `service.protocol` is set
- Corrected `hookVolumes` and `hookVolumeMounts` types from object (`{}`) to array (`[]`) to match the Kubernetes Pod spec rendered by the hook template
- Aligned the `externalSecrets` example in `values.yaml` with the keys actually consumed by the external-secrets template
- Removed `ExternalName` from the `service.type` schema enum since the Service template does not render `externalName`

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

This is a backward-compatible release. No action is required, but a few defaults and types were corrected:

- `service.protocol` now defaults to `TCP`. If you previously relied on the protocol being empty, set `service.protocol: ""` explicitly.
- `hookVolumes` and `hookVolumeMounts` are now typed as arrays (`[]`). If you set them as maps in your values file, convert them to lists.
- `service.type: ExternalName` is no longer accepted by the schema. The Service template never supported it.

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

### None in recent versions

All changes in versions 1.0.0 through 1.4.0 have been backward compatible.

---

## Deprecations

### None at this time

---

## Future Plans

- Support for custom startup probes (Kubernetes 1.20+)
- Support for topologySpreadConstraints
- NetworkPolicy template
- ServiceMonitor template for Prometheus Operator
- Support for multiple init containers
- Support for ephemeral containers
