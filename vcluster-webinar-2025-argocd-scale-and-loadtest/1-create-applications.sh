#!/usr/bin/env bash
set -euo pipefail

# Usage: CLUSTER_COUNT=5 ./create-applications.sh
#    or: ./1-create-applications.sh 5

# 1) Determine CLUSTER_COUNT
if [[ -n "${1-}" ]]; then
    CLUSTER_COUNT=$1
elif [[ -n "${CLUSTER_COUNT-}" ]]; then
    CLUSTER_COUNT=$CLUSTER_COUNT
else
    echo "Error: specify CLUSTER_COUNT (e.g. export CLUSTER_COUNT=5 or pass as arg)" >&2
    exit 1
fi

# 2) Point to your template
TEMPLATE_FILE=${TEMPLATE_FILE:-app-vcluster-template.yaml}
OUTPUT_DIR=${OUTPUT_DIR:-apps}

# 3) Make sure output dir exists
mkdir -p "$OUTPUT_DIR"

echo "🔄 Generating $CLUSTER_COUNT ArgoCD Application manifests using '$TEMPLATE_FILE'…"

# 4) Loop and envsubst only $CLUSTER
for ((i = 0; i < CLUSTER_COUNT; i++)); do
    export CLUSTER="vcluster-${i}"
    OUT_MANIFEST="$OUTPUT_DIR/${CLUSTER}.yaml"
    echo "• $CLUSTER → $OUT_MANIFEST"
    envsubst '$CLUSTER' <"$TEMPLATE_FILE" >"$OUT_MANIFEST"
done

echo "✅ Generated $CLUSTER_COUNT manifests in '$OUTPUT_DIR'"
