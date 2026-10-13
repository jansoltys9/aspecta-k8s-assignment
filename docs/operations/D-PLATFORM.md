# D – Mením platformu alebo addony

**Použi, keď meníš:** Argo CD, Traefik, monitoring, Sealed Secrets alebo iné platform komponenty.

**Zlaté pravidlo:** najskôr zisti, **kto danú službu spravuje**. Niektoré addony sleduje Argo CD; napr. Traefik a samotný Argo CD boli v tomto labe nasadené samostatným Helm release.

## Príklad D1: update monitoringu (spravuje Argo CD)

Napríklad chceš aktualizovať `kube-prometheus-stack` Helm chart.

### 1. Príprava

```bash
git switch main
git pull --ff-only origin main
git switch -c platform/monitoring-update

# Otvor gitops/apps/monitoring.yaml.
# V zdroji chartu zmeň targetRevision zo súčasnej verzie
# na novú, OVERENÚ kompatibilnú verziu (nie na "latest").
git diff --check
git diff -- gitops/apps/monitoring.yaml
```

Pred zmenou si prečítaj release notes nového chartu. Ak vyžaduje CRD/migráciu, rieš ju podľa dokumentácie – nepreskakuj.

### 2. PR → merge → kontrola

```bash
git add gitops/apps/monitoring.yaml
git commit -m "chore(platform): update monitoring chart"
git push -u origin platform/monitoring-update
```

Na GitHube vytvor PR a merge. Potom:

```bash
kubectl -n argocd get application aspecta-monitoring
kubectl -n monitoring get pods
```

**Očakávam:** monitoring je `Synced / Healthy`, pody bežia. **Žiadny nový app image tag.**

## Príklad D2: update Traefik (samostatný Helm)

Verzia chartu je v `platform/traefik/CHART_VERSION`; nastavenia v `platform/traefik/values-minikube.yaml`.

1. Zisti aktuálny stav: `helm -n traefik history traefik` a `cat platform/traefik/CHART_VERSION`.
2. Pozri release notes a kompatibilitu novej verzie (najmä CRD). Zmeň `CHART_VERSION` v samostatnej vetve → PR → merge.
3. Po merge a `git pull` vykonaj **plánovanú Helm aktualizáciu**, iba ak Traefik nespravuje Argo CD:

```bash
helm repo update
helm template traefik traefik/traefik --namespace traefik \
  --version "$(cat platform/traefik/CHART_VERSION)" \
  -f platform/traefik/values-minikube.yaml > /tmp/traefik-rendered.yaml

# Toto už reálne mení cluster – až po kontrole a schválení upgrade:
helm upgrade traefik traefik/traefik -n traefik \
  --version "$(cat platform/traefik/CHART_VERSION)" \
  -f platform/traefik/values-minikube.yaml --wait
kubectl -n traefik get pods
kubectl -n aspecta-app get ingress
```

**Pozor:** pri upgrade chartov s CRD môže byť potrebný samostatný CRD krok; `helm upgrade` ich sám vždy neaktualizuje. Nepúšťaj ho bez kontroly release notes.

## Príklad D3: update Argo CD

Samotný Argo CD má samostatný Helm release, pripnutý cez `platform/argocd/CHART_VERSION`. Postup: release notes → zmena pripnutej verzie vo vetve → PR → merge → schválený upgrade. Po merge:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm template argocd argo/argo-cd -n argocd \
  --version "$(cat platform/argocd/CHART_VERSION)" \
  -f platform/argocd/values-minikube.yaml > /tmp/argocd-rendered.yaml

# Reálny upgrade len po kontrole kompatibility, CRD a schválení:
helm upgrade argocd argo/argo-cd -n argocd \
  --version "$(cat platform/argocd/CHART_VERSION)" \
  -f platform/argocd/values-minikube.yaml --wait
kubectl -n argocd get pods,applications
```

Argo CD upgrade rob opatrne: ovplyvňuje celý GitOps proces. Ak release notes vyžadujú migráciu alebo CRD krok, najskôr vykonaj ten.

## Kedy zvýšim verziu?

- Mení sa `kube-prometheus-stack` → jeho **Helm chart targetRevision**.
- Mení sa Traefik → `platform/traefik/CHART_VERSION`.
- Mení sa Argo CD → `platform/argocd/CHART_VERSION`.
- Backend/frontend SemVer pri týchto zmenách **nemením**.

**Dôležité:** bežná GitHub Actions pipeline zameraná na `app/` a `helm/` nemusí pri zmene iba `gitops/` alebo `platform/` vôbec bežať. Pri platform upgrade sa preto nespoliehaj len na zelený PR – vykonaj uvedené kontroly osobitne.

## Ak upgrade nefunguje

- Pri Argo CD spravovanom addone sprav **revert cez PR** a over synchronizáciu.
- Pri samostatnom Helm release najskôr pozri `helm history -n <namespace> <release>`; prípadný `helm rollback` musí byť schválený a potom zosúlaď aj uloženú verziu v Gite.
- Pri nekompatibilných CRD alebo databázových zmenách nemusí stačiť jednoduchý rollback; riaď sa release notes.
