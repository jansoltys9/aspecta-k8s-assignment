# Aspecta – čo mám urobiť, keď niečo mením?

**Začni tu.** Vyber si jednu z možností A/B/C/D. Nemusíš čítať ostatné návody.

| Chcem zmeniť... | Otvor | Nová verzia backend/frontend? | Kto nasadzuje? |
|---|---|---|---|
| Kód backendu, frontend, Dockerfile | [A – Aplikácia a Docker](operations/A-APPLICATION.md) | **Áno**, iba zmenená služba | GitHub Actions → GHCR → Argo CD |
| GitHub Actions, Trivy, release skript | [B – CI/CD pipeline](operations/B-PIPELINE.md) | **Nie** | PR a kontrola CI |
| Helm hodnoty, HPA, limity, Kubernetes šablóny | [C – Helm a GitOps](operations/C-HELM-GITOPS.md) | **Nie** (ak sa nemení aplikácia) | Argo CD |
| Argo CD, Traefik, monitoring a ďalšie addony | [D – Platforma](operations/D-PLATFORM.md) | **Nie** | Argo CD alebo Helm podľa správcu |

## Najdôležitejší príklad

Zmením iba `app/backend/server.js`:

1. Vytvorím vetvu `fix/backend-...` a upravím kód.
2. Vytvorím Pull Request (PR). CI ho otestuje.
3. Po merge vydám `backend-v0.1.1` na **aplikáčnom commite**, nie na GitOps commite s `[skip ci]`.
4. GitHub Actions vyrobí `ghcr.io/jansoltys9/aspecta-backend:v0.1.1`.
5. Pipeline sama zmení **iba** `backend.image.tag` v `helm/aspecta/values.yaml`.
6. Argo CD nasadí backend. Frontend zostáva bez zmeny.

Presné príkazy: **[A – Aplikácia a Docker](operations/A-APPLICATION.md)**.

## Ako čítať verzie

- `backend-v0.1.1` – release tag backendu (Git); Docker image má tag `v0.1.1`.
- `frontend-v0.1.0` – samostatný frontend release.
- `helm/aspecta/Chart.yaml: version` – verzia Helm chartu, **nie** backendu/frontend.
- `platform/traefik/CHART_VERSION` – pripnutá verzia Traefik Helm chartu.
- `gitops/apps/monitoring.yaml: targetRevision` – verzia monitorovacieho chartu.

**PATCH** (`0.1.0 → 0.1.1`) = fix / security rebuild. **MINOR** (`0.1.1 → 0.2.0`) = nová kompatibilná funkcia. **MAJOR** = veľká nekompatibilná zmena; pri `0.x` ju výslovne opíš v PR.

## Spoločné pravidlá (platia pre A, B, C, D)

1. Pracuj v koreňovom adresári `aspecta-k8s-assignment` a používaj Git Bash.
2. Pred novou prácou: `git switch main && git pull --ff-only origin main`.
3. **Zmena → vlastná vetva → PR → kontroly → merge**. Necommituj priamo do `main` (výnimkou je automatický GitOps promotion commit workflow).
4. **Aplikáciu riadi Argo CD**. Bežne nepoužívaj `kubectl edit` ani `helm upgrade aspecta`; Argo CD by zmeny mohlo vrátiť.
5. Tajomstvá nikdy neukladaj do Git repozitára ako obyčajné heslá ani plaintext Kubernetes Secret.
6. Neopakuj už publikovaný release tag s iným obsahom; pri ďalšom fixe zvýš verziu.

## Ak mením viac vecí naraz

**Jednoduché poradie:** B (prípadná oprava pipeline) → C/D (potrebná spätne kompatibilná konfigurácia) → A (aplikácia + SemVer release) → kontrola Argo CD. Každú nezávislú zmenu daj do vlastného PR.

## Rýchla kontrola nasadenia

```bash
kubectl -n argocd get application aspecta
kubectl -n aspecta-app get deployments aspecta-backend aspecta-frontend \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image
kubectl -n aspecta-app get pods
```

Výsledok: Argo CD `Synced / Healthy` a očakávané image tagy. Ak sú rozdielne, skontroluj `helm/aspecta/values.yaml`, posledný GitOps commit a aktuálnu revíziu Argo CD.

## Pozor: dve odlišné úlohy

- **Bežný update** – tento návod; infraštruktúra už beží.
- **Čisté spustenie pre reviewera** – samostatný inštalačný/demo návod, nie súčasť tohto rozcestníka.

Tieto postupy sú pripravené pre aktuálny Aspecta lab (GitHub Actions + GHCR + Argo CD + Minikube), nie ako univerzálny návod pre každý Kubernetes cluster.
