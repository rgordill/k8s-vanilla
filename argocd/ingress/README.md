# HAProxy Ingress Controller

This directory contains ArgoCD Application manifests to deploy the HAProxy Kubernetes Ingress Controller.

## Components Deployed

| Component | Description |
|-----------|-------------|
| **HAProxy Ingress Controller** | High-performance ingress controller |

## Files

- `namespace.yaml` - Creates the `haproxy-controller` namespace
- `haproxy-ingress.yaml` - ArgoCD Application for HAProxy Ingress Controller

## Single-Node Deployment with HostPort

Configured for single-node clusters using hostPort for direct access:

- **Port 80**: HTTP traffic
- **Port 443**: HTTPS traffic
- **Port 1024**: Stats/metrics

```yaml
controller:
  kind: DaemonSet
  replicaCount: 1
  daemonset:
    useHostPort: true
    hostPorts:
      http: 80
      https: 443
```

## Prometheus Integration

ServiceMonitor enabled for metrics collection (requires kube-prometheus-stack):

```yaml
controller:
  serviceMonitor:
    enabled: true
    endpoints:
      - port: stat
        path: /metrics
        interval: 30s
```

## Using Ingress Resources

The controller supports Kubernetes Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    kubernetes.io/ingress.class: haproxy
spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

## Configuration

### Enable TLS

```yaml
controller:
  config:
    ssl-certificate: "default/tls-secret"
```

### Custom Timeout Settings

```yaml
controller:
  config:
    timeout-connect: 10s
    timeout-client: 60s
    timeout-server: 60s
```

## Accessing the Controller

### Direct Access via Node IP

Since hostPort is used, access HAProxy directly on the node:

```bash
# HTTP traffic
curl http://<NODE_IP>/

# HTTPS traffic
curl https://<NODE_IP>/

# Stats page
curl http://<NODE_IP>:1024/stats
```

### Check Logs

```bash
kubectl logs -n haproxy-controller -l app.kubernetes.io/name=kubernetes-ingress -f
```

## Troubleshooting

### Check Application Status

```bash
kubectl get applications -n argocd haproxy-ingress
```

### Check Controller Pods

```bash
kubectl get pods -n haproxy-controller
```

### View Controller Configuration

```bash
kubectl exec -n haproxy-controller -it deploy/haproxy-ingress-kubernetes-ingress -- cat /etc/haproxy/haproxy.cfg
```

## References

- [HAProxy Kubernetes Ingress Controller](https://github.com/haproxytech/kubernetes-ingress)
- [HAProxy Helm Charts](https://github.com/haproxytech/helm-charts)
