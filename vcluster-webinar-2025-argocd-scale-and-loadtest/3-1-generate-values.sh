#!/usr/bin/env bash
set -euo pipefail

# Usage: CLUSTER_COUNT=5 ./3-1-generate-values.sh > values.yaml
# or: ./3-1-generate-values.sh 5 > values.yaml

# Read cluster count
if [[ -n "${1-}" ]]; then
  CLUSTER_COUNT=$1
elif [[ -n "${CLUSTER_COUNT-}" ]]; then
  CLUSTER_COUNT=$CLUSTER_COUNT
else
  echo "Error: specify CLUSTER_COUNT (e.g. export CLUSTER_COUNT=5 or pass as arg)" >&2
  exit 1
fi

# --- 1) Static preamble ---
cat <<'EOF'
argo-cd:
  configs:
    cm:
      dex.config: |
        connectors:
          - type: github
            id: github
            name: GitHub
            config:
              clientID: $oauth2-credentials:client-id
              clientSecret: $oauth2-credentials:client-secret
              orgs:
                - name: la-demos
      url: https://controlplane-demo.stackit.run/argocd
    params:
      server.basehref: /argocd
      server.insecure: true
      server.rootpath: /argocd
    rbac:
      policy.csv: |
        g, la-demos:g-gitops, role:admin
      policy.default: role:readonly
  controller:
    metrics:
      enabled: true
      rules:
        enabled: false
      serviceMonitor:
        additionalLabels:
          monitoring.instance: controlplane-demo
        enabled: true
  global:
    domain: controlplane-demo.stackit.run
    imagePullSecrets:
      - name: image-pull-secret
    revisionHistoryLimit: 5
  server:
    ingress:
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-staging
        nginx.ingress.kubernetes.io/auth-signin: https://$host/oauth2/start?rd=$escaped_request_uri
        nginx.ingress.kubernetes.io/auth-url: https://$host/oauth2/auth
        nginx.ingress.kubernetes.io/backend-protocol: HTTP
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      enabled: true
      ingressClassName: nginx
      path: /argocd
      tls: true
    ingressGrpc:
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-staging
        nginx.ingress.kubernetes.io/backend-protocol: GRPC
      enabled: true
      ingressClassName: nginx
      path: /argocd
      tls: true
bootstrapValues:
  applicationSets:
    - apps:
        - name: argocd
          path: argo-cd
        - name: kyverno
          path: kyverno
        - name: kyverno-policies
          path: kyverno-policies
        - name: external-secrets
          path: external-secrets
        - name: cert-manager
          path: cert-manager
        - name: cert-manager-lean
          path: cert-manager-lean
        - name: ingress-nginx
          path: ingress-nginx
        - name: metallb
          path: metallb
        - name: external-dns
          path: external-dns
        - name: oauth2-proxy
          path: oauth2-proxy
        - name: longhorn
          path: longhorn
        - name: kube-prometheus-stack
          path: kube-prometheus-stack
        - name: kube-prometheus-stack-lean
          path: kube-prometheus-stack-lean
        - name: loki
          path: loki
        - name: kyverno-policy-reporter
          path: kyverno-policy-reporter
        - name: homer-dashboard
          path: homer-dashboard
        - name: metrics-server
          path: metrics-server
        - name: kro
          path: kro
      customerServices:
        path: customer-service-catalog/helm
        repoURL: https://github.com/la-cc/vcluster-webinar-2025-argocd-scale-test.git
        targetRevision: main
      managedServices:
        path: managed-service-catalog/helm
        repoURL: https://github.com/la-cc/vcluster-webinar-2025-argocd-scale-test.git
        targetRevision: main
      projectName: controlplane-demo
  cluster:
EOF

# --- 2) Dynamic cluster entries ---
for ((i = 0; i < CLUSTER_COUNT; i++)); do
  cat <<EOF
    - additionalLabels:
        kro: disabled
      name: vcluster-${i}
      project: controlplane-demo
      remoteRef:
        remoteKey: my_clusters
        remoteKeyProperty: vcluster-${i}
      secretStoreRef:
        kind: ClusterSecretStore
        name: controlplane-demo
EOF
done

# --- 3) Static postamble ---
cat <<'EOF'
  dockerPullSecrets:
    - matchNamespaceLabels:
        project-name: controlplane
        stage: demo
      name: image-pull-secret
      remoteRef:
        remoteKey: docker_config
        remoteKeyProperty: pull-secret
      secretStoreRef:
        kind: ClusterSecretStore
        name: controlplane-demo
  applications:
    - destination:
        serverName: controlplane
      info:
        - name: type
          value: app-of-apps
      name: app-of-apps
      namespace: argocd
      projectName: controlplane-demo
      repoPath: apps
      repoUrl: https://github.com/la-cc/vcluster-webinar-2025-argocd-scale-test.git
  projects:
    - description: controlplane-demo project
      name: controlplane-demo
      namespace: argocd
      orphanedResources:
        ignore:
          - kind: Secret
            name: cert-manager-webhook-ca
        warn: false
      sourceRepos:
        - registry.onstackit.cloud/stackit-edge-cloud-blueprint
externalSecrets:
  secretStoreRef:
    kind: ClusterSecretStore
    name: controlplane-demo
  secrets:
    - dataFrom:
        - remoteKey: argo_oauth2_credentials
      target: oauth2-credentials
inClusterName: controlplane
inClusterSecretLabels:
  argocd: enabled
  cert-manager: enabled
  cilium: disabled
  external-dns: enabled
  external-secrets: enabled
  homer-dashboard: enabled
  ingress-nginx: enabled
  kube-prometheus-stack: enabled
  kyverno: enabled
  kyverno-policies: enabled
  kyverno-policy-reporter: enabled
  loki: enabled
  longhorn: disabled
  metallb: disabled
  metrics-server: disabled
  oauth2-proxy: enabled
namespace:
  labels:
    project-name: controlplane
    stage: demo
EOF
