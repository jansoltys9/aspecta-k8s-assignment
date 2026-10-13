# Aspecta – Image and Chart Versioning

> Quick reference for engineering tickets. Current implementation as of 2026-10-13; see [Change and Release Guide](CHANGE-AND-RELEASE-GUIDE.md) for detailed procedures.

## Concrete example: developer image vs. GHCR image

This is the actual workflow for ticket **ASPECTA-OPS-01**, not an abstract naming scheme.

| Stage | Example | Who creates it? | Goes to GHCR? |
| --- | --- | --- | --- |
| Developer build | `aspecta-backend:dev-backend-release-demo` | Developer, on a laptop | **No** |
| PR validation | Temporary image built from PR source | GitHub Actions CI | **No** (current workflow) |
| Merged `main` build | `ghcr.io/jansoltys9/aspecta-backend:sha-<merged-main-commit>` | GitHub Actions release job | **Yes** |
| Kubernetes deployment | Image tag selected in `helm/aspecta/values.yaml` | GitOps promotion and Argo CD | Pulls from GHCR |

**Example – build on the developer machine (before committing):**

```bash
git switch feat/backend-release-demo
docker build -t aspecta-backend:dev-backend-release-demo ./app/backend
docker image ls aspecta-backend
# Run smoke tests locally; do not docker push.
```

The `dev-<branch-name>` tag is just a readable **working label**. Rebuilding with the same tag moves that local label to the newest test image; it is not a numbered product version. If reproducibility of a local build matters, first commit the source and build from a **clean** worktree; then a tag such as `dev-<short-commit>` may be used for local reference.

**Example – developer pushes Git source, not the Docker image:**

```bash
git add app/backend/server.js
git commit -m "feat(backend): add service identifier to hello response"
git push -u origin feat/backend-release-demo
# Create a Pull Request to main; do not run docker push.
```

**What happens next:** PR CI rebuilds an image **from the Git commit** and validates/scans it. After review and a squash merge, `main` has a **new commit SHA**. The release pipeline builds from that revision and tags the published image `sha-<full-main-commit>`. Its separate `scan` job builds an image for Trivy, and its `publish` job builds again before pushing to GHCR. **Important limitation:** the scan gates publishing, but it does not scan the exact pushed digest. For stricter artifact integrity, improve the pipeline to build once, scan the same artifact/digest, then publish or promote it unchanged. Neither job receives or re-tags the image from the developer's laptop. Finally, GitOps changes the backend image reference and Argo CD rolls out the Deployment.

**Official SemVer** such as `v0.2.0` would be a separately approved release identifier, normally created by a Git tag/release pipeline and optionally applied to the **same already-published image digest**. This is not yet automated in Aspecta.

## Four different identifiers

| Item | Current Aspecta convention | Meaning |
| --- | --- | --- |
| Backend container | `ghcr.io/jansoltys9/aspecta-backend:sha-<main-commit>` | Backend build from a specific merged Git revision. |
| Frontend container | `ghcr.io/jansoltys9/aspecta-frontend:sha-<main-commit>` | Separate frontend artifact; its release need not match the backend. |
| Helm chart | `helm/aspecta/Chart.yaml` → `version: 0.1.1` | Version of deployment templates/chart package, **not** a container version. |
| `Chart.yaml` `appVersion` | `0.1.0` | Informational metadata; **not** authoritative for two independently built components. |

**Current practice:** CI publishes SHA-tagged images; GitOps stores the desired image tags in `helm/aspecta/values.yaml`. An OCI digest (`sha256:...`) is the stronger, content-addressed artifact identity. Do not mistake the local Docker image ID for the Git commit or registry digest.

**Not implemented:** formal application SemVer / Git-tag release automation. Do not manually invent `v0.1.1` or `-rc` as if a release had been approved. Developer `dev-*` image tags are **temporary local test labels**, never official release versions.

## Which version changes?

| Change | New container image? | Helm values? | Helm chart version? |
| --- | --- | --- | --- |
| Backend source | Backend should change | Backend image reference promoted by CI | No |
| Frontend source | Frontend should change | Frontend image reference promoted by CI | No |
| Image rollback/promotion | No rebuild | Revert/change relevant image reference | No |
| HPA, resources, or other values | No | Yes | Normally no for Git-sourced chart |
| Helm template/chart package | No, unless app also changed | If necessary | Bump when intentionally releasing a new chart package |
| CI workflow only | No app release required | Normally no | No |
| Monitoring / add-on upgrade | Not our app images | Platform values if necessary | Bump add-on chart `targetRevision`, independently |

**Current limitation:** the existing workflow uses an `app/**` change detector and a backend/frontend matrix. A backend-only edit may build/publish **both** images; that is not independent artifact release selection. Separate per-component path filters would be a worthwhile follow-up, but are not part of ASPECTA-OPS-01.

## One chart or two?

Today `helm/aspecta/` deploys **two Deployments using two image references**. One chart is appropriate while they are released and managed as one product. Split into backend/frontend charts and Argo CD Applications only when independent deployment, approvals, ownership, or rollback justify the extra complexity.

**Release rule:** the PR validation build is separate from the build after a squash merge. Today `scan` and `publish` rebuild separately from the same `main` commit; this is an **identified CI hardening gap**, not a guaranteed build-once-scan-exact-digest process. GitOps then promotes the **published image without rebuilding it** across environments. Verify and roll back by reverting desired state in Git.
