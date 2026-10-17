#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

kind get clusters | grep -qx library-management-system || \
  kind create cluster --config deploy/kind/cluster.yaml --wait 120s

helm repo add traefik https://traefik.github.io/charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

pw() { openssl rand -hex 16; }
for ns in library monitoring; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl -n library get secret library-db >/dev/null 2>&1 || \
  kubectl -n library create secret generic library-db \
    --from-literal=MYSQL_PASSWORD="$(pw)" --from-literal=MYSQL_ROOT_PASSWORD="$(pw)"
kubectl -n monitoring get secret grafana-admin >/dev/null 2>&1 || \
  kubectl -n monitoring create secret generic grafana-admin \
    --from-literal=admin-user=admin --from-literal=admin-password="$(pw)"

P=deploy/platform
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --version 41.7.1 -f $P/traefik-values.yaml --wait
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
  --version 3.14.0 -f $P/metrics-server-values.yaml --wait
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace \
  --version 10.10.3 -f $P/argocd-values.yaml --wait --timeout 10m
helm upgrade --install loki grafana-community/loki -n monitoring \
  --version 18.15.1 -f $P/loki-values.yaml --wait --timeout 10m
helm upgrade --install alloy grafana/alloy -n monitoring \
  --version 1.13.1 -f $P/alloy-values.yaml --wait
helm upgrade --install jaeger jaegertracing/jaeger -n monitoring \
  --version 4.13.1 -f $P/jaeger-values.yaml --wait
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring \
  --version 92.6.0 -f $P/kube-prometheus-stack-values.yaml --wait --timeout 10m

kubectl apply -f deploy/argocd/library-app.yaml
echo "Argo CD is syncing deploy/local; the app answers on http://library.localhost"
