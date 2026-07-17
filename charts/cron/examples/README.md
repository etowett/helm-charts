# Helm Chart Examples

This directory contains example configuration files for common scheduling scenarios using this Helm chart. Each is rendered and validated by CI.

## Available Examples

### 1. Single Cron
**File:** `single-cron.yaml`

The simplest useful configuration — one CronJob running a nightly cleanup:
- A fixed `timeZone` so the schedule doesn't drift with the cluster's clock
- Resource limits and requests
- A retry `backoffLimit` and an `activeDeadlineSeconds` wall-clock limit

**Usage:**
```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/single-cron.yaml
```

### 2. Multiple Crons with Shared Defaults
**File:** `multi-cron-shared.yaml`

Three CronJobs (cleanup, sync, weekly report) in one release — the core shared-defaults pattern:
- Shared image, `env`, security contexts, resources, and Job defaults
- Per-job overrides: `concurrencyPolicy: Replace`, an extra merged `env` var, `secretEnv`, a per-job `backoffLimit`, and per-job resources

**Usage:**
```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/multi-cron-shared.yaml
```

### 3. Indexed Parallel Job
**File:** `indexed-parallel-job.yaml`

A batch sharded across parallel workers:
- `completionMode: Indexed` with `completions`/`parallelism: 4` — each pod gets a unique `JOB_COMPLETION_INDEX`
- `backoffLimitPerIndex`, `maxFailedIndexes`, and `podReplacementPolicy`
- A native sidecar (Cloud SQL proxy) that is torn down automatically so the job can complete

**Usage:**
```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/indexed-parallel-job.yaml
```

### 4. Pod Failure Policy
**File:** `pod-failure-policy.yaml`

Retries that depend on *why* a pod failed:
- Fail fast on a non-retriable application exit code
- Ignore node-drain disruptions so they don't burn the `backoffLimit`

**Usage:**
```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/pod-failure-policy.yaml
```

### 5. Security Hardened
**File:** `security-hardened.yaml`

A configuration for workloads under strict security requirements:
- Restricted Pod Security Standards (`runAsUser: 65534`, read-only root filesystem, dropped capabilities)
- `serviceAccount.automount: false`
- A default-deny NetworkPolicy allowing only DNS and HTTPS egress
- External Secrets instead of inline secrets, and minimal RBAC

**Usage:**
```bash
helm install my-crons ./charts/cron -f ./charts/cron/examples/security-hardened.yaml
```

## Notes

- Every entry under `cronjobs` must resolve to a non-empty `schedule` — set it on the job or as a shared top-level default.
- Top-level keys are shared defaults. A per-job override deep-merges over them: maps (like `env`) merge key-by-key, lists (like `args` or `sidecars`) are replaced wholesale.
- `sidecars` render as **native sidecars** (init containers with `restartPolicy: Always`, Kubernetes 1.29+) so a long-running helper doesn't keep the Job from completing.
- These files use placeholder images and secret names — replace them with real values for your deployment.
