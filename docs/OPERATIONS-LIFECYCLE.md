# Daily use – existing full lab

This guide is for the **existing** Minikube profile `aspecta` (one control plane, two workers). For a new laptop, use [First-time setup](BOOTSTRAP-MODES.md).

### Start the lab

First start Docker Desktop and wait for the Docker Engine.

```bash
cd ~/Project/aspecta-k8s-assignment
bash scripts/aspecta-env.sh start
bash scripts/aspecta-env.sh verify
bash scripts/aspecta-env.sh uis start
bash scripts/aspecta-env.sh uis open
```

`start` resumes an **existing** cluster, safely aligns the CSI addon (after checking PVC ownership), and checks readiness. `verify` is read-only. Neither command forces an Argo CD sync.

| UI | Local address |
|---|---|
| Application | <http://127.0.0.1:18080/> |
| Argo CD | <https://127.0.0.1:18081/> |
| Prometheus | <http://127.0.0.1:18090/> |
| Alertmanager | <http://127.0.0.1:18093/> |

The Argo CD UI uses HTTPS with a local self-signed certificate. If the UIs are not available, check the forwards:

```bash
bash scripts/aspecta-env.sh uis status
bash scripts/aspecta-env.sh uis logs
```

### Quick health check

```bash
kubectl --context aspecta get nodes
kubectl --context aspecta -n argocd get applications
kubectl --context aspecta -n aspecta-app get pods,hpa
curl -fsS http://127.0.0.1:18080/api/hello
```

### Stop safely

```bash
bash scripts/aspecta-env.sh stop
```

This stops forwards and Minikube. It **does not delete** the cluster or PVCs. CSI HostPath is a local lab driver, not a backup solution.

### Troubleshooting

```bash
bash scripts/aspecta-env.sh check    # overview, read only
bash scripts/aspecta-env.sh doctor   # deeper diagnostics, read only
kubectl --context aspecta get pods -A
kubectl --context aspecta -n monitoring get pvc
```

`start` automatically runs the safe storage reconcile. If storage still fails, check `bash scripts/aspecta-env.sh storage status --strict` and investigate; do not delete PVCs.
