# Local Path Provisioner

Rancher's Local Path Provisioner provides a way to use local storage in Kubernetes clusters using hostPath volumes.

## Storage Class

This deployment creates a default StorageClass named `local-path` with:
- **Reclaim Policy**: Delete
- **Volume Binding Mode**: WaitForFirstConsumer (default from chart)

## Storage Location

Volumes are stored at `/opt/local-path-provisioner` on the node.

## Usage

Create a PVC using the local-path storage class:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
```

## Sync Wave

This application uses sync-wave `-5` to ensure it's deployed before other applications that may depend on persistent storage.

## Notes

- Data is stored on the local filesystem and is **not replicated**
- Suitable for development, testing, and single-node clusters
- For production, consider a distributed storage solution

