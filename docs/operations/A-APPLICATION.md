# A – Mením aplikáciu alebo Dockerfile

**Použi, keď meníš:** `app/backend/`, `app/frontend/`, prípadne Dockerfile jednej služby.

**Výsledok:** nový Docker image **iba zmenenej služby**. GitHub Actions ho publikuje do GHCR, upraví Helm image tag a Argo CD nasadí.

## Príklad A1: opravím backend (`v0.1.0 → v0.1.1`)

### 1. Vyvinúť a odoslať opravu

```bash
git switch main
git pull --ff-only origin main
git switch -c fix/backend-small-fix

# Vo VS Code uprav app/backend/server.js a ulož súbor.
node --check app/backend/server.js
# Voliteľne: over lokálny Docker build (nič nepublikuje)
docker build -t aspecta-backend:local ./app/backend

git add app/backend/
git commit -m "fix(backend): correct API response"
git push -u origin fix/backend-small-fix
```

Na GitHube otvor **PR do `main`**, čakaj na zelené CI kontroly a daj **Squash and merge**.

### 2. Vydať novú verziu

```bash
git switch main
git pull --ff-only origin main
git log -6 --oneline
```

**Vyber SHA commitu so schválenou backend opravou po merge.** Nesmie ísť o automatický `chore(gitops)` commit s `[skip ci]`. V nasledujúcom príkaze nahraď `SEM_DAJ_SHA` skutočným SHA z `git log`.

```bash
RELEASE_COMMIT="SEM_DAJ_SHA"
git show -s --format='%h %s' "$RELEASE_COMMIT"
git tag -l 'backend-v*'
git tag -a backend-v0.1.1 "$RELEASE_COMMIT" -m "Release backend v0.1.1"
git push origin backend-v0.1.1
```

**Pozor:** `backend-v0.1.1` je príklad ďalšej verzie. Ak už existuje, zvoľ ďalšiu voľnú verziu. Nikdy existujúci release tag neposúvaj na nový commit. Tagovaný commit musí byť súčasťou `main` a obsahovať aktuálny release workflow.

### 3. Skontrolovať pipeline a nasadenie

```bash
gh run list --workflow publish-images.yml --limit 5
# Otvor posledný release run cez gh run view <RUN_ID> alebo GitHub Actions.

git pull --ff-only origin main
kubectl -n argocd get application aspecta
kubectl -n aspecta-app rollout status deployment/aspecta-backend --timeout=180s
kubectl -n aspecta-app get deployments aspecta-backend aspecta-frontend \
  -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image
```

**Očakávam:** backend `:v0.1.1`, frontend zostal `:v0.1.0`; Argo CD `Synced / Healthy`.

## Príklad A2: opravím frontend

Presne to isté, len:

- súbory: `app/frontend/`
- vetva: `fix/frontend-small-fix`
- release tag: `frontend-v0.1.1`
- kontrola rollout: `deployment/aspecta-frontend`

Napríklad pri ďalšom frontend PATCH release (po PR/merge a kontrole správneho commitu):

```bash
git tag -a frontend-v0.1.1 "$RELEASE_COMMIT" -m "Release frontend v0.1.1"
git push origin frontend-v0.1.1
```

Tu `RELEASE_COMMIT` nastav na SHA **frontend aplikačného commitu**, nie na starý backend release commit. Pred PR môžeš spustiť:

```bash
cd app/frontend
npm ci
npm run build
cd ../..
```

## Príklad A3: opravím iba Dockerfile

Príklad: bezpečnostná aktualizácia base image v `app/backend/Dockerfile`.

**Stále ide o novú verziu backend Docker image** (napr. `backend-v0.1.2`), hoci `server.js` sa nezmenil. Postup je identický s A1. CI musí nový image zbuildovať a oskenovať. Frontend nemeníš.

## Čo keď pipeline neprejde?

1. Pozri chybný krok v GitHub Actions (`gh run view RUN_ID --log-failed`).
2. Ak je chyba v kóde/Dockerfile, oprav ju v novej vetve a urob nový PR.
3. Pre opravený obsah vytvor **ďalší voľný release tag**. Už publikovanú verziu neprepíš.
4. Ak image existuje, ale Argo CD ho ešte nenasadilo, porovnaj image tag v `helm/aspecta/values.yaml` s bežiacim Deploymentom.

**Nikdy ručne nepúšťaj `docker push` pre štandardný release.** V Aspecta to robí GitHub Actions po release tagu.
