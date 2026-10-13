# B – CI/CD pipeline change

**Use this for:** `.github/workflows/publish-images.yml` or `.github/scripts/promote-images.py`.

**Result:** better automation, **no** backend/frontend SemVer bump, and **no** application image published just because the pipeline changed.

## Example B1: update a GitHub Action

For example, replace `actions/checkout@v4` with `actions/checkout@v5` after checking compatibility.

```bash
git switch main
git pull --ff-only origin main
git switch -c ci/update-checkout
# Edit .github/workflows/publish-images.yml.
git diff --check
git diff -- .github/workflows/publish-images.yml
git add .github/workflows/publish-images.yml
git commit -m "ci: update checkout action"
git push -u origin ci/update-checkout
```

Open PR → check validation and Trivy → merge. On a PR, the publish and GitOps promotion jobs should be **skipped**.

```bash
gh run list --workflow publish-images.yml --limit 5
```

**Version:** neither application version nor Helm chart version changes. The next release tag will use the new pipeline if its tagged commit includes this workflow update.

## Example B2: fix GitOps promotion

Branch `ci/fix-image-promotion`; edit `.github/scripts/promote-images.py`. Before opening the PR:

```bash
python -m py_compile .github/scripts/promote-images.py
python .github/scripts/promote-images.py \
  --owner jansoltys9 --component backend --tag v0.1.1 --dry-run
python .github/scripts/promote-images.py \
  --owner jansoltys9 --component frontend --tag v0.1.1 --dry-run
helm lint ./helm/aspecta
```

`--dry-run` prints a proposed change only. No Git commit or cluster change occurs. Review both components; test the actual release path later with an intentional **new** app version, not by reusing an old tag.

**If a PR check fails:** fix the same branch and push another commit. Do not make a fake app release to test an ordinary CI edit.
