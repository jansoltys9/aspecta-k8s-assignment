#!/usr/bin/env bash
# Aspecta local platform lifecycle helper (Windows Git Bash / Minikube Docker driver).
# Commands: check (read-only), start, bootstrap, doctor, flow, uis, stop.
# Does not destroy the cluster, delete PVCs, or auto-sync Argo CD.
set -Eeuo pipefail

PROFILE="${ASPECTA_PROFILE:-aspecta}"
CONTEXT="${ASPECTA_CONTEXT:-aspecta}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UI_HELPER="$SCRIPT_DIR/aspecta-uis.sh"
NODE_BOOTSTRAP="$REPO_ROOT/platform/bootstrap/label-workers.sh"

section() { printf '\n%s\n' "==== $* ===="; }
ok()      { printf '[OK] %s\n' "$*"; }
warn()    { printf '[WARN] %s\n' "$*"; }
info()    { printf '[INFO] %s\n' "$*"; }
fail()    { printf '[ERROR] %s\n' "$*" >&2; }
has()     { command -v "$1" >/dev/null 2>&1; }
k()       { kubectl --context "$CONTEXT" --request-timeout=10s "$@"; }

usage() {
  cat <<'USAGE'
Aspecta – local Kubernetes platform (Git Bash / Windows 11)

  bash scripts/aspecta-env.sh check       Read-only health, statistics and next steps
  bash scripts/aspecta-env.sh start       Start EXISTING Minikube profile; then check
  bash scripts/aspecta-env.sh bootstrap   Start + restore node labels + check + GitOps guide
  bash scripts/aspecta-env.sh doctor      Extended read-only diagnostics (events, allocations)
  bash scripts/aspecta-env.sh flow        Show ordered daily bootstrap and shutdown flow
  bash scripts/aspecta-env.sh uis start   Delegate to aspecta-uis.sh start|open|status|stop|logs
  bash scripts/aspecta-env.sh stop        Stop local UI forwards + Minikube (no delete)

No command automatically applies application YAML, runs a destructive command,
or forces an Argo CD synchronization.
USAGE
}

# Query only. Stopped Minikube profiles can return a non-zero exit code, so
# we also inspect the text while reporting status.
minikube_state() {
  minikube -p "$PROFILE" status 2>&1 || true
}

minikube_profile_exists() {
  local profiles
  profiles="$(minikube profile list --output=json 2>/dev/null || true)"
  [[ -n "$profiles" ]] && printf '%s\n' "$profiles" | grep -Eq '"Name"[[:space:]]*:[[:space:]]*"'"$PROFILE"'"'
}

docker_healthy() {
  has docker && docker info >/dev/null 2>&1
}

kube_healthy() {
  has kubectl && k get --raw='/readyz' >/dev/null 2>&1
}

show_nodes_and_slots() {
  section 'Kubernetes nodes and workload placement'
  k get nodes -L workload-tier,aspecta.io/pool || return 0

  local nodes pods node maximum used phase
  nodes="$(k get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.status.allocatable.pods}{"\n"}{end}' 2>/dev/null || true)"
  pods="$(k get pods -A -o jsonpath='{range .items[*]}{.spec.nodeName}{"|"}{.status.phase}{"\n"}{end}' 2>/dev/null || true)"
  if [[ -n "$nodes" ]]; then
    printf '\n%-17s %8s %8s %8s\n' 'NODE' 'PODS' 'MAX' 'SLOTS'
    while IFS='|' read -r node maximum; do
      [[ -n "$node" && "$maximum" =~ ^[0-9]+$ ]] || continue
      used="$(printf '%s\n' "$pods" | awk -F '|' -v n="$node" '$1==n && $2!="Succeeded" && $2!="Failed" {count++} END {print count+0}')"
      printf '%-17s %8d %8d %8d\n' "$node" "$used" "$maximum" "$(( maximum-used ))"
    done <<< "$nodes"
    info 'SLOTS = max. počet Podov, nie voľná RAM/CPU. Pre RAM pozri Docker stats a requests.'
  fi
}

show_docker() {
  section 'Docker Desktop / WSL2'
  if ! has docker; then
    warn 'Docker CLI nie je v PATH. Nainštaluj/spusti Docker Desktop.'
    return 1
  fi
  if ! docker_healthy; then
    warn 'Docker daemon neodpovedá. Zapni Docker Desktop a počkaj na stav Engine running.'
    info 'Potom: bash scripts/aspecta-env.sh start'
    return 1
  fi
  ok 'Docker daemon odpovedá.'
  local di
  di="$(docker info --format 'CPU={{.NCPU}}  DockerRAMbytes={{.MemTotal}}' 2>/dev/null || true)"
  [[ -n "$di" ]] && printf '%s\n' "$di"
  printf '\n%-16s %-24s\n' 'NODE' 'ACTUAL MEMORY / LIMIT'
  docker stats --no-stream --format '{{.Name}}|{{.MemUsage}}|{{.CPUPerc}}' \
    "$PROFILE" "${PROFILE}-m02" "${PROFILE}-m03" 2>/dev/null \
    | while IFS='|' read -r name mem cpu; do
        [[ -n "$name" ]] && printf '%-16s %-24s CPU %s\n' "$name" "$mem" "$cpu"
      done || true
  info 'Docker container memory limits nie sú Kubernetes requests/limits; scheduler môže vidieť inú kapacitu.'
}

show_cluster() {
  section 'Minikube profile'
  if ! has minikube; then
    warn 'Minikube nie je v PATH.'
    return 1
  fi
  local state
  state="$(minikube_state)"
  printf '%s\n' "$state"
  if [[ "$state" == *'host: Stopped'* ]]; then
    warn "Profil '$PROFILE' je vypnutý. Spustenie: bash scripts/aspecta-env.sh start"
    return 1
  fi
  if ! kube_healthy; then
    warn "Kubernetes API zatiaľ nie je pripravené na kontexte '$CONTEXT'."
    info 'Po čerstvom štarte počkaj 1–3 minúty a zopakuj check.'
    return 1
  fi
  ok "API Server ready (context '$CONTEXT')."
  return 0
}

show_argo() {
  section 'GitOps – Argo CD'
  if ! k get ns argocd >/dev/null 2>&1; then
    warn 'Namespace argocd neexistuje. Potrebná počiatočná inštalácia Argo CD.'
    return 0
  fi
  k -n argocd get applications || true
  local app sync health
  for app in aspecta-root aspecta aspecta-metrics-server aspecta-monitoring aspecta-storage aspecta-secrets sealed-secrets-controller; do
    sync="$(k -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health="$(k -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [[ -z "$sync" ]]; then
      warn "Argo Application '$app' chýba."
    elif [[ "$sync" != Synced ]]; then
      warn "$app: $sync / ${health:-unknown}; skontroluj Diff, potom manuálny Sync cez Argo UI."
    elif [[ "$health" == Degraded || "$health" == Missing ]]; then
      warn "$app: Synced / $health; skontroluj detaily v Argo CD."
    elif [[ "$health" == Progressing && "$app" == aspecta ]]; then
      info 'aspecta: Synced / Progressing môže byť Ingress bez LB statusu; over služby a Pody.'
    fi
  done
  if ! k -n argocd get application aspecta-root >/dev/null 2>&1; then
    info 'Počiatočný root bootstrap (iba ak Argo CD už beží):'
    info "  kubectl --context $CONTEXT apply -f gitops/bootstrap/aspecta-root.yaml"
  fi
}

show_runtime() {
  section 'Application / HPA / placement'
  k -n aspecta-app get deploy,pods,hpa -o wide 2>/dev/null || warn 'aspecta-app resources zatiaľ nie sú dostupné.'
  section 'Monitoring / PVC / storage'
  k -n monitoring get pods,pvc -o wide 2>/dev/null || warn 'monitoring resources zatiaľ nie sú dostupné.'
  local binding
  binding="$(k get storageclass aspecta-csi-wffc -o jsonpath='{.volumeBindingMode}' 2>/dev/null || true)"
  if [[ "$binding" == WaitForFirstConsumer ]]; then
    ok 'StorageClass aspecta-csi-wffc = WaitForFirstConsumer.'
  else
    warn "StorageClass aspecta-csi-wffc: ${binding:-missing} (očakávame WaitForFirstConsumer)."
  fi
}

show_metrics() {
  section 'Utilization – Metrics Server'
  local api
  api="$(k get apiservice v1beta1.metrics.k8s.io -o jsonpath='{range .status.conditions[?(@.type=="Available")]}{.status}{end}' 2>/dev/null || true)"
  if [[ "$api" == True ]]; then
    ok 'Metrics API Available=True'
    k top nodes 2>/dev/null || warn 'Metrics API je dostupné, ale metriky ešte nenabehli.'
    k -n aspecta-app top pods 2>/dev/null || true
  else
    warn "Metrics API: ${api:-missing}; HPA CPU potrebuje Metrics Server."
    info 'Argo CD: aspecta-root → Refresh/Sync → aspecta-metrics-server.'
  fi
}

show_local() {
  section 'Local helper and Git'
  if [[ -f "$UI_HELPER" ]]; then
    bash "$UI_HELPER" status || true
    info 'Web UI: bash scripts/aspecta-env.sh uis start'
    info 'Open:   bash scripts/aspecta-env.sh uis open'
  else
    info 'UI helper nie je v scripts/. Očakávaný súbor: scripts/aspecta-uis.sh'
  fi
  if has git && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Branch: %s\n' "$(git -C "$REPO_ROOT" branch --show-current)"
    info 'Local modifications (names only):'
    git -C "$REPO_ROOT" status --short || true
  fi
}

show_next() {
  section 'NEXT – daily bootstrap flow'
  printf '%s\n' \
    '1. Docker Desktop vypnutý? Otvor ho a počkaj na Engine running.' \
    '2. Cluster vypnutý? bash scripts/aspecta-env.sh start' \
    '3. Obnova labels/check: bash scripts/aspecta-env.sh bootstrap' \
    '4. Ak Argo root = OutOfSync: otvor Argo CD → aspecta-root → Diff → Sync (bez Force/Prune).' \
    '5. Aplikačný GitOps Sync: Argo CD → aspecta → Diff → Sync, iba ak je potrebný.' \
    '6. UI: bash scripts/aspecta-env.sh uis start && bash scripts/aspecta-env.sh uis open' \
    '7. Po práci: bash scripts/aspecta-env.sh stop  (bez vymazania clusteru/PVC).' \
    '8. Kompletné vysvetlenie: docs/ASPECTA-LOCAL-RUNBOOK.md'
}

check() {
  printf '\nASPECTA | Environment check | %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  if ! show_docker; then show_next; return 0; fi
  if ! show_cluster; then show_local; show_next; return 0; fi
  show_nodes_and_slots
  show_argo
  show_runtime
  show_metrics
  show_local
  show_next
}

start_cluster() {
  section 'Start EXISTING Aspecta cluster'
  has minikube || { fail 'Minikube not found in PATH'; return 1; }
  has kubectl || { fail 'kubectl not found in PATH'; return 1; }
  docker_healthy || {
    fail 'Docker Desktop is not ready. Start Docker Desktop and retry.'
    return 1
  }
  if ! minikube_profile_exists; then
    fail "Minikube profile '$PROFILE' was not found. Refusing to create a new cluster."
    info 'To create a NEW cluster intentionally, use the separately documented installation procedure.'
    return 1
  fi
  minikube -p "$PROFILE" start
  k wait --for=condition=Ready node/"$PROFILE" --timeout=180s
  k wait --for=condition=Ready node/"${PROFILE}-m02" --timeout=180s
  k wait --for=condition=Ready node/"${PROFILE}-m03" --timeout=180s
  ok 'Three nodes are Ready.'
}

bootstrap() {
  start_cluster
  section 'Idempotent node-label restoration'
  if [[ -f "$NODE_BOOTSTRAP" ]]; then
    local active
    active="$(kubectl config current-context 2>/dev/null || true)"
    if [[ "$active" != "$CONTEXT" ]]; then
      fail "Bootstrap label script expects active context '$CONTEXT', but current is '$active'."
      info "To switch explicitly: kubectl config use-context $CONTEXT"
      return 1
    fi
    bash "$NODE_BOOTSTRAP"
  else
    warn 'No platform/bootstrap/label-workers.sh found in repo.'
    info "kubectl --context $CONTEXT label node ${PROFILE}-m02 workload-tier=apps aspecta.io/pool=workers --overwrite"
    info "kubectl --context $CONTEXT label node ${PROFILE}-m03 workload-tier=monitoring aspecta.io/pool=workers --overwrite"
  fi
  check
  info 'GitOps sync is deliberately MANUAL; this command did not apply or delete any application.'
}

doctor() {
  check
  if ! kube_healthy; then return 0; fi
  section 'Doctor – node allocation'
  for node in "$PROFILE" "${PROFILE}-m02" "${PROFILE}-m03"; do
    printf '\n%s\n' "--- $node ---"
    k describe node "$node" 2>/dev/null | sed -n '/Allocated resources:/,+8p' || true
  done
  section 'Doctor – recent namespace events'
  for ns in aspecta-app monitoring kube-system argocd; do
    printf '\n%s\n' "--- $ns ---"
    k -n "$ns" get events --sort-by=.lastTimestamp 2>/dev/null | tail -n 12 || true
  done
  section 'Doctor – Docker memory limits (bytes)'
  docker inspect "$PROFILE" "${PROFILE}-m02" "${PROFILE}-m03" \
    --format '{{.Name}} RAM={{.HostConfig.Memory}} SWAP={{.HostConfig.MemorySwap}}' 2>/dev/null || true
}

stop_cluster() {
  section 'Safe shutdown (no delete, no PVC cleanup)'
  if [[ -f "$UI_HELPER" ]]; then
    bash "$UI_HELPER" stop || warn 'UI forwards could not all be stopped.'
  fi
  if ! has minikube; then fail 'Minikube not found.'; return 1; fi
  if ! minikube_profile_exists; then fail "Profile '$PROFILE' does not exist."; return 1; fi
  minikube -p "$PROFILE" stop
  ok 'Minikube stopped. Git repo, images, cluster and PVC resources were not deleted.'
}

flow() {
  cat <<'FLOW'

ASPECTA – Recommended daily operations (Windows Git Bash)

  Open Docker Desktop; WSL memory configured in %USERPROFILE%\.wslconfig (memory=9GB).
  bash scripts/aspecta-env.sh check
  bash scripts/aspecta-env.sh bootstrap
  # bootstrap starts the EXISTING 3-node cluster and restores node labels.
  # If an Argo app is OutOfSync, review Diff and Sync in Argo CD manually.
  bash scripts/aspecta-env.sh uis start
  bash scripts/aspecta-env.sh uis open
  bash scripts/aspecta-env.sh check
  # Do work: Git commit/push -> Argo CD Refresh/Diff/Sync -> smoke tests.
  bash scripts/aspecta-env.sh stop

SAFETY: no minikube delete; no terraform destroy; no PVC deletion;
        no automatic Argo prune/force/sync; no secrets printed.
FLOW
}

case "${1:-check}" in
  check|status) check ;;
  start) start_cluster; check ;;
  bootstrap) bootstrap ;;
  doctor) doctor ;;
  flow) flow ;;
  uis)
    shift
    [[ -f "$UI_HELPER" ]] || { fail 'Missing scripts/aspecta-uis.sh'; exit 1; }
    if (( $# == 0 )); then set -- status; fi
    bash "$UI_HELPER" "$@" ;;
  stop) stop_cluster ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
