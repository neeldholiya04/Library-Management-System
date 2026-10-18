#!/usr/bin/env bash
set -uo pipefail

BASE=${BASE:-http://library.localhost}
PIDS=()
pf() {
  kubectl -n "$1" port-forward "svc/$2" "$3" >/dev/null 2>&1 &
  PIDS+=($!)
}
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT

pf monitoring monitoring-kube-prometheus-prometheus 19090:9090
pf monitoring monitoring-kube-prometheus-alertmanager 19093:9093
pf monitoring monitoring-grafana 13000:80
pf monitoring loki 13100:3100
pf monitoring jaeger 16687:16686

GPW=$(kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d)

for _ in 1 2 3 4 5; do curl -s -o /dev/null "$BASE/author"; done
sleep 15

q() { curl -s -G localhost:19090/api/v1/query --data-urlencode "query=$1"; }
g() { curl -s -u "admin:$GPW" "localhost:13000$1"; }

app_scraped()      { q 'up{namespace="library",service="library-app"}' | grep -q '"1"\]'; }
http_metrics()     { q 'sum(http_server_requests_seconds_count{namespace="library"})' | grep -q '"value"'; }
ksm_metrics()      { q 'kube_deployment_status_replicas_available{namespace="library",deployment="library-app"}' | grep -q '"value"'; }
rules_loaded()     { curl -s localhost:19090/api/v1/rules | grep -q 'LibraryDatabaseDown'; }
prom_to_am()       { curl -s localhost:19090/api/v1/alertmanagers | grep -q '"activeAlertmanagers":\[{'; }
am_ready()         { curl -s -o /dev/null -w '%{http_code}' localhost:19093/-/ready | grep -q 200; }
ds_exists()        { for u in prometheus alertmanager loki jaeger; do g "/api/datasources/uid/$u" | grep -q "\"uid\":\"$u\"" || return 1; done; }
ds_health()        { g "/api/datasources/uid/$1/health" | grep -q '"status":"OK"'; }
ds_prometheus()    { ds_health prometheus; }
ds_loki()          { ds_health loki; }
ds_jaeger()        { ds_health jaeger; }
dashboard_loaded() { g '/api/search?query=Library' | grep -q 'library-overview'; }
loki_has_logs()    { curl -s -G localhost:13100/loki/api/v1/query_range --data-urlencode 'query={namespace="library",app="library-app"}' --data-urlencode 'limit=1' | grep -q '"values":\[\['; }
trace_id_in_logs() { kubectl -n library logs deploy/library-app --tail=300 | grep -q '"traceId":"'; }
jaeger_service()   { curl -s localhost:16687/api/services | grep -q '"library-app"'; }
jaeger_sql_spans() { curl -s -G localhost:16687/api/traces --data-urlencode service=library-app --data-urlencode limit=20 | grep -qiE '"operationName":"(connection|query|result-set)'; }
log_to_trace() {
  local id
  id=$(kubectl -n library logs deploy/library-app --tail=300 | grep -o '"traceId":"[0-9a-f]*"' | tail -1 | cut -d'"' -f4)
  [[ -n $id ]] && curl -s "localhost:16687/api/traces/$id" | grep -q "\"traceID\":\"$id\""
}

pass=0
fail=0
check() {
  if "$2"; then echo "PASS  $1"; pass=$((pass + 1)); else echo "FAIL  $1"; fail=$((fail + 1)); fi
}

check "Prometheus scrapes the app on port 8081" app_scraped
check "App HTTP metrics are in Prometheus" http_metrics
check "kube-state-metrics data is in Prometheus" ksm_metrics
check "Library alert rules are loaded" rules_loaded
check "Prometheus is connected to Alertmanager" prom_to_am
check "Alertmanager is ready" am_ready
check "Grafana has Prometheus, Alertmanager, Loki, Jaeger data sources" ds_exists
check "Grafana can query Prometheus" ds_prometheus
check "Grafana can query Loki" ds_loki
check "Grafana can query Jaeger" ds_jaeger
check "Library dashboard is loaded in Grafana" dashboard_loaded
check "Alloy ships app logs to Loki" loki_has_logs
check "App log lines carry a traceId" trace_id_in_logs
check "App sends traces to Jaeger over OTLP" jaeger_service
check "Traces include SQL spans" jaeger_sql_spans
check "A traceId from the logs opens in Jaeger" log_to_trace

echo "passed=$pass failed=$fail"
(( fail == 0 ))
