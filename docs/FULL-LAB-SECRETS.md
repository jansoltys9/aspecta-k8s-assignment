# Full lab: Sealed Secrets on a new Minikube cluster

The **quick demo** does not require Sealed Secrets. `aspecta-bootstrap.sh --mode demo --phase app` creates a new Kubernetes Secret locally.

The **full GitOps lab** requires a SealedSecret encrypted for **the target cluster**. The encrypted manifest included in this repository was created with a different controller key and will not decrypt on a fresh cluster.

## Prerequisites

1. Fork/clone this repository and configure the Argo CD `repoURL` values **and AppProject `sourceRepos`** to reference your fork. Check with `git grep -n 'jansoltys9/aspecta-k8s-assignment' -- gitops`.
2. Bootstrap the full cluster, install the Sealed Secrets controller, and wait until it is ready. Ensure the `aspecta-app` namespace exists. Do not sync the application Secret from the original repository.
3. Install `kubeseal`, `kubectl`, and `openssl`; use your **own** cluster context.

## Generate and seal a fresh token

Run from the repository root in Git Bash or Linux Bash. These commands do not write a plaintext Secret manifest to disk.

```bash
# Select YOUR new full-cluster context; check carefully.
kubectl config current-context
kubectl -n sealed-secrets get svc

# Most installations of the pinned chart use the service name "sealed-secrets".
# If your controller service has another name, adjust --controller-name.
mkdir -p .local-secrets
umask 077
kubeseal --controller-name sealed-secrets \
  --controller-namespace sealed-secrets \
  --fetch-cert > .local-secrets/sealed-secrets-public.pem

openssl rand -hex 32 | tr -d '\r\n' > .local-secrets/internal-api-token
wc -c < .local-secrets/internal-api-token  # Expected: 64

set -o pipefail
kubectl -n aspecta-app create secret generic aspecta-backend-auth-gitops \
  --from-file=INTERNAL_API_TOKEN=.local-secrets/internal-api-token \
  --dry-run=client -o yaml \
  | kubeseal --cert .local-secrets/sealed-secrets-public.pem \
      --scope strict --format yaml \
  > gitops/secrets/aspecta-backend-auth-gitops.yaml
```

Check the encrypted file contains `kind: SealedSecret`, namespace `aspecta-app`, name `aspecta-backend-auth-gitops` and encrypted key `INTERNAL_API_TOKEN`. **Do not print or commit the token, plaintext Secret, or the controller's private key.** `.local-secrets/` must stay Git-ignored.

Commit **only the encrypted manifest** to your fork and let the `aspecta-secrets` child Application sync. Verify without displaying credentials:

```bash
kubectl -n aspecta-app get sealedsecret aspecta-backend-auth-gitops
kubectl -n aspecta-app get secret aspecta-backend-auth-gitops
kubectl -n aspecta-app rollout status deploy/aspecta-backend
```

If the Secret does not appear, check `kubectl -n aspecta-app describe sealedsecret aspecta-backend-auth-gitops` and the Sealed Secrets controller logs. A wrong controller certificate or mismatched name/namespace will prevent decryption.

**Scope note:** The `strict` encryption scope binds the encrypted data to its Secret name and namespace. Re-seal whenever using a different controller key or changing these fields.
