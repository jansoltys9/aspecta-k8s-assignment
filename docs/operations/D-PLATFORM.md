# D – Platform and add-on updates

**Use this for:** Argo CD, Traefik, monitoring, Metrics Server, Sealed Secrets and storage. **No backend/frontend version bump.**

| Component | Owner | Where to change the version |
|---|---|---|
| Monitoring, Metrics Server, Sealed Secrets | Argo CD | `gitops/apps/*.yaml` → add-on Helm `targetRevision` |
| Traefik | Direct Helm release | `platform/traefik/CHART_VERSION` |
| Argo CD itself | Direct Helm release | `platform/argocd/CHART_VERSION` |
| CSI HostPath driver | Minikube addon | `scripts/aspecta-storage.sh`, maintenance procedure |

Before any upgrade: check release notes, Kubernetes support and CRD/PVC implications. Use a branch + PR; perform the upgrade one component at a time.

## Example D1: upgrade monitoring (Argo CD-owned)

```bash
git switch main
git pull --ff-only origin main
git switch -c platform/monitoring-upgrade
# Check release notes. Edit the CHART targetRevision in gitops/apps/monitoring.yaml.
# If required, update platform/monitoring/values-minikube.yaml as well.
git diff --check
git diff -- gitops/apps/monitoring.yaml platform/monitoring/values-minikube.yaml
git add gitops/apps/monitoring.yaml platform/monitoring/values-minikube.yaml
git commit -m "chore(platform): upgrade monitoring chart"
git push -u origin platform/monitoring-upgrade
```

Open PR → review Diff → merge → let Argo CD sync. A platform-only PR may not trigger the app CI workflow; perform the checks below manually. Check:

```bash
kubectl --context aspecta -n argocd get application aspecta-monitoring
kubectl --context aspecta -n monitoring get pods,pvc
```

Expected: `Synced / Healthy`, Pods Ready, PVCs still Bound. **Do not use `helm upgrade` for this Argo CD-owned add-on.**

## Example D2: upgrade Traefik (direct Helm)

Branch `platform/traefik-upgrade`; change `platform/traefik/CHART_VERSION` (and values if needed). **Also update `TRAEFIK_CHART_VERSION` in `scripts/aspecta-bootstrap.sh`**: first-time setup currently has a separate hardcoded pin. PR → merge. After reviewing the new version and CRDs:

```bash
git switch main && git pull --ff-only origin main
helm history traefik -n traefik --kube-context aspecta
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo update
helm template traefik traefik/traefik -n traefik --kube-context aspecta \
  --version "$(cat platform/traefik/CHART_VERSION)" \
  -f platform/traefik/values-minikube.yaml > /tmp/traefik.yaml
# Planned maintenance only:
helm upgrade traefik traefik/traefik -n traefik --kube-context aspecta \
  --version "$(cat platform/traefik/CHART_VERSION)" \
  -f platform/traefik/values-minikube.yaml --wait
kubectl --context aspecta -n traefik get pods
```

**Version:** the Traefik chart changes, not backend/frontend/Aspecta chart versions. Test the app through the Ingress afterward.

## Example D3: upgrade Argo CD (direct Helm)

Branch `platform/argocd-upgrade`; edit `platform/argocd/CHART_VERSION`, PR and merge. In a maintenance window, after reviewing compatibility/CRDs:

```bash
git switch main && git pull --ff-only origin main
helm history argocd -n argocd --kube-context aspecta
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update
helm template argocd argo/argo-cd -n argocd --kube-context aspecta \
  --version "$(cat platform/argocd/CHART_VERSION)" \
  -f platform/argocd/values-minikube.yaml > /tmp/argocd.yaml
# Planned maintenance only:
helm upgrade argocd argo/argo-cd -n argocd --kube-context aspecta \
  --version "$(cat platform/argocd/CHART_VERSION)" \
  -f platform/argocd/values-minikube.yaml --wait
kubectl --context aspecta -n argocd get pods,applications
```

**If an upgrade fails:** Argo CD-owned add-on → revert via PR. Direct Helm release → inspect `helm history`; consider `helm rollback` after assessing compatibility, then align the Git version pin. Chart upgrades with CRD/data migrations may not be safely reversible.
