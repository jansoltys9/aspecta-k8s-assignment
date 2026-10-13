# Aspecta: local lifecycle and reviewer setup

Aspecta has two different startup paths. **Use the right one for your situation.**

Run these scripts from a Bash shell on **Windows Git Bash, Linux, or macOS** with Docker, Minikube, kubectl and Helm available. On Windows Git Bash, the Kubernetes `/readyz` health check disables MSYS path rewriting for that request only. Linux and macOS use the normal kubectl request. The UI helper opens a browser with `explorer.exe` (Windows), `xdg-open` (Linux), or `open` (macOS), and prints URLs for headless systems.

> Portability is designed in the scripts; the full local environment has been exercised on Windows. Verify the Docker/Minikube resource limits and chart-image architecture on other operating systems before presenting the full three-node mode.

## Daily operations (existing three-node lab)

Start Docker Desktop (Windows/macOS) or Docker Engine (Linux) before running the commands below.

```bash
bash scripts/aspecta-env.sh start
bash scripts/aspecta-env.sh verify
bash scripts/aspecta-env.sh uis start
bash scripts/aspecta-env.sh uis open
# When finished:
bash scripts/aspecta-env.sh stop
```

`start` resumes the **existing** Minikube profile `aspecta`; it will not create a new cluster. It then checks these dependencies, in order:

1. Kubernetes API and three Ready nodes.
2. Calico, CoreDNS, kube-proxy, CSI HostPath driver, and the enabled Minikube addon state.
   The old storage-provisioner/default-storageclass addons must remain disabled.
3. Traefik, Sealed Secrets controller and Argo CD components.
4. Prometheus Operator, Prometheus, Alertmanager, Metrics Server, its Metrics API and Bound monitoring PVCs.
5. Backend and frontend Deployments.
6. All seven Argo CD Applications `Synced / Healthy`.

The independent `verify` command runs the same checks **without restarting Minikube**. A missing or unhealthy component causes a non-zero exit code and a specific error message. If a component takes longer than expected, inspect its events and logs before increasing `ASPECTA_ROLLOUT_TIMEOUT` (default: 180 seconds per resource) or `ASPECTA_ARGO_TIMEOUT` (default: 120 seconds).

> **Important:** These are ordered **readiness checks**, not a guaranteed container startup order. At Minikube power-on, kubelet and Kubernetes controllers restart existing Pods independently. Startup/restarter counts can increase simply because nodes were powered off. HPA, Argo CD reconciliation and PVCs are deliberately **not changed** by these lifecycle commands.

`stop` saves a Pod JSON snapshot under `~/.aspecta-ops/`, stops the local UI port-forwards and stops Minikube. It does not delete PVCs, Pods or the cluster, and does not suspend GitOps controllers.

## One-time storage alignment (existing full lab)

Full-lab storage uses **only the CSI HostPath driver**, managed by the Minikube
`csi-hostpath-driver` addon. GitOps manages `aspecta-csi-wffc`, which becomes
the default StorageClass after the updated GitOps manifest is synced.

```bash
# This is read-only and can fail before first alignment.
bash scripts/aspecta-env.sh storage status

# Explicit maintenance (may recreate CSI Pods, never deletes PVCs).
bash scripts/aspecta-env.sh storage reconcile

# Once the branch is merged and aspecta-storage reconciles the Git manifest:
bash scripts/aspecta-env.sh storage status --strict
bash scripts/aspecta-env.sh verify
```

The helper validates all existing PVC class assignments before switching addons.
Legacy StorageClass objects may remain visible, but are not default and their
Minikube provisioner addons are disabled. CSI HostPath is only for local labs.

## Reviewer: first installation

Use `aspecta-bootstrap.sh` **only** for intentional first-time setup. Do not run it every morning.

### Lightweight, single-node demo

```bash
bash scripts/aspecta-bootstrap.sh --mode demo --phase infra
bash scripts/aspecta-bootstrap.sh --mode demo --phase app
kubectl --context aspecta-review -n traefik port-forward svc/traefik 18082:80
```

Open `http://127.0.0.1:18082/`. The demo generates its own Kubernetes authentication Secret and does **not** require Argo CD or Sealed Secrets.

### Full three-node GitOps lab

```bash
bash scripts/aspecta-bootstrap.sh --mode full --phase infra
bash scripts/aspecta-bootstrap.sh --mode full --phase gitops
```

Full `infra` enables and checks the CSI HostPath addon; it does not install monitoring PVCs.

The full GitOps phase is intentionally **guided, not automatic**. Argo CD must be installed and configured. First apply `gitops/apps/project-aspecta-management.yaml` (the management AppProject), then `gitops/bootstrap/aspecta-root.yaml`. The reviewer then syncs the root Application and platform prerequisites. A freshly installed Sealed Secrets controller has **different encryption keys** from the reference cluster. The reviewer must seal a new token against their controller and point GitOps at their own repository/fork. See [FULL-LAB-SECRETS.md](FULL-LAB-SECRETS.md).

## Troubleshooting

```bash
bash scripts/aspecta-env.sh doctor
kubectl --context aspecta get pods -A
kubectl --context aspecta get events -A --sort-by=.metadata.creationTimestamp
kubectl --context aspecta -n argocd get applications
kubectl --context aspecta get pvc -A
```

If health checks fail, diagnose the failed component first. Do not bulk-delete `kube-system` Pods, run `minikube delete`, or enable Argo CD Force/Prune to make the dashboard green.
