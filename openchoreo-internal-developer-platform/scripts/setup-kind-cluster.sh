#!/bin/bash
set -o errexit
set -o pipefail


# --- 1. Create Kind Cluster ---

CLUSTER_NAME="openchoreo"

# Check if the Kind cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "✅ Kind cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  echo "🚀 Creating Kind cluster '${CLUSTER_NAME}'..."
  cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  image: kindest/node:v1.32.0@sha256:c48c62eac5da28cdadcf560d1d8616cfa6783b58f0d94cf63ad1bf49600cb027
- role: worker
  labels:
    openchoreo.dev/noderole: workflow-runner
  image: kindest/node:v1.32.0@sha256:c48c62eac5da28cdadcf560d1d8616cfa6783b58f0d94cf63ad1bf49600cb027
  extraMounts:
    - hostPath: /tmp/kind-shared
      containerPath: /mnt/shared
networking:
  disableDefaultCNI: true
EOF
fi

echo "✅ Kind cluster successfully created"

# --- 2. Install Cilium CN ---
helm upgrade --install cilium oci://ghcr.io/openchoreo/helm-charts/cilium --version 0.3.2 --create-namespace --namespace cilium --wait


# --- 3. Install OpenChoreo Control Plane ---
helm upgrade --install control-plane oci://ghcr.io/openchoreo/helm-charts/openchoreo-control-plane \
--version 0.3.2 \
--create-namespace --namespace openchoreo-control-plane --timeout=1m


# --- 4. Install OpenChoreo Data Plane ---

helm upgrade --install data-plane oci://ghcr.io/openchoreo/helm-charts/openchoreo-data-plane \
--version 0.3.2 \
--create-namespace --namespace openchoreo-data-plane \
--set cert-manager.enabled=false \
--set cert-manager.crds.enabled=false --timeout=1m

# --- 5. Install OpenChoreo Build Plane (Optional) ---

helm upgrade --install build-plane oci://ghcr.io/openchoreo/helm-charts/openchoreo-build-plane \
--version 0.3.2 \
--create-namespace --namespace openchoreo-build-plane --timeout=1m


## Configure BuildPlane
curl -s https://raw.githubusercontent.com/openchoreo/openchoreo/release-v0.3/install/add-build-plane.sh | bash

## Configure DataPlane
curl -s https://raw.githubusercontent.com/openchoreo/openchoreo/release-v0.3/install/add-default-dataplane.sh | bash

# --- 7. Install OpenChoreo Observability Plane (Optional) ---

helm upgrade --install observability-plane oci://ghcr.io/openchoreo/helm-charts/openchoreo-observability-plane \
--version 0.3.2 \
--create-namespace --namespace openchoreo-observability-plane \
--timeout=5m

## Configure Observer Integration

# Configure DataPlane to use observer service
kubectl patch dataplane default -n default --type merge -p '{"spec":{"observer":{"url":"http://observer.openchoreo-observability-plane:8080","authentication":{"basicAuth":{"username":"dummy","password":"dummy"}}}}}'

# Configure BuildPlane to use observer service
kubectl patch buildplane default -n default --type merge -p '{"spec":{"observer":{"url":"http://observer.openchoreo-observability-plane:8080","authentication":{"basicAuth":{"username":"dummy","password":"dummy"}}}}}'

# --- 8. Install OpenChoreo Backstage Portal (Optional) ---

helm upgrade --install openchoreo-backstage-demo oci://ghcr.io/openchoreo/helm-charts/backstage-demo \
--version 0.3.2 \
--namespace openchoreo-control-plane

# --- 9. Install OpenChoreo Default Identity Provider (Optional) ---

helm upgrade --install identity-provider oci://ghcr.io/openchoreo/helm-charts/openchoreo-identity-provider \
--version 0.3.2 \
--create-namespace --namespace openchoreo-identity-system \
--timeout=3m

# --- 10. Verify OpenChoreo Installation ---

# Check default organization and project
kubectl get organizations,projects,environments -A

# Check default platform classes
kubectl get serviceclass,apiclass -n default

# Check all OpenChoreo CRDs
kubectl get crds | grep openchoreo

# Check gateway resources
kubectl get gateway,httproute -n openchoreo-data-plane

# Check cluster info
kubectl cluster-info --context kind-openchoreo

# Check control plane pods
kubectl get pods -n openchoreo-control-plane

# Check data plane pods
kubectl get pods -n openchoreo-data-plane

# Check build plane pods (if installed)
kubectl get pods -n openchoreo-build-plane

# Check observability plane pods (if installed)
kubectl get pods -n openchoreo-observability-plane

# Check identity provider pods (if installed)
kubectl get pods -n openchoreo-identity-system

# Check Cilium pods
kubectl get pods -n cilium

# Check nodes (should be Ready)
kubectl get nodes

echo ""
echo "✅ Setup complete!"
echo ""