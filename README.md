# Aspecta Kubernetes Assignment

A small frontend/backend application deployed to Kubernetes, with security controls, autoscaling, monitoring, and a GitOps-based delivery pipeline.

## Design

```text
Developer -> GitHub Actions (build, validation, Trivy) -> GHCR images
                                        |
                              GitOps image promotion
                                        v
Git repository (Helm chart + values) -> Argo CD -> Kubernetes
                                             |
                                  Traefik Ingress
                                  /           \
                             Frontend       Backend (/api, /metrics)
                                             |
                                   Prometheus + Alertmanager
```

The application uses Kubernetes **Deployments**, **ClusterIP Services**, a **Traefik Ingress**, **ConfigMap**, **Secret**, namespace-scoped **RBAC**, **Calico NetworkPolicies**, and **CPU-based HPA** (1–2 replicas per application component). Pods run as non-root with resource limits and health probes.

The full lab adds **Argo CD App-of-Apps**, an application **AppProject**, **Sealed Secrets**, **Metrics Server**, and **Prometheus/Alertmanager** with CSI-backed persistent volumes. The full cluster has one control-plane node and two workers. This is a local demonstration, not production HA storage.

## Installation — quick demo

Prerequisites: **Docker Desktop**, **Minikube**, **kubectl**, **Helm**, **Git**, **Bash** (Git Bash on Windows is supported), and **OpenSSL**. Docker needs sufficient free memory; the bootstrap selects a suitable single-node profile based on available resources. Internet access is required for the initial image and chart downloads.

```bash
git clone https://github.com/jansoltys9/aspecta-k8s-assignment.git
cd aspecta-k8s-assignment

# Stage 1: Kubernetes, Calico, Traefik (no application yet)
bash scripts/aspecta-bootstrap.sh --mode demo --phase infra

# Stage 2: Metrics Server, locally generated Secret, application Helm release
bash scripts/aspecta-bootstrap.sh --mode demo --phase app
```

This demo uses the public GHCR images and a newly generated local authentication token. It **does not require the author's Sealed Secrets key**. Prometheus custom resources are disabled in demo mode.

## Usage and verification

Start an Ingress port-forward in a separate terminal:

```bash
kubectl --context aspecta-review -n traefik port-forward svc/traefik 18082:80
```

Open **http://127.0.0.1:18082/** and click **Call Backend API**, or test directly:

```bash
curl -f http://127.0.0.1:18082/
curl -f http://127.0.0.1:18082/api/hello
kubectl --context aspecta-review -n aspecta-app get deploy,pods,hpa
```

To stop the quick demo without deleting the cluster:

```bash
minikube stop -p aspecta-review
```

## Full GitOps lab (advanced)

For the full multi-node lab, use the same staged bootstrap:
For a new full GitOps cluster, see the [Sealed Secrets setup](docs/FULL-LAB-SECRETS.md).

```bash
bash scripts/aspecta-bootstrap.sh --mode full --phase infra
bash scripts/aspecta-bootstrap.sh --mode full --phase gitops
```

The `gitops` phase provides **guided Argo CD/App-of-Apps setup**; it does not automatically provision and sync every add-on on a brand-new cluster. New clusters require a **new SealedSecret encrypted using their controller's public certificate**. See [Bootstrap Modes](docs/BOOTSTRAP-MODES.md).

For an existing full lab, the helpers provide environment checks, startup/stop, diagnostics and UI port-forwarding:

```bash
bash scripts/aspecta-env.sh check
bash scripts/aspecta-env.sh --help
bash scripts/aspecta-uis.sh start
bash scripts/aspecta-uis.sh status
```

## Build and CI/CD

The source Dockerfiles are in `app/backend/` and `app/frontend/`. Local verification:

```bash
docker build -t aspecta-backend:dev ./app/backend
docker build -t aspecta-frontend:dev ./app/frontend
helm lint ./helm/aspecta
helm template aspecta ./helm/aspecta -n aspecta-app --set observability.enabled=false
```

GitHub Actions (`.github/workflows/publish-images.yml`) validates the source and Helm chart, scans images with **Trivy**, publishes versioned images to **GHCR**, and promotes approved image references in Git. Argo CD reconciles Helm-generated Kubernetes manifests with the repository. The application Helm chart remains in Git; no separate chart registry is required.

**Scope:** The single-node demo is not highly available. The full lab uses local CSI Hostpath storage and local port-forwarding; production deployments require managed storage, appropriate TLS, protected release branches and operational access controls.
