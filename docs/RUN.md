# Run instructions

## Prerequisites

| Tool | Tested with |
|---|---|
| Docker (≥ 6 GB memory for the full stack) | Docker 29 |
| kind | 0.31 and 0.33 |
| kubectl | 1.35 and 1.36 |
| helm | 4.3 |
| bash, curl, openssl | any recent |
| Java 21 (only to build or test outside Docker) | Temurin 21 |

On Windows use Git Bash. `library.localhost` resolves to 127.0.0.1 without editing hosts files.

## 1. Run the app alone (Docker Compose)

```bash
cp .env.example .env
```

```bash
docker compose up --build
```

API on http://localhost:8080, MySQL on localhost:3307.

## 2. Tests

```bash
./mvnw -B verify
```

Needs Docker running; the integration test starts MySQL with Testcontainers.

## 3. Full platform on kind

```bash
bash deploy/bootstrap-local.sh
```

This creates the cluster, random in-cluster secrets, Traefik, metrics-server, Argo CD, Loki, Alloy, Jaeger and kube-prometheus-stack (pinned chart versions), then applies the Argo CD Application. Argo CD deploys the app from the `deploy/local` branch. It takes about 10 minutes on first run.

```bash
kubectl -n argocd get application library
```

Wait for `Synced  Healthy`.

## 4. Access

| What | How |
|---|---|
| API | http://library.localhost/book, `/author`, `/patron`, `/lending` |
| Grafana | `kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80`, user `admin`, password from `kubectl -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' \| base64 -d` |
| Prometheus | `kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090` |
| Jaeger | `kubectl -n monitoring port-forward svc/jaeger 16686:16686` |
| Argo CD | `kubectl -n argocd port-forward svc/argocd-server 8443:443`, user `admin`, password from `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Actuator | `kubectl -n library port-forward svc/library-app 8081:8081`, then `/actuator/health`, `/actuator/info` |

## 5. Release a change

1. Push to `feat/advance-cloud-assignment`.
2. CI runs tests, scans and builds `ghcr.io/neeldholiya04/library-app:sha-<commit>`.
3. Approve the **Release** job (environment `local`) in GitHub Actions.
4. Argo CD syncs `deploy/local` within about a minute.

```bash
bash scripts/trace-release.sh
```

Shows the commit, image, pods and `/actuator/info` for the running release.

## 6. Roll back

```bash
git push --force origin <previous-release-commit>:deploy/local
```

Roll forward again by pushing the newer release commit to `deploy/local`.

## 7. Verification scripts

| Script | Shows |
|---|---|
| `scripts/journey.sh` | Author → book → patron → lend → return through the Ingress |
| `scripts/trace-release.sh` | Commit → image tag → pod → `/actuator/info` |
| `scripts/fault-demo.sh` | MySQL outage: readiness drops, alert fires, Argo restores MySQL, journey passes |

## Known limitations

- Single-node kind cluster on a laptop: HPA and PDB behaviour is real, but there is no node-level redundancy.
- MySQL is a single replica with no backups; the PVC is lost when the cluster is deleted.
- Secrets are created imperatively by the bootstrap script, not stored in git. Sealed Secrets was not used because its key is cluster-bound and this cluster is rebuilt from scratch.
- The baseline commit `05fd425` contains plaintext dev DB passwords in `application.properties` and `docker-compose.yml`. History is kept unchanged so the before/after comparison stays intact; those passwords are not used anywhere now.
- Jaeger stores traces in memory; they are lost on restart. Jaeger is pinned to chart 4.13.1 (Jaeger 2.20) because Grafana's Jaeger datasource calls `/api/services`, which Jaeger 2.21+ no longer serves.
- Two Spring Framework CVEs have no fix before Spring Boot 4; they are accepted in `.trivyignore.yaml` with reasons and an expiry date.
- Local values trade JVM peak performance for low CPU (`TieredStopAtLevel=1`, serial GC) so the whole stack fits on a laptop.
- Releases need a human approval in GitHub; GitHub runners cannot reach the local cluster, so Argo CD pulls instead.
- Argo CD follows `deploy/local`, which is moved forward from the feature branch by the approved release job. After merging, the release job and `deploy/local` would follow `main`. Anyone with write access can still push to `deploy/local` directly (used on purpose for fast rollback); a branch ruleset limiting it to the release job would close that.
- Alertmanager has no notification receiver (no Slack or email), so alerts are only visible in Prometheus, Alertmanager and Grafana.
- Prometheus does not scrape the kubelet, so there are no container CPU metrics; the dashboard uses the JVM's own CPU metric instead.
- Dependabot opens its pull requests against `main`.
