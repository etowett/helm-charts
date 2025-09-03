# Helm charts

This is home for my helm charts.

```sh
helm template athena ~/Code/my/helm-charts/charts/app \
  -f deploy/helm/prod.yml \
  --namespace prod \
  --dry-run \
  --debug
```
