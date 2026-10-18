#!/usr/bin/env bash
set -euo pipefail

NS=${NS:-library}
REPO=neeldholiya04/Library-Management-System

git fetch -q origin deploy/local
TAG=$(git show origin/deploy/local:charts/library/values-local.yaml | sed -n 's/^  tag: //p')
SHA=${TAG#sha-}

echo "deploy/local commit : $(git log -1 --format='%h %s' origin/deploy/local)"
echo "image tag in git    : $TAG"
echo "source commit       : $(git log -1 --format='%h %s' "$SHA" 2>/dev/null || echo "$SHA")"
echo "CI checks for commit: https://github.com/$REPO/commit/$SHA/checks"
echo "argo sync revision  : $(kubectl -n argocd get application library -o jsonpath='{.status.sync.revision}' | cut -c1-7) $(kubectl -n argocd get application library -o jsonpath='{.status.sync.status}/{.status.health.status}')"
echo "running pods        :"
kubectl -n "$NS" get pods -l app.kubernetes.io/name=library-app \
  -o custom-columns='  POD:.metadata.name,IMAGE:.spec.containers[0].image,VERSION:.metadata.labels.app\.kubernetes\.io/version'

kubectl -n "$NS" port-forward svc/library-app 18081:8081 >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null' EXIT
sleep 3
echo "/actuator/info      : $(curl -s localhost:18081/actuator/info)"
