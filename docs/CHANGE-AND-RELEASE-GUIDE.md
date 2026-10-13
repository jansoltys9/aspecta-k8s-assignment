# Changes and release versions

**For step-by-step commands, start with [Operations A/B/C/D](OPERATIONS.md).** This page only explains the version rules so you can choose the right one.

| If you change... | Branch example | What gets a new version? |
|---|---|---|
| Backend logic | `fix/backend-response` | Backend: `v0.1.0 → v0.1.1` |
| Frontend feature | `feat/frontend-search` | Frontend: next `MINOR` release |
| Backend Dockerfile/base image | `fix/backend-base-image` | Backend: new PATCH image release |
| Workflow / Trivy / promotion script | `ci/update-checkout` | **Nothing** in the application |
| Memory limits in `values.yaml` | `config/backend-memory` | No app or chart bump for routine values |
| Helm template | `chart/backend-readiness` | Helm `Chart.yaml: version` (usually PATCH) |
| Monitoring/Traefik/Argo CD chart | `platform/monitoring-upgrade` | Only the selected third-party chart pin |
| Docs | `docs/simplify-guides` | No runtime version |

### Three different version numbers

- **Application:** Git tags `backend-vX.Y.Z`, `frontend-vX.Y.Z`; GHCR images use `vX.Y.Z`.
- **Our Helm chart:** `helm/aspecta/Chart.yaml` → `version`; template/packaging contract, **not** an app image.
- **Platform charts:** `gitops/apps/*.yaml` → Helm `targetRevision`, or `platform/{traefik,argocd}/CHART_VERSION`.

`Chart.yaml appVersion` is informational and cannot represent the two independent app versions.

**SemVer shortcuts:** PATCH = fix/security rebuild; MINOR = compatible feature; MAJOR = incompatible change (document breaking changes explicitly while in the `0.x` series).

**Best habit:** change → branch → PR → validation → merge → deploy → verify. For an app release, create the version tag **after merge** on the intended app commit, never on the `chore(gitops)` bot commit. Do not move existing release tags.
