# C – Mením Helm alebo Kubernetes konfiguráciu

**Použi, keď meníš:** `helm/aspecta/values.yaml`, `helm/aspecta/templates/` alebo súvisiace GitOps manifesty.

**Výsledok:** Argo CD z Gitu aplikuje konfiguráciu. **Nový backend/frontend Docker image sa kvôli tomu nevytvára.**

## Príklad C1: zvýšim RAM limit backendu

Zmena `backend.resources.limits.memory` z `256Mi` na `384Mi`.

### 1. Úprava v samostatnej vetve

```bash
git switch main
git pull --ff-only origin main
git switch -c config/backend-memory

# Vo VS Code uprav helm/aspecta/values.yaml:
# backend -> resources -> limits -> memory: 384Mi
helm lint ./helm/aspecta
helm template aspecta ./helm/aspecta --namespace aspecta-app > /tmp/aspecta-rendered.yaml
git diff --check
git diff -- helm/aspecta/values.yaml
```

**Nemeň `backend.image.tag`:** ten riadi release pipeline z postupu A.

### 2. PR a merge

```bash
git add helm/aspecta/values.yaml
git commit -m "chore(helm): increase backend memory limit"
git push -u origin config/backend-memory
```

Na GitHube otvor PR, skontroluj CI/Helm a mergni do `main`.

### 3. Overenie

```bash
kubectl -n argocd get application aspecta
kubectl -n aspecta-app get deployment aspecta-backend \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}{"\n"}'
```

**Očakávam:** `384Mi` a Argo CD `Synced / Healthy`. Image tag backendu zostáva pôvodný.

## Príklad C2: mením Helm template

Napríklad upravíš readiness/liveness probes v `helm/aspecta/templates/backend-deployment.yaml`.

Postup je rovnaký ako C1, ale pri zmene **samotného chartu/šablóny** zváž zvýšenie `version` v `helm/aspecta/Chart.yaml` (napr. `0.1.0 → 0.1.1`).

`Chart.yaml appVersion` **nie je** spoločnou verziou backendu a frontendu. Tie zostávajú nezávislé.

## Príklad C3: potrebujem zmeniť tajomstvo

**Nepridávaj plaintext heslo do `values.yaml` ani Git repozitára.** V Aspecta sa GitOps secret spravuje cez **Sealed Secrets** (`gitops/secrets/`). Zmenu urob cez jeho existujúci bezpečný postup a over, že sa Secret obnovil. Nový app release je potrebný iba vtedy, keď sa mení aj aplikačný kód.

## Ak sa objaví problém

- Skontroluj `kubectl -n argocd get application aspecta` a `kubectl -n aspecta-app get pods`.
- Ak konfigurácia pokazí chod služby, **revertuj chybný Git commit cez PR**. Argo CD aplikuje opravený požadovaný stav.
- Nepoužívaj `kubectl edit deployment` ani `helm upgrade aspecta`: Argo CD tieto objekty riadi cez Git.
