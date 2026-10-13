# Aspecta documentation

**Start here.** Pick what you want to do; you do not need to read everything.

| I want to... | Open |
|---|---|
| Run the app on a new laptop (quick reviewer demo) | [First-time setup](BOOTSTRAP-MODES.md) |
| Start or stop my existing 3-node lab | [Daily use](OPERATIONS-LIFECYCLE.md) |
| Change code, CI, Helm or an add-on | [Operations: choose A/B/C/D](OPERATIONS.md) |
| Understand how a release reaches Kubernetes | [CI/CD flow](CI-CD-AND-DEVELOPMENT-FLOW.md) |
| See where components live | [Architecture and repository map](REPOSITORY-AND-GITOPS-MAP.md) |
| Check which versions mean what | [Versions](STACK-AND-VERSIONS.md) |
| Set up secrets in a *new full* GitOps lab | [Full-lab Sealed Secrets](FULL-LAB-SECRETS.md) |

The quick demo takes two bootstrap phases. The full GitOps lab is an **advanced, guided** setup and needs more RAM and a fresh Sealed Secret. Do not use full-lab commands to install a simple reviewer demo.

**Validated release example (13 Oct 2026):** backend `v0.1.0` and frontend `v0.1.0` were deployed; Argo CD reported `Synced / Healthy`. See live versions with the commands in [Versions](STACK-AND-VERSIONS.md).
