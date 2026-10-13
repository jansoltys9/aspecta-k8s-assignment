# Aspecta – Docker Image Build and Release

> Short runbook for **ASPECTA-OPS-01: Backend service identifier**. Source of truth: `.github/workflows/publish-images.yml`. **Developer pushes Git, CI publishes the registry image.** Never publish a locally built test image as an official release.

## 1. Developer checks (feature branch)

```bash
git status --short
git branch --show-current
node --check app/backend/server.js
git diff --check

docker build -t aspecta-backend:dev-backend-release-demo ./app/backend
TEST_TOKEN=$(openssl rand -hex 32)
docker run -d --rm --name aspecta-backend-dev-test \
  --read-only --cap-drop=ALL --security-opt=no-new-privileges \
  -e INTERNAL_API_TOKEN="$TEST_TOKEN" -p 127.0.0.1:18082:3000 \
  aspecta-backend:dev-backend-release-demo
curl -fsS http://127.0.0.1:18082/healthz
curl -fsS http://127.0.0.1:18082/api/hello
docker stop aspecta-backend-dev-test
unset TEST_TOKEN
```

For frontend changes, use e.g. `docker build -t aspecta-frontend:dev-frontend-feature ./app/frontend`; its **multi-stage build** uses Node.js for assets and unprivileged NGINX at runtime. Backend uses **distroless Node.js runtime**, so it does not gain much from an extra build stage while it has no compilation/dependencies. **Never commit the test token.**

## 2. Pull request – review and security gates

```bash
git add app/backend/server.js
git commit -m "feat(backend): add service identifier to hello response"
git push -u origin feat/backend-release-demo
gh pr create --base main --head feat/backend-release-demo \
  --title "ASPECTA-OPS-01: Add backend service identifier"
gh pr checks --watch
```

Review the diff and actual job results: change detection, application/Helm validation, Trivy HIGH/CRITICAL for the applicable images. **PR checks do not mean an image has been published.** The PR runner builds/scans from Git; it cannot see a developer laptop image. Merge only after passing required checks/review.

## 3. Main branch – release and GitOps

1. The eligible `main` push (including a squash merge) triggers `scan` and then `publish`. **Both jobs build from merged Git code; they are separate Docker builds today**. `publish` pushes `sha-<full-main-commit>` to GHCR. This is NOT a retag or upload of the developer's local `dev-*` image.
2. The promotion job commits desired image references to `helm/aspecta/values.yaml`.
3. Argo CD reconciles `aspecta`; Kubernetes performs a Deployment rollout.
4. Check the **actual workflow `if` filters**: currently `app/**` may publish *both* backend and frontend even for a backend-only change.

```bash
gh run list --branch main --limit 5
kubectl --context aspecta -n aspecta-app get deployment aspecta-backend \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl --context aspecta -n aspecta-app rollout status deployment/aspecta-backend --timeout=180s
kubectl --context aspecta -n argocd get application aspecta
```

Smoke-test `/api/hello` via the Traefik port-forward and confirm its new `service` field; check Prometheus `/metrics` target. Record the merged commit, GHCR tag/digest, promotion commit, Argo CD revision and test result in the ticket.

**CI hardening follow-up:** currently the image scanned by Trivy and the image pushed to GHCR come from separate builds. For true build-once/scanned-artifact integrity, scan the **exact artifact/digest** that will be promoted; keep deployment promotion separate from rebuilding.

**Rollback:** revert the GitOps image-reference change through a reviewed Git commit, let Argo CD reconcile, and re-run smoke tests. Avoid ad-hoc `kubectl set image` because it creates GitOps drift.
