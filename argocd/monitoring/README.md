# Kubernetes Monitoring Stack

This directory contains ArgoCD Application manifests to deploy the standard Kubernetes metrics stack using the **kube-prometheus-stack** Helm chart.

## Components Deployed

The kube-prometheus-stack includes:

| Component | Description |
|-----------|-------------|
| **Prometheus Operator** | Manages Prometheus instances and related resources |
| **Prometheus** | Time-series database for metrics collection |
| **Alertmanager** | Handles alerts sent by Prometheus |
| **Grafana** | Visualization and dashboards |
| **kube-state-metrics** | Generates metrics about Kubernetes objects |
| **node-exporter** | Exposes hardware and OS metrics from nodes |
| **ServiceMonitors** | Auto-discover and scrape Kubernetes components |
| **PrometheusRules** | Pre-configured alerting rules |

## Files

- `namespace.yaml` - Creates the `monitoring` namespace
- `kube-prometheus-stack.yaml` - ArgoCD Application for the full stack

## Deployment

### Using ArgoCD CLI

```bash
# Apply the namespace first
kubectl apply -f namespace.yaml

# Apply the ArgoCD Application
kubectl apply -f kube-prometheus-stack.yaml
```

### Using ArgoCD Core (kubectl plugin)

```bash
argocd app create -f kube-prometheus-stack.yaml
argocd app sync kube-prometheus-stack
```

## Accessing Services

### Grafana

```bash
# Port-forward to access Grafana UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Default credentials
# Username: admin
# Password: admin (change in production!)
```

### Prometheus

```bash
# Port-forward to access Prometheus UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

### Alertmanager

```bash
# Port-forward to access Alertmanager UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

## Configuration

### Customizing Values

Edit the `valuesObject` section in `kube-prometheus-stack.yaml` to customize the deployment:

```yaml
spec:
  source:
    helm:
      valuesObject:
        # Your custom values here
```

### Common Customizations

#### Increase Prometheus Storage

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 50Gi  # Increase from default 20Gi
```

#### Configure Alertmanager Receivers

```yaml
alertmanager:
  config:
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/xxx'
            channel: '#alerts'
```

#### Enable Ingress for Grafana

```yaml
grafana:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
    hosts:
      - grafana.example.com
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.example.com
```

#### Disable Components

```yaml
# Disable Alertmanager
alertmanager:
  enabled: false

# Disable Grafana (if using external)
grafana:
  enabled: false
```

## Storage Requirements

| Component | Default Size | Purpose |
|-----------|--------------|---------|
| Prometheus | 20Gi | Metrics storage |
| Alertmanager | 5Gi | Alert state persistence |
| Grafana | 5Gi | Dashboard and plugin storage |

## Upgrading

The ArgoCD Application is configured with automated sync. To upgrade to a new chart version:

1. Update `targetRevision` in `kube-prometheus-stack.yaml`
2. Commit and push the change
3. ArgoCD will automatically sync the new version

## Troubleshooting

### Check Application Status

```bash
kubectl get applications -n argocd kube-prometheus-stack
```

### View Sync Status

```bash
argocd app get kube-prometheus-stack
```

### Check Prometheus Targets

Access the Prometheus UI and navigate to Status → Targets to verify all endpoints are being scraped correctly.

### Common Issues

1. **CRDs not installing**: Ensure `ServerSideApply=true` is set in syncOptions
2. **Storage class issues**: Ensure a default StorageClass is configured
3. **Control plane metrics not available**: Check that kube-scheduler and kube-controller-manager expose metrics

## References

- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Documentation](https://grafana.com/docs/)

