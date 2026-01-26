# Cluster Apps (App of Apps)

This directory contains the root ArgoCD Application that follows the **App of Apps** pattern to deploy all cluster applications from this repository.

## Overview

The `cluster-apps` Application is the entry point that references a Kustomize overlay based on the deployment environment (AWS or libvirt). The overlay then references all individual application directories in the `base/` directory.

## Architecture

```
cluster-apps/
  ├── cluster-apps.yaml (this Application)
  ├── base/
  │   └── kustomization.yaml
  │       ├── cert-manager
  │       ├── ingress
  │       ├── storage
  │       └── monitoring/base
  └── overlays/
      ├── aws/
      │   └── kustomization.yaml
      └── libvirt/
          └── kustomization.yaml
```

## Files

- `cluster-apps.yaml` - ArgoCD Application manifest for the App of Apps pattern
- `kustomization.yaml` - Kustomize resources for this Application
- `base/` - Base Kustomization that references all application directories
- `overlays/` - Environment-specific overlays (aws, libvirt)

## Deployment

### Manual Deployment

```bash
# Apply the Application directly
kubectl apply -f cluster-apps.yaml
```

### Automated Deployment via Ansible

The actual deployment uses the Ansible template at `ansible/roles/argocd/templates/apps.yaml.j2`, which dynamically sets the overlay path based on `terraform_provider`:

- **AWS**: `argocd/cluster-apps/overlays/aws`
- **libvirt**: `argocd/cluster-apps/overlays/libvirt`

## Sync Wave

This Application doesn't use a sync-wave annotation as it's the root Application that manages all other applications.

## Configuration

The Application is configured with:

- **Automated sync**: Enabled with prune and self-heal
- **Retry policy**: 5 retries with exponential backoff (5s → 3m)
- **Sync options**: 
  - `CreateNamespace=true` - Creates namespaces automatically
  - `PrunePropagationPolicy=foreground` - Ensures proper cleanup order
  - `PruneLast=true` - Prunes resources last during sync

## References

- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml/#app-of-apps-pattern)
- [Kustomize Overlays](https://kustomize.io/tutorial/overlays)
