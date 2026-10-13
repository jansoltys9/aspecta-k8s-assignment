# Stack and version check

**Example snapshot – 13 October 2026.** Backend and frontend `v0.1.0` were confirmed running with Argo CD `Synced / Healthy`. Versions can change; use the commands below for the current state.

| Component | Version / source | Owner |
|---|---|---|
| Kubernetes | v1.35.1 (lab nodes) | Minikube |
| Backend image | `ghcr.io/jansoltys9/aspecta-backend:v0.1.0` | App release pipeline |
| Frontend image | `ghcr.io/jansoltys9/aspecta-frontend:v0.1.0` | App release pipeline |
| Aspecta Helm chart | `0.1.1` (`Chart.yaml`) | Repo / Argo CD |
| Argo CD | chart `10.10.1` (last observed) | Direct Helm |
| Traefik | chart `41.6.1` (last observed) | Direct Helm |
| Monitoring | kube-prometheus-stack chart `92.2.0` (last observed) | Argo CD |
| Metrics Server | chart `3.14.0` (last observed) | Argo CD |
| Sealed Secrets | chart `2.20.0` (last observed) | Argo CD |
| Storage | Minikube CSI HostPath, `aspecta-csi-wffc` | Minikube + Argo CD |

**Find the actual versions (do not rely on the snapshot):**

```bash
kubectl get nodes
kubectl -n aspecta-app get deployment aspecta-backend aspecta-frontend \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image
cat helm/aspecta/Chart.yaml
cat platform/argocd/CHART_VERSION platform/traefik/CHART_VERSION
helm list -A
kubectl -n argocd get applications
kubectl -n monitoring get pods,pvc
```

Argo CD-managed Helm charts may **not** appear in `helm list -A`; inspect their Argo CD Applications and `gitops/apps/*.yaml` instead. `Chart.yaml appVersion` is informational; it is not a shared backend/frontend version. A green `Synced / Healthy` status is useful but should be paired with a real HTTP check.
