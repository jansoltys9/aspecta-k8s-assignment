# Aspecta – quick start and staged demo

## Requirements

Docker Desktop (Linux containers), Git Bash or Bash, Minikube, kubectl, Helm and OpenSSL. An internet connection is needed to download Kubernetes components, public container images and Helm charts. The bootstrap checks Docker memory: **demo** needs at least ~4 GiB available to Docker (>=7 GiB recommended); **full** needs at least ~8 GiB. No specific `.wslconfig` is required for demo mode.

## Demo: one node

```bash
bash scripts/aspecta-bootstrap.sh --mode demo --phase infra
# Explain the node, CNI and Traefik. No application is running yet.
bash scripts/aspecta-bootstrap.sh --mode demo --phase app
# Installs Metrics Server and the app, creates a fresh local Secret.
```

In a second terminal:

```bash
kubectl --context aspecta-review -n traefik port-forward svc/traefik 18082:80
```

Check `http://127.0.0.1:18082/` and `http://127.0.0.1:18082/api/hello` (HTTP 200 expected). Stop with `minikube stop -p aspecta-review`. This quick demo does **not** include Argo CD, Prometheus or multi-node failover.

## Full lab: three nodes

Stop demo first if your laptop has limited RAM.

```bash
bash scripts/aspecta-bootstrap.sh --mode full --phase infra
# Explain 1 control plane + 2 workers, Calico, Traefik.
bash scripts/aspecta-bootstrap.sh --mode full --phase gitops
# One-time Argo CD setup guidance; then apply root Application.
```

The GitOps phase deliberately does **not** auto-sync all applications: demonstrate Argo CD root/child Applications step by step. A new cluster must reseal its application Secret with its **own** Sealed Secrets controller key before deploying the protected backend. The ciphertext from the original lab is not portable.

## Other helpers

- `bash scripts/aspecta-env.sh check|start|doctor|stop` – daily full-lab operations on an existing profile. Its `bootstrap` command is a **daily resume** operation, not first-time provisioning.
- `bash scripts/aspecta-uis.sh start|open|status|stop` – UI port-forwards for the **full** lab. Use the manual Traefik port-forward above for demo.
- Image builds, Trivy scanning and registry publishing are separate **CI/CD** steps. Neither bootstrap mode builds an image.

No bootstrap command deletes a Minikube profile, Kubernetes Secret or PVC, and there is no single `all` command.
