#!/usr/bin/env bash
set -euo pipefail

NS=${NS:-library}
BASE=${BASE:-http://library.localhost}
OUTAGE=${OUTAGE:-180}
SYNC='{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 19090:9090 >/dev/null 2>&1 &
PF=$!
restore() {
  kubectl -n argocd patch application library --type merge -p "$SYNC" >/dev/null
  kill $PF 2>/dev/null || true
}
trap restore EXIT
sleep 3

ready_endpoints() {
  kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=library-app \
    -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | grep -c . || true
}

status() {
  local http firing
  http=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$BASE/author" || true)
  firing=$(curl -s localhost:19090/api/v1/query --data-urlencode 'query=ALERTS{alertname=~"Library.*"}' \
    | grep -o '"alertname":"[A-Za-z]*","alertstate":"[a-z]*"' \
    | sed -E 's/"alertname":"([A-Za-z]+)","alertstate":"([a-z]+)"/\1=\2/' | sort -u | tr '\n' ' ' || true)
  printf '%s  http=%s  ready-endpoints=%s  alerts=[%s]\n' "$(date +%H:%M:%S)" "$http" "$(ready_endpoints)" "$firing"
}

echo "== baseline"
status

echo "== pausing Argo auto-sync so self-heal does not undo the fault"
kubectl -n argocd patch application library --type json -p '[{"op":"remove","path":"/spec/syncPolicy/automated"}]' >/dev/null

echo "== fault: MySQL scaled to 0 for ${OUTAGE}s"
kubectl -n "$NS" scale statefulset library-mysql --replicas=0 >/dev/null
end=$((SECONDS + OUTAGE))
while (( SECONDS < end )); do status; sleep 15; done

echo "== recovery: re-enable auto-sync, Argo restores MySQL from git"
kubectl -n argocd patch application library --type merge -p "$SYNC" >/dev/null
until [[ $(ready_endpoints) -ge 1 ]]; do status; sleep 10; done
status
kubectl -n "$NS" rollout status statefulset library-mysql --timeout=300s >/dev/null
for _ in 1 2 3 4; do status; sleep 15; done

echo "== post-recovery user journey"
BASE=$BASE "$(dirname "$0")/journey.sh"
