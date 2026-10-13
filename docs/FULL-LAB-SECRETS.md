# Sealed Secrets for a new full GitOps lab

**Skip this page for the quick demo.** The quick demo generates a local Kubernetes Secret. The full lab needs a *new* SealedSecret for **your controller's key**; the encrypted Secret in this repository is not portable to a fresh cluster.

1. Use your own repository/fork in Argo CD `repoURL` settings **and** AppProject `sourceRepos`.
2. Bootstrap the full cluster; install/sync the Sealed Secrets controller and create the `aspecta-app` namespace.
3. Install `kubeseal` and `openssl`, and verify the Kubernetes context.

```bash
kubectl config current-context  # Must be your intended full cluster.
kubectl -n sealed-secrets get svc
mkdir -p .local-secrets
umask 077
kubeseal --controller-name sealed-secrets \
  --controller-namespace sealed-secrets --fetch-cert \
  > .local-secrets/sealed-secrets-public.pem
openssl rand -hex 32 | tr -d '\r\n' > .local-secrets/internal-api-token
set -o pipefail
kubectl -n aspecta-app create secret generic aspecta-backend-auth-gitops \
  --from-file=INTERNAL_API_TOKEN=.local-secrets/internal-api-token \
  --dry-run=client -o yaml \
  | kubeseal --cert .local-secrets/sealed-secrets-public.pem \
      --scope strict --format yaml \
  > gitops/secrets/aspecta-backend-auth-gitops.yaml
```

If your controller Service name differs, change `--controller-name`. Confirm that the output is a `kind: SealedSecret` for `aspecta-app/aspecta-backend-auth-gitops`; do not print the token or commit plaintext. `.local-secrets/` is ignored by Git.

Commit **only** the encrypted manifest to your fork. Sync `aspecta-secrets`, then check:

```bash
kubectl -n aspecta-app get sealedsecret aspecta-backend-auth-gitops
kubectl -n aspecta-app get secret aspecta-backend-auth-gitops
kubectl -n aspecta-app rollout status deployment/aspecta-backend
```

If it does not decrypt, check `kubectl -n aspecta-app describe sealedsecret aspecta-backend-auth-gitops` and controller logs. Strict sealing binds encrypted data to the Secret's name and namespace.
