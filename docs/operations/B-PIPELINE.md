# B – Mením CI/CD pipeline

**Použi, keď meníš:** `.github/workflows/publish-images.yml` alebo `.github/scripts/promote-images.py`.

**Výsledok:** opravíš automatizáciu. **Nevytváraš** kvôli tomu nový release tag backendu/frontend.

## Príklad: aktualizujem GitHub Action

Príklad: `actions/checkout@v4` → `actions/checkout@v5` (po overení kompatibility).

### 1. Pracovná vetva a úprava

```bash
git switch main
git pull --ff-only origin main
git switch -c ci/update-checkout

# Vo VS Code otvor .github/workflows/publish-images.yml,
# uprav zvolenú Action, ulož súbor.
git diff --check
git diff -- .github/workflows/publish-images.yml
```

### 2. Pull Request

```bash
git add .github/workflows/publish-images.yml
git commit -m "ci: update checkout action"
git push -u origin ci/update-checkout
```

Na GitHube otvor **PR do `main`**, počkaj na CI testy a merge.

### 3. Overenie

```bash
gh run list --workflow publish-images.yml --limit 5
```

**Očakávam:** validácia a Trivy prejdú. `Publish release to GHCR` a `Promote ... to GitOps` majú byť pre PR/obyčajný `main` push **Skipped**.

### Verzia?

- Backend: bez zmeny.
- Frontend: bez zmeny.
- Helm values: bez zmeny.
- **Novú pipeline použije ďalší app release**.

## Príklad: opravím skript GitOps promotion

Zmením `.github/scripts/promote-images.py`. Použijem ten istý postup B. Lokálne testy pred PR:

```bash
python -m py_compile .github/scripts/promote-images.py
python .github/scripts/promote-images.py \
  --owner jansoltys9 --component backend --tag v0.1.1 --dry-run \
  | grep -A11 '^backend:'
helm lint ./helm/aspecta
```

`--dry-run` iba zobrazí návrh zmeny Helm values – neupraví cluster. **Pri zásahu do promotion skriptu over aj frontend prípad.**

## Ak CI zlyhá

Oprav tú istú pracovnú vetvu, pushni ďalší commit, pozri novú CI kontrolu. **Nevytváraj release tag** na testovanie samotnej úpravy pipeline.

**Poznámka:** GitOps bot vytvára commity s `[skip ci]`. Release tagy preto vytváraj na schválených aplikačných commitoch (postup A), nie na bot commitoch.
