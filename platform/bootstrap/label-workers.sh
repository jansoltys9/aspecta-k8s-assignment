#!/usr/bin/env bash
set -euo pipefail

if [[ "$(kubectl config current-context)" != "aspecta" ]]; then
  echo "Wrong Kubernetes context"
  exit 1
fi

kubectl label node aspecta-m02 \
  workload-tier=apps \
  aspecta.io/pool=workers --overwrite

kubectl label node aspecta-m03 \
  workload-tier=monitoring \
  aspecta.io/pool=workers --overwrite
