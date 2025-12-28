# HAProxy Ingress Controller with Gateway API

This directory contains ArgoCD Application manifests to deploy the HAProxy Kubernetes Ingress Controller with Gateway API support enabled.

## Components Deployed

| Component | Description |
|-----------|-------------|
| **Gateway API CRDs** | Standard Gateway API Custom Resource Definitions (v1.2.1) |
| **HAProxy Ingress Controller** | High-performance ingress controller |

## Files

- `namespace.yaml` - Creates the `haproxy-controller` namespace
- `gateway-api-crds.yaml` - ArgoCD Application for Gateway API CRDs
- `haproxy-ingress.yaml` - ArgoCD Application for HAProxy Ingress Controller
- `gateway-example.yaml` - Example Gateway and HTTPRoute configurations (commented)

## Deployment Order

The applications use sync waves to ensure proper deployment order:

1. **Wave -1**: Gateway API CRDs (required first)
2. **Wave 0**: HAProxy Ingress Controller

## Deployment

```bash
# Apply all ingress resources
kubectl apply -f namespace.yaml
kubectl apply -f gateway-api-crds.yaml
kubectl apply -f haproxy-ingress.yaml
```

## Features Enabled

### Gateway API Support

The controller is configured with Gateway API support:

```yaml
controller:
  gatewayControllerName: haproxy.org/gateway-controller
```

### Single-Node Deployment with HostPort

Configured for single-node clusters using hostPort for direct access:

- **Port 80**: HTTP traffic
- **Port 443**: HTTPS traffic
- **Port 1024**: Stats/metrics

```yaml
controller:
  kind: DaemonSet
  replicaCount: 1
  service:
    enabled: false
  daemonset:
    useHostPort: true
    hostPorts:
      http: 80
      https: 443
```

### Prometheus Integration

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

## Using Gateway API

### 1. Create a GatewayClass

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: haproxy
spec:
  controllerName: haproxy.org/gateway-controller
```

### 2. Create a Gateway

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: haproxy-controller
spec:
  gatewayClassName: haproxy
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
```

### 3. Create an HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
  namespace: default
spec:
  parentRefs:
    - name: my-gateway
      namespace: haproxy-controller
  hostnames:
    - "myapp.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-service
          port: 80
```

## Using Traditional Ingress

The controller also supports traditional Kubernetes Ingress resources:

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

### Use Different Host Ports

```yaml
controller:
  daemonset:
    hostPorts:
      http: 8080
      https: 8443
  containerPort:
    http: 8080
    https: 8443
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

### View Stats Page via Port-Forward

```bash
kubectl port-forward -n haproxy-controller pod/$(kubectl get pods -n haproxy-controller -l app.kubernetes.io/name=kubernetes-ingress -o jsonpath='{.items[0].metadata.name}') 1024:1024
# Access http://localhost:1024/stats
```

### Check Logs

```bash
kubectl logs -n haproxy-controller -l app.kubernetes.io/name=kubernetes-ingress -f
```

## Troubleshooting

### Check Application Status

```bash
kubectl get applications -n argocd haproxy-ingress gateway-api-crds
```

### Verify CRDs are Installed

```bash
kubectl get crds | grep gateway
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
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Gateway API with HAProxy](https://www.haproxy.com/documentation/kubernetes-ingress/gateway-api/)

