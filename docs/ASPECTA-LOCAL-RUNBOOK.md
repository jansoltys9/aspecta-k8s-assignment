# Aspecta – local startup, health check and safe shutdown

Local workflow for **Windows 11 + Git Bash + Docker Desktop (WSL2) + Minikube**.
Use the existing Kubernetes profile `aspecta`, with 1 control plane and 2 workers.
This runbook is for **day-to-day use**, not initial creation of the environment.

## Quick start (normal day)

Open **Docker Desktop**, wait until Docker Engine is running, then in Git Bash:

```bash
cd ~/Project/aspecta-k8s-assignment
bash scripts/aspecta-env.sh check
bash scripts/aspecta-env.sh bootstrap
bash scripts/aspecta-env.sh uis start
bash scripts/aspecta-env.sh uis open
```

To review current condition at any time:

```bash
bash scripts/aspecta-env.sh check    # read-only platform dashboard
bash scripts/aspecta-env.sh doctor   # detailed, read-only diagnostics
bash scripts/aspecta-env.sh flow     # ordered startup/shutdown guide
```

After working:

```bash
bash scripts/aspecta-env.sh stop
```

**`stop` runs `minikube stop`, not `minikube delete`.** It stops locally managed port-forwards first. Docker Desktop may then be closed via the UI. It does **not** destroy Kubernetes resources, PVCs, or data intentionally; however, the Minikube CSI Hostpath driver is for local testing, not durable HA backups.

## What commands do

| Command | Side effects | Purpose |
|---|---|---|
| `check` (default) | None | Docker status, node labels and Pod slots, Docker usage, Argo apps, Deployments, HPA, PVC, StorageClass, Metrics API, Git and UI forward state |
| `start` | Starts **existing** Minikube cluster | Requires Docker already running; refuses to create a new profile |
| `bootstrap` | `start` + reapply node labels from repository | Ordered daily recovery; **does not** sync Argo CD automatically |
| `doctor` | None | Everything in `check`, plus node allocations, events, Docker limits |
| `uis start/open/status/logs/stop` | Controls localhost-only port-forwards | Delegates to the existing UI helper |
| `stop` | Stops UI forwards and cluster | Does not delete cluster/PVC or modify Git |
| `flow` | None | Prints daily operation sequence |

## Architecture and GitOps dependency order

```text
Docker Desktop / WSL2 (memory=9GB)
    |
    v
Existing Minikube profile: aspecta (Kubernetes 1.35.1)
    +-- aspecta        Control plane
    +-- aspecta-m02    Label workload-tier=apps,       aspecta.io/pool=workers
    +-- aspecta-m03    Label workload-tier=monitoring, aspecta.io/pool=workers
    |
    v
Kubernetes API + Calico + CSI Hostpath (system)
    |
    v
Argo CD root: gitops/bootstrap/aspecta-root.yaml (App-of-Apps)
    +-- aspecta-storage       StorageClass aspecta-csi-wffc (WaitForFirstConsumer)
    +-- sealed-secrets        Controller + encrypted Secret
    +-- aspecta-monitoring    Prometheus / Alertmanager / PVCs
    +-- aspecta-metrics-server  CPU metrics for HPA
    +-- aspecta               Frontend, Backend, NetworkPolicies, HPA
    |
    v
Traefik + browser port-forwards
```

Argo CD *sync waves* order resources in a sync operation, but do **not** universally guarantee that every nested Application is fully operational before the next starts. Check `kubectl -n argocd get applications` and PVC status; don't assume `Synced` means the application is serving traffic. `aspecta` can appear `Synced / Progressing` when its ClusterIP-backed Ingress has no published LoadBalancer status, even while the app is accessible.

### After an Argo CD application becomes OutOfSync

1. Inspect the **Diff** in Argo CD UI (`https://127.0.0.1:18081`).
2. If change is intended, **manually Sync** the relevant Application (`aspecta-root` first when adding child Applications, `aspecta` when deploying Helm changes).
3. Avoid `Force`, `Replace`, `Prune` until their effects are understood.
4. Verify `kubectl -n aspecta-app get deploy,pods,hpa -o wide` and the browser.

If `aspecta-root` is missing after a deliberately fresh install **and Argo CD is already installed**, its one-time declaration can be applied from Git:

```bash
kubectl --context aspecta apply -f gitops/bootstrap/aspecta-root.yaml
```

This is **not** executed by `bootstrap` automatically.

## Web interfaces

| Interface | Local URL | Authentication |
|---|---|---|
| Application through Traefik | http://127.0.0.1:18080 | Public lab app |
| Argo CD | https://127.0.0.1:18081 | Argo CD credentials; self-signed HTTPS in local lab |
| Prometheus | http://127.0.0.1:18090 | Localhost lab |
| Alertmanager | http://127.0.0.1:18093 | Localhost lab |

Use `bash scripts/aspecta-env.sh uis status` or `... uis logs` if a page does not load. Port-forward checks indicate a tunnel process, not necessarily that the underlying application is healthy.

## Verification / smoke tests

```bash
kubectl --context aspecta get nodes -L workload-tier,aspecta.io/pool
kubectl --context aspecta -n argocd get applications
kubectl --context aspecta -n aspecta-app get pods,hpa -o wide
kubectl --context aspecta -n monitoring get pods,pvc
kubectl --context aspecta get sc aspecta-csi-wffc
kubectl --context aspecta top nodes
curl -fsS http://127.0.0.1:18080/api/hello
curl -fsS http://127.0.0.1:18090/-/ready
curl -fsS http://127.0.0.1:18093/-/ready
```

## Interpretation and known lab limitations

- The user originally configured `%USERPROFILE%\.wslconfig` with `memory=9GB`, so Docker reports approximately `8.726GiB` available. If Docker is stopped, start it first; if WSL settings change, safely stop Minikube and Docker before `wsl.exe --shutdown`.
- Node-level Docker limits after the latest adjustments are approximately **3.418GiB** control plane, **2.246GiB** m02 and **2.637GiB** m03. `check` displays **current** `docker stats`; `doctor` displays actual config bytes. Kubernetes `kubectl top` node percentages may reflect WSL-wide capacity rather than individual Docker container limits.
- The backend/frontend HPA range is **minReplicas=1**, **maxReplicas=2**, CPU target **70%**. `HPA` cannot prevent downtime during a worker failure when only one replica is running. The node scheduler *prefers* m02 for application Pods but may use m03; that is expected.
- CSI Hostpath uses PVCs with `WaitForFirstConsumer`, but **does not offer shared highly available storage or off-cluster backups**.
- Application Docker images currently include local tags (`aspecta-backend:secret-v1`, `aspecta-frontend:dev`). If an image is missing from a worker after rescheduling, rebuild/load images or complete the planned GHCR workflow. Do not force GitOps resync to work around image problems.
- `git status --short` may show local changes (such as `platform/monitoring/monitoring.yaml`); don't commit unrelated files by accident.

## Useful diagnostics

```bash
bash scripts/aspecta-env.sh doctor
kubectl --context aspecta -n monitoring get events --sort-by=.lastTimestamp
kubectl --context aspecta -n kube-system get apiservice v1beta1.metrics.k8s.io
kubectl --context aspecta -n argocd get application aspecta -o yaml
```

The helper intentionally prints **no secret data**, performs **no Terraform destroy**, **no minikube delete**, **no PVC cleanup**, and **no automatic GitOps sync**.
