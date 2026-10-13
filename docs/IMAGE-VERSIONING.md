# Aspecta – Image and Chart Versioning

> Quick reference for engineering tickets. Current implementation as of 2026-10-13; see [Change and Release Guide](CHANGE-AND-RELEASE-GUIDE.md) for detailed procedures.

## Four different identifiers

| Item | Current Aspecta convention | Meaning |
| --- | --- | --- |
| Backend container | `ghcr.io/jansoltys9/aspecta-backend:sha-<main-commit>` | Backend build from a specific merged Git revision. |
| Frontend container | `ghcr.io/jansoltys9/aspecta-frontend:sha-<main-commit>` | Separate frontend artifact; its release need not match the backend. |
| Helm chart | `helm/aspecta/Chart.yaml` → `version: 0.1.1` | Version of deployment templates/chart package, **not** a container version. |
| `Chart.yaml` `appVersion` | `0.1.0` | Informational metadata; **not** authoritative for two independently built components. |

**Current practice:** CI publishes SHA-tagged images; GitOps stores the desired image tags in `helm/aspecta/values.yaml`. An OCI digest (`sha256:...`) is the stronger, content-addressed artifact identity. Do not mistake the local Docker image ID for the Git commit or registry digest.

**Not implemented:** formal application SemVer / Git-tag release automation. Do not manually invent `v0.1.1` or `-rc` as if a release had been approved. Local `:local` is a disposable test label, not an artifact to deploy.

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

**Release rule:** build once in CI, scan, publish with traceable identity, promote the *same artifact* via GitOps, verify, and roll back by reverting the desired state in Git.
