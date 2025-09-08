# Helm charts

This is home for my helm charts.

```sh
helm template athena ~/Code/my/helm-charts/charts/app \
  -f deploy/helm/prod.yml \
  --namespace prod \
  --dry-run \
  --debug

helm template nginx ~/Code/my/helm-charts/charts/app \
  -f ~/Code/my/helm-charts/charts/app/values-example.yaml \
  --namespace default \
  --dry-run \
  --debug
```
