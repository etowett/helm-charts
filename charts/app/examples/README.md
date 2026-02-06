# Helm Chart Examples

This directory contains example configuration files for common deployment scenarios using this Helm chart.

## Available Examples

### 1. Basic Web Application
**File:** `basic-web-app.yaml`

A simple web application deployment with:
- 3 replicas
- Resource limits and requests
- Health checks (liveness and readiness probes)
- Environment variables

**Usage:**
```bash
helm install my-app ./charts/app -f ./charts/app/examples/basic-web-app.yaml
```

### 2. Web Application with Ingress
**File:** `web-with-ingress.yaml`

Web application with external access:
- Ingress configuration with TLS
- cert-manager integration for automatic SSL certificates
- nginx ingress controller annotations

**Usage:**
```bash
helm install my-app ./charts/app -f ./charts/app/examples/web-with-ingress.yaml
```

### 3. Application with Celery Workers
**File:** `celery-workers.yaml`

Django application with Celery distributed task queue:
- Celery worker with autoscaling
- Celery beat scheduler
- Celery Flower monitoring UI with ingress
- Shared environment variables

**Usage:**
```bash
helm install my-app ./charts/app -f ./charts/app/examples/celery-workers.yaml
```

### 4. Application with Init Container
**File:** `with-init-container.yaml`

Application with database migrations:
- Init container that runs migrations before app starts
- Secret environment variables for database credentials
- Ensures database is ready before app deployment

**Usage:**
```bash
helm install my-app ./charts/app -f ./charts/app/examples/with-init-container.yaml
```

### 5. Application with Pre-Install Hooks
**File:** `with-hooks.yaml`

Application with pre-deployment tasks:
- Pre-install/pre-upgrade hooks for setup tasks
- Runs collectstatic and migrations before deployment
- Configurable backoff and timeout settings

**Usage:**
```bash
helm install my-app ./charts/app -f ./charts/app/examples/with-hooks.yaml
```

### 6. Application with Autoscaling
**File:** `with-autoscaling.yaml`

Production-ready application with high availability:
- Horizontal Pod Autoscaling based on CPU and memory
- Pod Disruption Budget for controlled updates
- Node affinity for optimal placement
- Pod anti-affinity to spread across nodes

**Usage:**
```bash
helm install my-app ./charts/app -f ./charts/app/examples/with-autoscaling.yaml
```

### 7. Application with Sidecar Container
**File:** `with-sidecar.yaml`

Application with a sidecar container:
- Nginx reverse proxy as sidecar
- Shared volumes between containers
- Independent resource limits and health checks

**Usage:**
```bash
helm install my-app ./charts/app -f ./charts/app/examples/with-sidecar.yaml
```

## Combining Examples

You can combine multiple example files to use features from different examples:

```bash
helm install my-app ./charts/app \
  -f ./charts/app/examples/celery-workers.yaml \
  -f ./charts/app/examples/with-autoscaling.yaml
```

## Customizing Examples

These examples are starting points. You should customize them based on your specific requirements:

1. Update image repositories and tags
2. Adjust resource limits based on your application needs
3. Configure environment variables for your application
4. Update ingress hosts and TLS configuration
5. Adjust replica counts and autoscaling thresholds

## Prerequisites

Some examples require additional components to be installed in your cluster:

- **Ingress examples**: nginx-ingress-controller or similar
- **TLS examples**: cert-manager for automatic certificate management
- **Celery examples**: Redis or RabbitMQ for message broker
- **Autoscaling examples**: metrics-server for HPA

## Testing Examples

You can test examples in a dry-run mode to see the generated Kubernetes manifests:

```bash
helm install my-app ./charts/app \
  -f ./charts/app/examples/basic-web-app.yaml \
  --dry-run --debug
```

## Getting Help

For more information, refer to the main [README.md](../README.md) in the chart directory.
