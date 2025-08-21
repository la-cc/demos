#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 3-prune-vclusters-in-vault.sh
#   Entfernt N vCluster-Felder (Prefix+Index) aus einem Vault KV-v2 Secret.
#   Beispiel-Felder: vcluster-0, vcluster-1, ... vcluster-(N-1)
#
# Usage:
#   ./3-prune-vclusters-in-vault.sh <number-of-clusters>
#   CLUSTER_COUNT=<number> START_INDEX=0 VC_PREFIX="vcluster-" ./3-prune-vclusters-in-vault.sh
#
# Required env:
#   VAULT_ADDR, VAULT_USER, VAULT_PASS, MOUNT, SECRET_PATH
#
# Optional env:
#   START_INDEX=0     # Startindex (default 0)
#   VC_PREFIX="vcluster-"  # Feld-/Cluster-Prefix (default vcluster-)
#   DRY_RUN=1         # nur anzeigen, nicht patchen
#   FORCE=1           # ohne Rückfrage
# -----------------------------------------------------------------------------

# --- Anzahl bestimmen ---
if [[ -n "${1-}" ]]; then
  N="$1"
elif [[ -n "${CLUSTER_COUNT-}" ]]; then
  N="$CLUSTER_COUNT"
else
  echo "Error: supply number of clusters as arg or CLUSTER_COUNT." >&2
  exit 1
fi

START_INDEX="${START_INDEX:-0}"
VC_PREFIX="${VC_PREFIX:-vcluster-}"
DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"

# --- Tools/Env prüfen ---
for bin in jq curl; do
  command -v "$bin" >/dev/null || { echo >&2 "Missing tool: $bin"; exit 1; }
done
: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_USER:?set VAULT_USER}"
: "${VAULT_PASS:?set VAULT_PASS}"
: "${MOUNT:?set MOUNT (kv v2 mount path, e.g. secret)}"
: "${SECRET_PATH:?set SECRET_PATH (e.g. platforms/argocd/kubeconfigs)}"

# --- Ziel-Felder vorbereiten ---
keys_json_elems=()
for ((i=START_INDEX; i<START_INDEX+N; i++)); do
  keys_json_elems+=("\"${VC_PREFIX}${i}\"")
done
KEYS_JSON="[$(IFS=,; echo "${keys_json_elems[*]}")]"

echo "Vault target: ${MOUNT}/data/${SECRET_PATH}"
echo "Remove fields: $(jq -r '.[]' <<<"${KEYS_JSON}" | tr '\n' ' ')"
[[ "$DRY_RUN" == "1" ]] && echo "Mode: DRY-RUN (no changes will be made)"

if [[ "$FORCE" != "1" ]]; then
  read -r -p "Proceed deleting these fields from Vault? [y/N] " ans
  ans_lower=$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')
  if [[ "$ans_lower" != "y" && "$ans_lower" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# --- Vault Login ---
VAULT_TOKEN="$(curl -sS \
  --request PUT \
  --url "${VAULT_ADDR}/v1/auth/userpass/login/${VAULT_USER}" \
  --header "Content-Type: application/json" \
  --data "{\"password\":\"${VAULT_PASS}\"}" | jq -r .auth.client_token)"

if [[ -z "${VAULT_TOKEN}" || "${VAULT_TOKEN}" == "null" ]]; then
  echo "Vault login failed." >&2
  exit 1
fi

# --- Payload bauen: { "data": { "<field>": null, ... } }
PAYLOAD="$(jq -n --argjson arr "${KEYS_JSON}" \
  'reduce $arr[] as $k ({}; .[$k]=null) | {data: .}')"

echo "PATCH payload (keys -> null):"
echo "${PAYLOAD}" | jq '.'

# --- PATCH ausführen (KV v2 Merge-Patch entfernt Felder mit null) ---
if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY-RUN: Would PATCH ${VAULT_ADDR}/v1/${MOUNT}/data/${SECRET_PATH}"
else
  curl -sS \
    --request PATCH \
    --url "${VAULT_ADDR}/v1/${MOUNT}/data/${SECRET_PATH}" \
    --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --header "Content-Type: application/merge-patch+json" \
    --data "${PAYLOAD}" >/dev/null
  echo "✓ Fields removed from Vault secret."
fi
