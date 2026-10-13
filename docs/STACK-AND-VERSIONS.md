# Aspecta: Stack, ownership and version inventory

> Reference date: **2026-10-13**. The *observed* versions below came from the local three-node lab. The *declared* versions come from configuration or known bootstrap pins. Do not treat a Helm release record as proof of the Argo CD-rendered chart version. Refresh this inventory before a demo or upgrade.

## 1. Who manages what?

| Layer | Managed by | Examples | Update mechanism |
| --- | --- | --- | --- |
| Kubernetes cluster | Minikube / local Docker runtime | One control-plane node, two worker nodes, Calico | `scripts/aspecta-bootstrap.sh` (initial setup), `scripts/aspecta-env.sh` (daily lifecycle) |
| Infrastructure prerequisites | Minikube add-ons / pinned Helm install | CSI HostPath driver, Traefik ingress, initial Argo CD | Explicit bootstrap/install; **not** application Auto-Sync |
| Platform desired state | Argo CD App-of-Apps | `aspecta-storage`, monitoring, metrics-server, Sealed Secrets | GitOps Applications on `main` |
| Application desired state | Argo CD + Helm chart from Git | Backend/frontend Deployments, Services, Ingress, HPA, policies, probes | Git commit to chart/values -> Argo CD |
| Containers | GitHub Actions + GHCR | Backend and frontend immutable `sha-<commit>` tags | Build, security scan, publish and promote |
| Persistent data | Kubernetes PVC + CSI HostPath | Prometheus 2 GiB, Alertmanager 512 MiB | StatefulSets and PVCs; retain across ordinary Minikube stop/start |

**Storage decision:** `csi-hostpath-driver` is a **Minikube add-on**, as indicated by the `kubernetes.io/minikube-addons: csi-hostpath-driver` Pod template label and the `addonmanager.kubernetes.io/mode: Reconcile` label. It does not appear in `helm list`. The `aspecta-storage` Argo CD Application currently owns the **StorageClass only**, `aspecta-csi-wffc`. Keeping the CSI driver as a bootstrap prerequisite avoids a storage-dependency cycle during a new GitOps installation.

**Converged storage target (this PR):** `csi-hostpath-driver` must show **enabled** in `minikube addons list`, with `CSIDriver hostpath.csi.k8s.io` and CSI sidecars Ready. The legacy Minikube `storage-provisioner` and `default-storageclass` add-ons must show **disabled**. Our monitoring PVCs explicitly reference `aspecta-csi-wffc`; GitOps marks this as the **sole default** StorageClass for any new PVC that omits `storageClassName`. Existing `standard` or addon-created `csi-hostpath-sc` StorageClass objects may still be listed but are **not separate active provisioners**. The reconcile helper only demotes their default annotations; it does not delete them.

**Evidence before this patch:** both CSI and legacy Minikube storage addons were reported `disabled`, even while CSI Pods ran. The old `storage-provisioner` Pod was manually deleted and did not return; it is **not a Job**. That inconsistent state is the reason for the explicit reconciliation workflow. Do not claim that the addon is enabled on the live cluster until `bash scripts/aspecta-env.sh storage reconcile` succeeds. Enabling an addon may re-apply its manifests and briefly restart CSI Pods, so perform it during lab maintenance, not under production traffic.

### Storage classes observed before convergence

| StorageClass | Provisioner | Binding mode | Intended use |
| --- | --- | --- | --- |
| `aspecta-csi-wffc` | `hostpath.csi.k8s.io` | `WaitForFirstConsumer` | **Only Aspecta PVC choice**; GitOps-managed and default after reconciliation |
| `csi-hostpath-sc` | `hostpath.csi.k8s.io` | `Immediate` | Exists as CSI addon example class; demoted from default, not used by Aspecta PVCs |
| `standard` (historically default) | `k8s.io/minikube-hostpath` | `Immediate` | May remain as a legacy API object; no active legacy provisioner; its default annotation is demoted |

CSI HostPath is a **local development/testing driver**, not resilient multi-node or production storage. The data is tied to local Minikube node storage. Do not infer production durability from a `Bound` PVC.

## 2. Version snapshot (with provenance)

| Component | Version / reference | Evidence and important distinction |
| --- | --- | --- |
| Minikube CLI | `v1.38.1` | Observed in the local startup log; reviewer should run `minikube version` |
| Local Python CLI | *Verify locally* (`python --version` or `python3 --version`) | The CI promotion script is Python; a specific host Python interpreter version was not captured from the current run |
| Local Helm CLI | *Verify locally* (`helm version --short`) | The local Helm CLI version was not in the pasted evidence; `helm lint` is a check, **not a Helm version** |
| kubectl CLI / Git / Docker CLI | *Verify locally* | The host-side client tool versions may differ from the Minikube server/runtime versions |
| Kubernetes nodes | `v1.35.1` | Observed in `kubectl get nodes`; pinned in bootstrap |
| Container runtime inside Minikube | `Docker 29.2.1` | Reported by Minikube; **not necessarily Docker Desktop's own Engine version** |
| Argo CD Helm installation | `argo-cd-10.10.1`, app `v3.5.4` | Observed in `helm list -A` |
| Traefik Helm installation | `traefik-41.6.1`, app `v3.7.13` | Observed in `helm list -A`; bootstrap pins chart `41.6.1` |
| Aspecta chart in Git (desired state) | Chart `0.1.1`, metadata `appVersion: 0.1.0` | **Observed in `helm/aspecta/Chart.yaml`**. Git-sourced Argo CD uses current chart files, not the older Helm CLI release record. |
| Aspecta native Helm CLI release record | `aspecta-0.1.0`, app `0.1.0` | Observed in `helm list -A`; a separate historical Helm release record. **Do not confuse it with the Git chart version**. |
| Metrics Server Helm chart | `3.14.0` | **Observed in live Argo CD Application** and pinned for demo bootstrap |
| kube-prometheus-stack | `92.2.0` | **Observed in live multi-source Argo CD Application**; Git values source tracks `main` |
| Sealed Secrets controller Helm chart | `2.20.0` | **Observed in live Argo CD Application**; distinct from the app version |
| CSI HostPath driver | `hostpathplugin:v1.9.0` | Image version in DaemonSet **last-applied manifest**; the entire CSI addon version is bundled with the installed Minikube, not a Helm chart |
| CSI provisioner sidecar | `csi-provisioner:v3.3.0` | CSI DaemonSet last-applied manifest |
| CSI node registrar | `csi-node-driver-registrar:v2.6.0` | CSI DaemonSet last-applied manifest |
| CSI snapshotter | `csi-snapshotter:v6.1.0` | CSI DaemonSet last-applied manifest |
| CSI liveness sidecar | `livenessprobe:v2.8.0` | CSI DaemonSet last-applied manifest |
| Backend runtime base | `gcr.io/distroless/nodejs22-debian13:nonroot` | Backend Dockerfile reference; Node.js 22 family, non-root UID 1000 |
| Frontend build base | `node:22-alpine` | Multi-stage Dockerfile; build-only stage |
| Frontend runtime base | `nginxinc/nginx-unprivileged:stable-alpine` | Multi-stage Dockerfile; unprivileged web server |
| CI Helm CLI | `v3.21.2` | Explicit version used by workflow setup step in the reviewed CI configuration |
| GitOps image tag at last observed startup | `sha-e15e721956a10a8657296e3096b42245dffafa5d` | Observed for **both** frontend and backend Deployments; can change after a new CI promotion |

The Docker base references above use moving tags. For strictly reproducible builds, pin reviewed image digests; this lab currently relies on full-commit-SHA **tags** for published application images. A SHA-derived tag is a convenient release identifier, but a registry tag is not intrinsically immutable; use the OCI image digest when strict artifact immutability is required.

## 3. Capture the actual current versions

These commands are read-only. Run them from a shell configured for the `aspecta` context. They reveal both direct Helm releases and Helm charts rendered by Argo CD.

```bash
# Local tools and nodes
python --version || python3 --version  # The host interpreter may be named python3
helm version --short
minikube version
kubectl --context aspecta version --client
kubectl --context aspecta get nodes -o wide
docker version
git --version
gh --version  # optional: used for PR and Actions operations
argocd version --client  # optional: CLI may not be installed

# Direct Helm releases (Argo CD-rendered Helm charts are absent here)
helm --kube-context aspecta list -A

# Source-of-truth version for OUR Helm chart
cat helm/aspecta/Chart.yaml
# Helm lint is a validation operation, not a package-version identifier
helm lint ./helm/aspecta
helm template aspecta ./helm/aspecta -n aspecta-app --set observability.enabled=false > /tmp/aspecta-demo-rendered.yaml

# Show every Argo CD Application's source(s), including multi-source Helm charts
kubectl --context aspecta -n argocd get applications -o json > /tmp/aspecta-applications.json
python -c '
import json
with open("/tmp/aspecta-applications.json", encoding="utf-8") as f:
    items = json.load(f)["items"]
for item in sorted(items, key=lambda obj: obj["metadata"]["name"]):
    spec = item["spec"]
    sources = spec.get("sources") or [spec.get("source", {})]
    for source in sources:
        print(item["metadata"]["name"], "|", source.get("chart", "Git path"), "|", source.get("targetRevision", "?"), "|", source.get("repoURL", "?"))
'

# CSI add-on state and running image references
bash scripts/aspecta-env.sh storage status
# After merging the GitOps default-class change and reconciling:
bash scripts/aspecta-env.sh storage status --strict
minikube -p aspecta addons list | grep -E 'csi-hostpath-driver|storage-provisioner|default-storageclass'
kubectl --context aspecta get csidrivers
kubectl --context aspecta -n kube-system get ds csi-hostpathplugin \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" = "}{.image}{"\n"}{end}'

# Current backend/frontend images (desired state)
kubectl --context aspecta -n aspecta-app get deploy \
  -o custom-columns='NAME:.metadata.name,IMAGES:.spec.template.spec.containers[*].image'

# Resolved image IDs from running Pods (for digest/audit evidence)
kubectl --context aspecta -n aspecta-app get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.containerStatuses[*]}{.imageID}{"\n"}{end}{end}'

# PVCs and GitOps status
kubectl --context aspecta get pvc -A
kubectl --context aspecta -n argocd get applications
```

> On Windows Git Bash, ordinary kubectl file paths can be converted differently than on Linux/macOS. The scripts handle the **raw `/readyz` API call** specially. For the JSON file above, `/tmp` is provided by Git Bash; on Windows without Git Bash, use a native temporary path.

## 4. Storage reconciliation and verification

For the **existing full lab**, use this explicit maintenance sequence. Do not run the entire first-install bootstrap just to align addon ownership:

```bash
# Read-only preflight
kubectl --context aspecta get pvc -A
bash scripts/aspecta-env.sh storage status  # may report disabled CSI addon initially

# One-time, controlled infrastructure reconciliation (may update CSI Pods)
bash scripts/aspecta-env.sh storage reconcile

# Wait for the GitOps manifest change to reach main, then sync aspecta-storage.
bash scripts/aspecta-env.sh storage status --strict
bash scripts/aspecta-env.sh verify
```

A reviewer starting a **new full cluster** runs `aspecta-bootstrap.sh --mode full --phase infra`; the same storage reconciler is called before Traefik and before GitOps monitoring. The dedicated **demo** profile remains independent. Neither path deletes PV/PVC objects or migrates data. The CSI HostPath addon is still a local testing implementation, not a production EKS EBS equivalent.

## 5. Upgrade/change rules

- Update version pins through a reviewed PR; do not silently change a live component to make the numbers look newer.
- **Minikube/Calico/CSI/Traefik/initial Argo CD:** review/bootstrap responsibility. Upgrading these requires cluster-level validation, not just an application rollout.
- **Argo CD external charts:** adjust pinned `targetRevision` and values in Git, inspect Diff, test resource compatibility, and sync. Helm-rendered deployments are not shown by `helm list`.
- **Application code:** new image build -> Trivy -> GHCR -> GitOps image promotion -> Argo CD.
- **Helm templates/values:** PR -> lint/render -> Argo CD sync; may not require new images.
- **PVC/storage:** never delete PVCs or replace a StorageClass blindly; verify `reclaimPolicy`, `volumeBindingMode`, node affinity and data persistence.

See [Repository map and GitOps architecture](REPOSITORY-AND-GITOPS-MAP.md), [Change and release guide](CHANGE-AND-RELEASE-GUIDE.md), [CI/CD and development flow](CI-CD-AND-DEVELOPMENT-FLOW.md), and [Operations lifecycle](OPERATIONS-LIFECYCLE.md).
