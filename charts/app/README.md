# Application Helm Chart

A flexible and production-ready Helm chart for deploying applications in Kubernetes with support for Celery workers, init containers, sidecars, and comprehensive configuration options.

## Features

- Flexible deployment configuration with support for multiple deployment strategies
- Built-in support for Celery workers (worker, beat, flower)
- Init containers for pre-deployment tasks
- Sidecar container support
- Horizontal Pod Autoscaling (HPA)
- Pod Disruption Budget (PDB)
- Ingress configuration with TLS support
- External Secrets integration
- Pre-install/pre-upgrade hooks
- Liveness and readiness probes
- Customizable resource limits and requests
- Service account configuration
- Persistent Volume Claim support

## Prerequisites

- Kubernetes 1.29+
- Helm 3.8+

## Installing the Chart

To install the chart with the release name `my-app`:

```bash
helm install my-app ./charts/app
```

To install with custom values:

```bash
helm install my-app ./charts/app -f my-values.yaml
```

## Uninstalling the Chart

To uninstall the `my-app` deployment:

```bash
helm uninstall my-app
```

## Configuration

The following table lists the configurable parameters of the chart and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas for the main application | `1` |
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full name of resources | `""` |

### Image Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image repository | `nginx` |
| `image.tag` | Image tag (overrides appVersion) | `"latest"` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets | `[]` |

### Application Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.name` | Application name | `nginx` |
| `app.env` | Application environment | `stage` |
| `app.country` | Application country/region | `ke` |

### Deployment Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `strategy.type` | Deployment strategy type | `RollingUpdate` |
| `strategy.rollingUpdate.maxUnavailable` | Max unavailable pods during update | `1` |
| `strategy.rollingUpdate.maxSurge` | Max surge pods during update | `0` |
| `commands` | Override container command | `[]` |
| `args` | Override container args | `[]` |
| `env` | Environment variables as key-value pairs | `{}` |
| `secretEnv` | Environment variables from secrets | `{}` |

### Service Account Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create service account | `true` |
| `serviceAccount.automount` | Automount service account token | `true` |
| `serviceAccount.annotations` | Service account annotations | `{}` |
| `serviceAccount.name` | Service account name | `""` |

### Pod Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podAnnotations` | Pod annotations | `{}` |
| `podLabels` | Pod labels | `{}` |
| `podSecurityContext` | Pod security context | `{}` |
| `securityContext` | Container security context | `{}` |

### Network Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `port` | Container port configuration | `{}` |
| `service.type` | Service type | `ClusterIP` |
| `service.name` | Service port name | `http` |
| `service.port` | Service port | `80` |
| `service.protocol` | Container port protocol fallback used by the deployment template | `TCP` |
| `extraPorts` | Additional ports to expose | `{}` |

### Ingress Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts configuration | `[{"host": "chart-example.local", "paths": [{"path": "/", "pathType": "ImplementationSpecific"}]}]` |
| `ingress.tls` | Ingress TLS configuration | `[]` |

### Probes Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe` | Liveness probe configuration (empty `{}` disables the probe) | `{}` |
| `livenessProbe.path` | Liveness probe HTTP path | - |
| `livenessProbe.port` | Liveness probe port | - |
| `livenessProbe.httpHeaders` | Liveness probe HTTP headers | `[]` |
| `livenessProbe.initialDelaySeconds` | Initial delay for liveness probe | - |
| `livenessProbe.periodSeconds` | Period for liveness probe | - |
| `livenessProbe.timeoutSeconds` | Timeout for liveness probe | - |
| `readinessProbe` | Readiness probe configuration (empty `{}` disables the probe) | `{}` |
| `readinessProbe.path` | Readiness probe HTTP path | - |
| `readinessProbe.port` | Readiness probe port | - |
| `readinessProbe.httpHeaders` | Readiness probe HTTP headers | `[]` |
| `readinessProbe.initialDelaySeconds` | Initial delay for readiness probe | - |
| `readinessProbe.periodSeconds` | Period for readiness probe | - |
| `readinessProbe.timeoutSeconds` | Timeout for readiness probe | - |
| `startupProbe` | Startup probe configuration (empty `{}` disables the probe). Use for slow-starting apps so the liveness probe and HPA "Ready" gate are deferred until the app has reported healthy once. | `{}` |
| `startupProbe.path` | Startup probe HTTP path | - |
| `startupProbe.port` | Startup probe port | - |
| `startupProbe.httpHeaders` | Startup probe HTTP headers | `[]` |
| `startupProbe.initialDelaySeconds` | Seconds before first probe | - |
| `startupProbe.periodSeconds` | Seconds between probes | - |
| `startupProbe.timeoutSeconds` | Per-probe timeout in seconds | - |
| `startupProbe.failureThreshold` | Consecutive failures before the container is restarted. Effective max boot time = `periodSeconds * failureThreshold`. | - |
| `startupProbe.successThreshold` | Consecutive successes before the probe is considered started | - |

### Resources Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | Resource limits and requests | `{}` |

### Autoscaling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable horizontal pod autoscaling | `false` |
| `autoscaling.minReplicas` | Minimum number of replicas | `1` |
| `autoscaling.maxReplicas` | Maximum number of replicas | `100` |
| `autoscaling.targetCPUUtilizationPercentage` | Target average CPU utilization as a percentage of the container's CPU request. Values > 100 are valid when the request is intentionally small. | `80` |
| `autoscaling.targetMemoryUtilizationPercentage` | Target average memory utilization (% of request) | `80` |
| `autoscaling.metrics` | Extra raw HPA v2 metric specs appended to the generated `metrics:` list. Use for `averageValue` targets, Pods/Object/External metrics. | `[]` |
| `autoscaling.behavior` | HPA v2 `behavior` block (`scaleUp` / `scaleDown` policies + `stabilizationWindowSeconds`). Strongly recommended for apps with bursty boot-time CPU. | `{}` |

### Pod Disruption Budget Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pdb.enabled` | Enable pod disruption budget | `false` |
| `pdb.minAvailable` | Minimum available pods | `1` |

### Storage Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `pvc.create` | Create persistent volume claim | `false` |
| `pvc.claimName` | Override the generated PVC name | `""` (defaults to `<fullname>-data`) |
| `pvc.size` | Requested storage size (Kubernetes quantity) | `1Gi` |
| `pvc.accessModes` | PVC access modes | `[ReadWriteOnce]` |
| `pvc.storageClassName` | StorageClass name (empty uses cluster default) | `""` |
| `pvc.annotations` | PVC annotations | `{}` |
| `volumes` | Additional volumes | `[]` |
| `volumeMounts` | Additional volume mounts | `[]` |
| `configMaps` | Additional ConfigMaps to render alongside the app | `[]` |

### Scheduling Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `topologySpreadConstraints` | Pod topology spread constraints (preferred over `podAntiAffinity` since k8s 1.19+, default-on since 1.25). String fields are processed through `tpl`, so `{{ .Release.Name }}` resolves correctly. | `[]` |

### External Secrets Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalSecrets` | External secrets configuration | `[]` |

### Init Container Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `initContainer.enabled` | Enable init container | `false` |
| `initContainer.name` | Init container name | - |
| `initContainer.commands` | Init container commands | - |
| `initContainer.args` | Init container args | - |
| `initContainer.resources` | Init container resources | `{}` |
| `initContainer.volumeMounts` | Init container volume mounts | - |

### Sidecar Container Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sidecarimage` | Sidecar container configuration | - |
| `sidecarimage.name` | Sidecar container name | - |
| `sidecarimage.repository` | Sidecar image repository | - |
| `sidecarimage.tag` | Sidecar image tag | - |
| `sidecarimage.pullPolicy` | Sidecar image pull policy | - |
| `sidecarimage.ports` | Sidecar container ports | - |
| `sidecarimage.mounts` | Sidecar volume mounts | - |
| `sidecarimage.resources` | Sidecar resources | - |
| `sidecarimage.livenessProbe` | Sidecar liveness probe | - |
| `sidecarimage.readinessProbe` | Sidecar readiness probe | - |
| `sidecarimage.startupProbe` | Sidecar startup probe (same shape as the main container's `startupProbe`) | - |

### Hook Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hook` | Pre-install/pre-upgrade hook configuration | - |
| `hook.name` | Hook job name | - |
| `hook.image.repository` | Hook image repository | - |
| `hook.image.tag` | Hook image tag | - |
| `hook.image.pullPolicy` | Hook image pull policy | - |
| `hook.commands` | List of commands to run | - |
| `hook.backoffLimit` | Hook job backoff limit | - |
| `hook.ttlSecondsAfterFinished` | TTL for completed hook jobs | `3600` |
| `hook.activeDeadlineSeconds` | Active deadline for hook jobs | - |
| `hookVolumes` | Volumes for hook jobs | `{}` |
| `hookVolumeMounts` | Volume mounts for hook jobs | `{}` |

### Celery Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `celery.enabled` | Enable Celery workers | `false` |

#### Celery Worker Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `celery.worker.enabled` | Enable Celery worker | `true` |
| `celery.worker.replicaCount` | Number of worker replicas | `1` |
| `celery.worker.command` | Worker command | `["python", "manage.py", "celery", "worker"]` |
| `celery.worker.args` | Worker arguments | `[]` |
| `celery.worker.resources` | Worker resources | `{}` |
| `celery.worker.autoscaling.enabled` | Enable worker autoscaling | `false` |
| `celery.worker.autoscaling.minReplicas` | Min worker replicas | `1` |
| `celery.worker.autoscaling.maxReplicas` | Max worker replicas | `10` |
| `celery.worker.autoscaling.targetCPUUtilizationPercentage` | Target CPU for worker (% of request, values > 100 allowed) | `80` |
| `celery.worker.autoscaling.targetMemoryUtilizationPercentage` | Target memory for worker (% of request) | `80` |
| `celery.worker.autoscaling.metrics` | Extra raw HPA v2 metric specs for the worker HPA | `[]` |
| `celery.worker.autoscaling.behavior` | HPA v2 `behavior` block for the worker HPA | `{}` |
| `celery.worker.nodeSelector` | Worker node selector | `{}` |
| `celery.worker.tolerations` | Worker tolerations | `[]` |
| `celery.worker.affinity` | Worker affinity | `{}` |
| `celery.worker.topologySpreadConstraints` | Worker pod topology spread constraints (processed through `tpl`) | `[]` |
| `celery.worker.podAnnotations` | Worker pod annotations | `{}` |
| `celery.worker.podLabels` | Worker pod labels | `{}` |

#### Celery Beat Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `celery.beat.enabled` | Enable Celery beat scheduler | `false` |
| `celery.beat.command` | Beat command | `["python", "manage.py", "celery", "beat"]` |
| `celery.beat.args` | Beat arguments | `[]` |
| `celery.beat.resources` | Beat resources | `{}` |
| `celery.beat.nodeSelector` | Beat node selector | `{}` |
| `celery.beat.tolerations` | Beat tolerations | `[]` |
| `celery.beat.affinity` | Beat affinity | `{}` |
| `celery.beat.topologySpreadConstraints` | Beat pod topology spread constraints (processed through `tpl`) | `[]` |
| `celery.beat.podAnnotations` | Beat pod annotations | `{}` |
| `celery.beat.podLabels` | Beat pod labels | `{}` |

#### Celery Flower Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `celery.flower.enabled` | Enable Celery Flower monitoring | `false` |
| `celery.flower.replicaCount` | Number of flower replicas | `1` |
| `celery.flower.command` | Flower command | `["python", "manage.py", "celery", "flower"]` |
| `celery.flower.args` | Flower arguments | `[]` |
| `celery.flower.resources` | Flower resources | `{}` |
| `celery.flower.service.port` | Flower service port | `5555` |
| `celery.flower.service.type` | Flower service type | `ClusterIP` |
| `celery.flower.service.name` | Flower service name | `flower` |
| `celery.flower.ingress.enabled` | Enable Flower ingress | `false` |
| `celery.flower.ingress.className` | Flower ingress class | `""` |
| `celery.flower.ingress.annotations` | Flower ingress annotations | `{}` |
| `celery.flower.ingress.hosts` | Flower ingress hosts | See values.yaml |
| `celery.flower.ingress.tls` | Flower ingress TLS | `[]` |
| `celery.flower.nodeSelector` | Flower node selector | `{}` |
| `celery.flower.tolerations` | Flower tolerations | `[]` |
| `celery.flower.affinity` | Flower affinity | `{}` |
| `celery.flower.topologySpreadConstraints` | Flower pod topology spread constraints (processed through `tpl`) | `[]` |
| `celery.flower.podAnnotations` | Flower pod annotations | `{}` |
| `celery.flower.podLabels` | Flower pod labels | `{}` |

## Examples

### Basic Web Application

```yaml
replicaCount: 3

image:
  repository: myapp/web
  tag: "1.0.0"
  pullPolicy: IfNotPresent

app:
  name: mywebapp
  env: production
  country: us

service:
  type: ClusterIP
  port: 8080

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

livenessProbe:
  path: /health
  port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5

readinessProbe:
  path: /ready
  port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
```

### Application with Ingress

```yaml
image:
  repository: myapp/web
  tag: "1.0.0"

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com
```

### Application with Celery Workers

```yaml
image:
  repository: myapp/django
  tag: "1.0.0"

celery:
  enabled: true

  worker:
    enabled: true
    replicaCount: 3
    command: ["celery", "-A", "myapp", "worker"]
    args: ["-l", "info"]
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70

  beat:
    enabled: true
    command: ["celery", "-A", "myapp", "beat"]
    resources:
      limits:
        cpu: 200m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi

  flower:
    enabled: true
    command: ["celery", "-A", "myapp", "flower"]
    ingress:
      enabled: true
      className: nginx
      hosts:
        - host: flower.example.com
          paths:
            - path: /
              pathType: Prefix
```

### Application with Init Container

```yaml
image:
  repository: myapp/web
  tag: "1.0.0"

initContainer:
  enabled: true
  name: db-migrations
  commands: ["python"]
  args: ["manage.py", "migrate"]
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
```

### Application with Pre-Install Hook

```yaml
image:
  repository: myapp/web
  tag: "1.0.0"

hook:
  name: pre-install-setup
  image:
    repository: myapp/web
    tag: "1.0.0"
    pullPolicy: IfNotPresent
  commands:
    - command: "python manage.py collectstatic --noinput"
    - command: "python manage.py migrate --noinput"
  backoffLimit: 3
  ttlSecondsAfterFinished: 600
  activeDeadlineSeconds: 300
```

### Application with Autoscaling and PDB

```yaml
replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

pdb:
  enabled: true
  minAvailable: 2

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

### Application with Sidecar

```yaml
image:
  repository: myapp/web
  tag: "1.0.0"

sidecarimage:
  name: nginx-proxy
  repository: nginx
  tag: "1.21"
  pullPolicy: IfNotPresent
  ports:
    - name: proxy
      containerPort: 8080
      protocol: TCP
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

## Upgrading

### To 1.5.0

Backward-compatible release. Existing values files render the same manifests they did on 1.4.0. New opt-in features:

- `startupProbe` on the main container and on `sidecarimage`. Recommended for any app whose boot time is comparable to or larger than `livenessProbe.failureThreshold * livenessProbe.periodSeconds`.
- `autoscaling.behavior` exposes the HPAv2 `behavior` block. Strongly recommended whenever boot CPU dwarfs steady-state CPU (Next.js, JVM, Rails eager-load) — without it, a single booting pod's CPU burst can cascade the HPA into runaway scale-up. Mirrored on `celery.worker.autoscaling.behavior`.
- `autoscaling.metrics` accepts a raw list of HPAv2 metric specs (appended to the generated `metrics:`). Use for absolute (`averageValue`) targets and for Pods/Object/External metrics. Mirrored on `celery.worker.autoscaling.metrics`.
- `topologySpreadConstraints` is now wired on the main deployment and on every celery deployment. Prefer this over `affinity.podAntiAffinity` for new deployments.
- The schema `maximum` on `targetCPUUtilizationPercentage` / `targetMemoryUtilizationPercentage` (and the celery worker equivalents) was raised from `100` to `1000` to reflect that utilization is a percentage of the container's *request*, not of node capacity. Existing values are unchanged.

See `examples/with-startup-probe.yaml`, `examples/with-topology-spread.yaml`, and the updated `examples/with-autoscaling.yaml` for ready-to-use snippets.

### To 1.4.0

This release modernises the chart for currently-supported Kubernetes versions and fixes templates that previously could not be enabled.

Breaking changes:

- `kubeVersion` is now `>=1.29.0-0`. Helm will refuse to install on clusters older than 1.29. If you need to run on an older cluster, pin to an earlier chart release.
- `pvc.created` was renamed to `pvc.create` (the old key was a typo; the PVC template never matched). New keys `pvc.claimName`, `pvc.size`, `pvc.accessModes`, `pvc.storageClassName`, and `pvc.annotations` are now exposed.
- `hookVolumes` and `hookVolumeMounts` are arrays (`[]`) rather than objects.

Other changes:

- Fixed the livenessProbe `httpHeaders` reference in the deployment template.
- Added `service.protocol` default (`TCP`) so manifests stay valid out of the box.
- Documented and schema-validated the previously-undocumented `configMaps` value; the ConfigMap template now emits proper YAML separators and labels.
- Removed dead pre-1.19 branches from both Ingress templates now that the chart only targets 1.29+.
- Expanded documentation, configuration examples, and JSON schema validation.

## Troubleshooting

### Pods are in CrashLoopBackOff

Check the pod logs:

```bash
kubectl logs <pod-name>
```

Common causes:
- Incorrect image or tag
- Missing environment variables
- Failed liveness/readiness probes
- Insufficient resources

### Ingress not working

Verify the ingress controller is installed:

```bash
kubectl get pods -n ingress-nginx
```

Check ingress resource:

```bash
kubectl describe ingress <ingress-name>
```

### Celery workers not processing tasks

Check worker logs:

```bash
kubectl logs <celery-worker-pod-name>
```

Verify environment variables for broker and backend are set correctly.

## Contributing

Contributions are welcome. Please submit pull requests or issues to the repository.

## License

This chart is provided as-is for use in your projects.
