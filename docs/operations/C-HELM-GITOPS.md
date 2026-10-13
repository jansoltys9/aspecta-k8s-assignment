# C – Helm and GitOps configuration

**Use this for:** `helm/aspecta/values.yaml`, `helm/aspecta/templates/**`, or app GitOps manifests.

**Result:** Argo CD applies the Git change. There is **no new Docker image** and no backend/frontend version bump for a config-only change.

## Example C1: increase backend memory

Change `backend.resources.limits.memory` from `256Mi` to `384Mi`.

```bash
git switch main
git pull --ff-only origin main
git switch -c config/backend-memory
# Edit helm/aspecta/values.yaml: backend.resources.limits.memory: 384Mi
# Leave backend.image.tag and frontend.image.tag alone.
helm lint ./helm/aspecta
helm template aspecta ./helm/aspecta -n aspecta-app > /tmp/aspecta-rendered.yaml
git diff --check
git diff -- helm/aspecta/values.yaml
git add helm/aspecta/values.yaml
git commit -m "chore(helm): increase backend memory limit"
git push -u origin config/backend-memory
```

Open PR → wait for checks → merge. Then:

```bash
kubectl -n argocd get application aspecta
kubectl -n aspecta-app get deployment aspecta-backend \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}{"\n"}'
```

Expected: `384Mi` and `Synced / Healthy`. Existing image tags remain unchanged.

## Example C2: change a Helm template

Branch `chart/backend-readiness`, edit `helm/aspecta/templates/backend-deployment.yaml`; run the same Helm checks and PR flow. If releasing a changed chart template/default contract, bump **`version`** in `helm/aspecta/Chart.yaml` (example `0.1.1 → 0.1.2`). No application release tag is needed.

Changing only an image tag or routine `values.yaml` setting does **not** require a chart version bump. `Chart.yaml appVersion` is informational; it is **not** the version of two independent services.

## Example C3: rotate a Secret

Branch `gitops/rotate-backend-secret`. In the **full** lab, use Sealed Secrets and your own controller certificate; see [Full-lab Secrets](../FULL-LAB-SECRETS.md). Commit **encrypted data only**. Do not place plaintext passwords or tokens in Git.

**If something breaks:** inspect the Argo CD Diff and Pods; revert the bad Git commit through a PR. Do not `kubectl edit deployment` or `helm upgrade aspecta`: Argo CD owns this release.
