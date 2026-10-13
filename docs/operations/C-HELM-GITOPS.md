# C – Change Helm or application GitOps

**Use for:** `helm/aspecta/**`, app ConfigMaps/HPA/RBAC/NetworkPolicies or `gitops/apps/aspecta.yaml`. A config-only change **doesn't need a new Docker image**.

## Example C1: raise backend memory limit

```bash
git switch main
git pull --ff-only origin main
git switch -c config/backend-memory
# In helm/aspecta/values.yaml change backend.resources.limits.memory
# e.g. from 256Mi to 384Mi. Leave the image tags unchanged.
helm lint ./helm/aspecta
helm template aspecta ./helm/aspecta -n aspecta-app >/tmp/aspecta.yaml
git diff --check
git add helm/aspecta/values.yaml
git commit -m "chore(helm): increase backend memory limit"
git push -u origin config/backend-memory
```

PR → checks → merge → app Argo CD auto-sync:

```bash
kubectl -n argocd get application aspecta
kubectl -n aspecta-app get deploy aspecta-backend \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}{"\n"}'
```

Expected: new memory limit, unchanged image tags. **No** app version or chart version bump for a routine values change.

## Example C2: change a Helm template

Branch `chart/backend-probe`. Edit `helm/aspecta/templates/backend-deployment.yaml`, validate as above, bump `helm/aspecta/Chart.yaml` **`version`** for a template release (e.g. `0.1.1 → 0.1.2`), then PR and merge. `appVersion` is informational; both services retain separate image tags.

## Example C3: change the app Argo CD Application

Branch `gitops/app-sync-policy`. Edit `gitops/apps/aspecta.yaml`, review it, PR and merge. **Different from editing a Helm values file:** `aspecta-root` watches `gitops/apps/` without automated sync. **Manually Sync `aspecta-root` in the Argo CD UI**, then verify the child Application. No app image release is needed.

## Secrets and recovery

For Sealed Secrets use [full-lab setup](../FULL-LAB-SECRETS.md); commit only encrypted data. If a change breaks the app, revert it via Git PR. Don't manually `kubectl edit` or run `helm upgrade aspecta` against Argo CD-owned workloads.
