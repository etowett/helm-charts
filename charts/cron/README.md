# Cron Helm Chart

A Helm chart for running scheduled jobs in Kubernetes. One release defines **many CronJobs** that share a common pod spec, with per-job overrides and full control over scheduling, concurrency, retries, history, and parallelism.

## Features

- Many CronJobs per release from a single `cronjobs` map — no installing the chart once per cron
- Shared defaults with per-job overrides (deep-merged: maps merge key-by-key, lists replace)
- Full CronJob control — `schedule`, `timeZone`, `concurrencyPolicy`, `suspend`, `startingDeadlineSeconds`, history limits
- Full Job control — `backoffLimit`, `ttlSecondsAfterFinished`, `activeDeadlineSeconds`, `parallelism`, `completions`, `completionMode`, per-index retries, `podReplacementPolicy`, `podFailurePolicy`
- Full pod spec — env / secret env / envFrom, resources, security contexts, volumes, lifecycle, scheduling (affinity, tolerations, topology spread, priority/runtime class)
- Native sidecars (init containers with `restartPolicy: Always`) so helpers don't block Job completion
- Init containers for migrations and pre-run setup
- Release-scoped helpers — ServiceAccount, optional RBAC, ConfigMaps, External Secrets, PVC, NetworkPolicy
- Schema-validated `values.yaml` (`values.schema.json`)

## Prerequisites

- Kubernetes 1.29+
- Helm 3.8+

Optional:

- **External Secrets Operator** — required for `externalSecrets`

## Installing the Chart

To install the chart with the release name `my-crons`:

```bash
helm install my-crons ./charts/cron -f my-values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall my-crons
```

## How it works

Every top-level key in `values.yaml` is a **shared default**. Each entry under `cronjobs` is a named CronJob (`<release-fullname>-<name>`) that may **override any shared key**. Overrides are deep-merged over the defaults: the per-job value wins, maps such as `env` merge key-by-key, and lists such as `args` or `sidecars` are replaced wholesale.

```yaml
image:
  repository: myrepo/worker
  tag: v1.2.3
env:
  LOG_LEVEL: info          # shared by every cron

cronjobs:
  nightly-cleanup:
    schedule: "0 2 * * *"
    commands: ["/bin/sh"]
    args: ["-c", "bin/cleanup"]
  hourly-sync:
    schedule: "0 * * * *"
    args: ["-c", "bin/sync"]
    concurrencyPolicy: Replace
    env:
      BATCH_SIZE: "1000"   # merged on top of the shared env
    resources:
      limits: { cpu: 500m, memory: 256Mi }
```

This renders two CronJobs (`my-crons-nightly-cleanup`, `my-crons-hourly-sync`) sharing one image and base env, each with its own schedule and overrides.

Cronjob map keys are normalized to DNS-1123 labels (e.g. `Nightly_Cleanup` becomes `nightly-cleanup`) for resource names, container names, and label values. Each cron's resources carry `app.kubernetes.io/component: <name>`, so a single cron's jobs and pods can be selected on their own.

## Configuration

### Image Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository shared by every cronjob | `busybox` |
| `image.pullPolicy` | Image pull policy (`Always`, `IfNotPresent`, `Never`) | `IfNotPresent` |
| `image.tag` | Image tag (overrides the chart appVersion if set) | `"1.36"` |
| `imagePullSecrets` | Kubernetes secret names for pulling private images | `[]` |

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full name of resources | `""` |

### Service Account Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Specifies whether a service account should be created | `true` |
| `serviceAccount.automount` | Automatically mount the ServiceAccount's API credentials | `true` |
| `serviceAccount.annotations` | Annotations to add to the service account (e.g. IRSA / Workload Identity) | `{}` |
| `serviceAccount.name` | Name of the service account (generated from the fullname template if empty) | `""` |
| `serviceAccountName` | Use a specific ServiceAccount name without creating one (overridable per-job) | `""` |

### Pod Metadata Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `annotations` | Annotations applied to every CronJob resource's metadata | `{}` |
| `podAnnotations` | Annotations added to every job pod | `{}` |
| `podLabels` | Labels added to every job pod | `{}` |

### Security Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext` | Pod-level security context | `{}` |
| `securityContext` | Container-level security context for the main job container | `{}` |

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65534
  fsGroup: 65534
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

### Container Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `commands` | Override the container entrypoint | `[]` |
| `args` | Override the container arguments | `[]` |
| `workingDir` | Working directory for the main container | `""` |
| `resources` | Resource limits and requests for the main job container | `{}` |
| `lifecycle` | Lifecycle hooks for the main container | `{}` |
| `env` | Environment variables as key-value pairs | `{}` |
| `secretEnv` | Environment variables sourced from existing secrets | `{}` |
| `envFrom` | Mount entire ConfigMaps or Secrets as environment variables | `[]` |

```yaml
env:
  LOG_LEVEL: "info"
secretEnv:
  DATABASE_PASSWORD:
    name: db-secret
    key: password
envFrom:
  - secretRef:
      name: cron-secrets
```

### Storage Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `volumes` | Additional volumes for the pod | `[]` |
| `volumeMounts` | Additional volume mounts for the main container | `[]` |
| `pvc.enabled` | Create a PersistentVolumeClaim | `false` |
| `pvc.name` | PVC name (defaults to the fullname template) | `""` |
| `pvc.annotations` | Annotations to add to the PVC | `{}` |
| `pvc.accessModes` | Access modes for the PVC | `["ReadWriteOnce"]` |
| `pvc.size` | Storage size to request | `10Gi` |
| `pvc.storageClassName` | Storage class (uses the cluster default if empty) | `""` |
| `pvc.volumeMode` | Volume mode (`Filesystem` or `Block`) | `Filesystem` |
| `pvc.selector` | Label selector to bind a specific volume | `{}` |

### Scheduling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node labels for pod assignment | `{}` |
| `tolerations` | Tolerations for pod assignment | `[]` |
| `affinity` | Affinity rules for pod assignment | `{}` |
| `topologySpreadConstraints` | Topology spread constraints for pod assignment | `[]` |
| `priorityClassName` | Pod priority class name | `""` |
| `runtimeClassName` | Runtime class name (gVisor, Kata, etc.) | `""` |
| `terminationGracePeriodSeconds` | Grace period before a job pod is force-killed | `30` |

### Init Container Parameters

A one-shot init container (e.g. migrations) that must complete before the main container starts. It reuses the cron's image and the shared `env`/`secretEnv`.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `initContainer.enabled` | Enable the one-shot init container | `false` |
| `initContainer.name` | Init container name | `init` |
| `initContainer.commands` | Override the init container entrypoint | `[]` |
| `initContainer.args` | Override the init container arguments | `[]` |
| `initContainer.resources` | Resource limits and requests for the init container | `{}` |
| `initContainer.volumeMounts` | Volume mounts for the init container | `[]` |

```yaml
initContainer:
  enabled: true
  name: migrate
  commands: ["/bin/sh"]
  args: ["-c", "bin/migrate"]
```

### Sidecar Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sidecars` | Native sidecar containers (requires Kubernetes 1.29+) | `[]` |

Sidecars render as **native sidecars** — init containers with `restartPolicy: Always`. This is the correct pattern for Jobs: the sidecar runs alongside the main container and is terminated automatically once the main container exits, so the Job can complete. A plain sidecar would keep the Job running forever.

Each entry requires an explicit `image.repository` and `image.tag`, and accepts `commands` (matching the main container) as well as `command`. Probes (`httpGet` / `tcpSocket` / `exec` / `grpc`) are supported.

```yaml
sidecars:
  - name: cloud-sql-proxy
    image:
      repository: gcr.io/cloud-sql-connectors/cloud-sql-proxy
      tag: "2.11.0"
    args: ["--port=5432", "my-project:us-central1:my-instance"]
    resources:
      limits: { cpu: 200m, memory: 128Mi }
    startupProbe:
      tcpSocket: { port: 5432 }
      periodSeconds: 5
      failureThreshold: 12
```

### CronJob Scheduling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `schedule` | Default cron schedule used when a cronjob omits its own | `""` |
| `timeZone` | IANA time zone for the schedule, e.g. `America/New_York` | `""` |
| `concurrencyPolicy` | How to treat concurrent runs (`Allow`, `Forbid`, `Replace`) | `Forbid` |
| `suspend` | Suspend the schedule (no new jobs are created while true) | `false` |
| `startingDeadlineSeconds` | Deadline for starting a job that missed its scheduled time | `null` |
| `successfulJobsHistoryLimit` | How many completed jobs to retain | `3` |
| `failedJobsHistoryLimit` | How many failed jobs to retain | `1` |

Every entry under `cronjobs` must resolve to a non-empty `schedule`, set either per-job or as a shared default. Rendering fails with a named error if one does not.

### Job Parameters

Set under `job` (shared) or `cronjobs.<name>.job` (per-job).

| Parameter | Description | Default |
|-----------|-------------|---------|
| `job.restartPolicy` | Restart policy for job pods (`OnFailure` or `Never`) | `OnFailure` |
| `job.backoffLimit` | Number of retries before the job is marked failed | `6` |
| `job.ttlSecondsAfterFinished` | Auto-clean finished jobs this many seconds after completion | `3600` |
| `job.activeDeadlineSeconds` | Hard wall-clock limit for a single job run, in seconds | `null` |
| `job.parallelism` | Number of pods running in parallel | `null` |
| `job.completions` | Number of successful completions required | `null` |
| `job.completionMode` | `NonIndexed` or `Indexed` | `NonIndexed` |
| `job.backoffLimitPerIndex` | Per-index retry limit for Indexed jobs | `null` |
| `job.maxFailedIndexes` | Maximum failed indexes before an Indexed job fails | `null` |
| `job.podReplacementPolicy` | When to create replacement pods (`Failed`, `TerminatingOrFailed`) | `null` |
| `job.podFailurePolicy` | Fine-grained handling of pod failures | `{}` |

#### Pod failure policy

React to *why* a pod failed instead of blindly retrying:

```yaml
job:
  podFailurePolicy:
    rules:
      - action: FailJob          # non-retriable exit code → fail immediately
        onExitCodes:
          operator: In
          values: [42]
      - action: Ignore           # node drain → don't count against backoffLimit
        onPodConditions:
          - type: DisruptionTarget
            status: "True"
```

### CronJobs

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cronjobs` | Map of `<name>` → per-cronjob overrides (each must resolve to a `schedule`) | `{}` |

### Helper Resource Parameters

Release-scoped resources, created once per release rather than per cronjob.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `configMaps` | ConfigMaps to create | `[]` |
| `externalSecrets` | External Secrets to create (requires the External Secrets Operator) | `[]` |
| `networkPolicy.enabled` | Create a NetworkPolicy for the cronjob pods | `false` |
| `networkPolicy.policyTypes` | Policy types to enforce | `["Egress"]` |
| `networkPolicy.ingress` | Ingress rules | `[]` |
| `networkPolicy.egress` | Egress rules | `[]` |
| `rbac.enabled` | Create a Role and RoleBinding for the ServiceAccount | `false` |
| `rbac.rules` | Role rules | `[]` |

```yaml
rbac:
  enabled: true
  rules:
    - apiGroups: ["batch"]
      resources: ["jobs"]
      verbs: ["get", "list", "watch"]

externalSecrets:
  - name: cron-db
    refreshInterval: 1h
    secretStoreRefName: gcp-secret-store
    targetName: cron-db
    dataKey: prod/cron/db

networkPolicy:
  enabled: true
  policyTypes: ["Egress"]
  egress:
    - ports:
        - { protocol: TCP, port: 443 }
```

## Examples

Ready-to-use values files live in [`examples/`](examples/). See the [examples README](examples/README.md) for the full list.

### A single scheduled job

```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/single-cron.yaml
```

```yaml
image:
  repository: myrepo/worker
  tag: "v1.2.3"

cronjobs:
  nightly-cleanup:
    schedule: "0 2 * * *"
    timeZone: "America/New_York"
    commands: ["/bin/sh"]
    args: ["-c", "bin/cleanup --older-than=30d"]
    job:
      backoffLimit: 3
      activeDeadlineSeconds: 1800
```

### Several crons sharing one image and config

```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/multi-cron-shared.yaml
```

### A parallel, Indexed job

Shard a batch across N workers. Each pod gets a unique `JOB_COMPLETION_INDEX`, and the job completes when every index succeeds.

```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/indexed-parallel-job.yaml
```

```yaml
cronjobs:
  shard-processor:
    schedule: "*/30 * * * *"
    commands: ["/bin/sh"]
    args: ["-c", "bin/process --shard=$JOB_COMPLETION_INDEX --of=4"]
    job:
      completionMode: Indexed
      completions: 4
      parallelism: 4
      backoffLimitPerIndex: 2
```

## Operating cronjobs

```bash
# List the cronjobs this release created
kubectl get cronjobs -l app.kubernetes.io/instance=my-crons

# Trigger a run now, without waiting for the schedule
kubectl create job my-run --from=cronjob/my-crons-nightly-cleanup

# Inspect runs and logs for one cron
kubectl get jobs -l app.kubernetes.io/instance=my-crons,app.kubernetes.io/component=nightly-cleanup
kubectl logs -l app.kubernetes.io/instance=my-crons --tail=100 -f

# Pause / resume a schedule (or set suspend: true in values)
kubectl patch cronjob my-crons-hourly-sync -p '{"spec":{"suspend":true}}'
```

## Troubleshooting

**A cronjob never runs.** Check that it is not suspended and that the schedule is what you expect: `kubectl describe cronjob <name>`. If `startingDeadlineSeconds` is set and the controller was down longer than that, the run is skipped rather than backfilled.

**Jobs pile up or overlap.** The default `concurrencyPolicy: Forbid` skips a run whose predecessor is still going. Use `Replace` to kill the old run, or raise `job.activeDeadlineSeconds` if runs legitimately take longer than the interval.

**A job never completes and stays Running.** If a helper container keeps running after the main container exits, it must be under `sidecars` (native sidecars are terminated automatically), not a plain container.

**Finished jobs accumulate.** Lower `job.ttlSecondsAfterFinished`, or the `successfulJobsHistoryLimit` / `failedJobsHistoryLimit`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

[MIT](../../LICENSE) © Eutychus Towett.
