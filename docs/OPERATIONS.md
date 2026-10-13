# Operations: what are you changing?

**Pick one case.** Each guide has a branch name, an example, version rules, commands and checks. Commands run from the repository root in Git Bash.

| Case | Change | Branch example | Version change? | Guide |
|---|---|---|---|---|
| **A – App** | Backend/frontend code or Dockerfile | `fix/backend-response` | **Yes:** only that service | [A](operations/A-APPLICATION.md) |
| **B – CI** | GitHub Actions, Trivy, promotion script | `ci/update-checkout` | **No** app version | [B](operations/B-PIPELINE.md) |
| **C – Helm** | Requests, limits, probes, HPA, RBAC | `config/backend-memory` | **No** app version; chart version if chart is changed | [C](operations/C-HELM-GITOPS.md) |
| **D – Platform** | Argo CD, Traefik, monitoring, add-ons | `platform/monitoring-upgrade` | **Only** the affected add-on chart/version | [D](operations/D-PLATFORM.md) |

### Rules for every change

1. `git switch main && git pull --ff-only origin main`
2. Create your branch. Edit only related files. Run checks.
3. Commit → push → pull request (PR) → wait for checks → merge into `main`.
4. Check the live result. **Do not edit an Argo CD-managed Deployment by hand.**
5. Never commit a plaintext Secret. Never move/reuse an already published release tag.

**If a change needs several parts:** fix the pipeline first (B), introduce backward-compatible configuration or platform prerequisites (C/D), then release the app (A). Use separate PRs when possible.

### Quick check after a deployment

```bash
kubectl -n argocd get application aspecta
kubectl -n aspecta-app get deployment aspecta-backend aspecta-frontend \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image
kubectl -n aspecta-app get pods
```

Expect `Synced / Healthy` and the intended image tags. `Synced` does not replace an API/browser smoke test.
