# Aspecta – per-service SemVer release update

This package replaces only two existing files. It does not change your cluster directly.

## Install (Git Bash, from repository root)

1. Make sure `git status --short` is empty and you are on an up-to-date `main`.
2. Copy the two bundled files into the same paths in your repository.
3. Test:

```bash
python -m py_compile .github/scripts/promote-images.py
python .github/scripts/promote-images.py --owner jansoltys9 --component backend --tag v0.1.0 --dry-run | grep -A3 '^backend:'
helm lint ./helm/aspecta
helm template aspecta ./helm/aspecta -n aspecta-app >/tmp/aspecta-rendered.yaml
git diff --check
git diff -- .github/
```

4. Commit on a feature branch and open a PR. Main branch pushes now VALIDATE but DO NOT PUBLISH. Only release tags publish and promote.

## Release backend 0.1.0 (after PR is merged)

```bash
git switch main
git pull --ff-only origin main
git tag -l 'backend-v*'
git tag backend-v0.1.0
git push origin backend-v0.1.0
```

Check GitHub Actions: validation -> Trivy scans -> publish backend image -> promote only backend tag in Helm values. Argo CD watches `main` and syncs to Kubernetes. To release frontend independently, use `frontend-v0.1.0` (if not already taken).

## Check

```bash
kubectl --context aspecta -n argocd get application aspecta
kubectl --context aspecta -n aspecta-app rollout status deployment/aspecta-backend --timeout=180s
kubectl --context aspecta -n aspecta-app get deployment aspecta-backend -o jsonpath='{.spec.template.spec.containers[*].image}{"\n"}'
git pull --ff-only origin main
grep -A10 '^backend:' helm/aspecta/values.yaml
```

For next backend release: `backend-v0.1.1` (PATCH), `backend-v0.2.0` (MINOR), `backend-v1.0.0` (MAJOR). Do not force-move existing release tags. CI uses GitHub GITHUB_TOKEN; no personal GHCR token is needed. GHCR packages must be publicly readable for the reviewer quick demo, or reviewer needs imagePullSecrets.

**Important:** Repository permissions / branch protection must permit GitHub Actions to push the GitOps values update to `main`. Otherwise change the promotion to create a PR. This release requires tag names referring to already merged `main` commits. See actual repository docs for complete local bootstrap.
