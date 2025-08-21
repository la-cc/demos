#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 2-sync-vclusters.sh
#   Logs into Vault, generates each vcluster's kubeconfig, patches it into
#   a Vault KV-v2 secret, and cleans up temporary files.
#
# Usage:
#   ./2-sync-vclusters.sh <number-of-clusters>
#   CLUSTER_COUNT=<number-of-clusters> ./sync-vclusters.sh
# -----------------------------------------------------------------------------

# 1) Determine how many clusters to process (0…N-1)
if [[ -n "${1-}" ]]; then
    N=$1
elif [[ -n "${CLUSTER_COUNT-}" ]]; then
    N=$CLUSTER_COUNT
else
    echo "Error: please supply the number of clusters as an argument or via CLUSTER_COUNT" >&2
    echo "Usage: ./sync-vclusters.sh 3    OR    CLUSTER_COUNT=3 ./sync-vclusters.sh" >&2
    exit 1
fi

# --- Tool checks ---
command -v jq >/dev/null || {
    echo >&2 "jq is not installed. Please install it."
    exit 1
}
command -v vcluster >/dev/null || {
    echo >&2 "vcluster CLI not found. Please install it."
    exit 1
}

# --- 2) Vault login ---
echo "🔐 Logging in to Vault..."
VAULT_TOKEN=$(curl -sS \
    --request PUT \
    --url "${VAULT_ADDR}/v1/auth/userpass/login/${VAULT_USER}" \
    --header "Content-Type: application/json" \
    --data "{\"password\":\"${VAULT_PASS}\"}" |
    jq -r .auth.client_token)

if [[ -z "$VAULT_TOKEN" ]]; then
    echo "‼️ Vault login failed" >&2
    exit 1
fi
echo "→ Received Vault token"

# --- 3) Loop through all vClusters 0…N-1 ---
for ((i = 0; i < N; i++)); do
    VC="vcluster-${i}"
    KC_FILE="kubeconfig-${VC}.yaml"
    DATA_FILE="data-${VC}.json"

    echo "⏳ Generating kubeconfig for ${VC}"
    vcluster connect "${VC}" \
        -n "${VC}" \
        --server="${VC}.controlplane-demo.stackit.run" \
        --print >"${KC_FILE}"

    echo "📝 Escaping kubeconfig to JSON"
    CFG=$(jq -Rs . "${KC_FILE}")

    echo "💾 Preparing patch payload"
    cat >"${DATA_FILE}" <<EOF
{
  "data": {
    "${VC}": ${CFG}
  }
}
EOF

    echo "📡 Patching Vault secret '${SECRET_PATH}' → field '${VC}'"
    curl -sS \
        --request PATCH \
        --url "${VAULT_ADDR}/v1/${MOUNT}/data/${SECRET_PATH}" \
        --header "X-Vault-Token: ${VAULT_TOKEN}" \
        --header "Content-Type: application/merge-patch+json" \
        --data @"${DATA_FILE}" ||
        {
            echo "‼️ Patch for ${VC} failed" >&2
            exit 1
        }

    echo "✓ Patched ${VC}"

    # --- 4) Cleanup temporary files ---
    rm -f "${KC_FILE}" "${DATA_FILE}"
    echo "🗑  Removed ${KC_FILE} and ${DATA_FILE}"
done

echo "🎉 Successfully synchronized ${N} vClusters!"
