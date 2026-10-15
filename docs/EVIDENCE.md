# Verification and operational evidence

All evidence below comes from the local kind cluster built with `deploy/bootstrap-local.sh` and the scripts in `scripts/`. Raw outputs are in [`docs/evidence/`](evidence/).

## Tested version

| Item | Value |
|---|---|
| Source commit | `608c03c` |
| CI run | [actions/runs/38700781542](https://github.com/neeldholiya04/Library-Management-System/actions/runs/38700781542) |
| Image | `ghcr.io/neeldholiya04/library-app:sha-608c03c` |
| Release commit on `deploy/local` | `7d07395` |
| Argo CD | `Synced` / `Healthy` at `7d07395` |
| `/actuator/info` | `{"app":{"version":"0.1.0","git-sha":"608c03c"}}` |

## 1. Commit to running pod

Output of `scripts/trace-release.sh` ([raw](evidence/trace-release.txt)):

```
deploy/local commit : 7d07395 deploy: library-app sha-608c03c [skip ci]
image tag in git    : sha-608c03c
source commit       : 608c03c Verification scripts: ...
argo sync revision  : 7d07395 Synced/Healthy
running pods        :
  POD                          IMAGE                                           VERSION
library-app-5d44ddbdbb-2vw76   ghcr.io/neeldholiya04/library-app:sha-608c03c   sha-608c03c
/actuator/info      : {"app":{"version":"0.1.0","git-sha":"608c03c"}}
```

The same SHA appears in git, the image tag, the pod label and the running application, so the running version is traceable back to one commit and one CI run.

## 2. Pipeline run for that commit

[Run 38700781542](https://github.com/neeldholiya04/Library-Management-System/actions/runs/38700781542), all jobs green:

| Job | Result | Duration |
|---|---|---|
| Tests (unit + Testcontainers MySQL) | success | 42 s |
| Secret scan (gitleaks, `baseline..HEAD`) | success | 12 s |
| Helm lint + kubeconform + Trivy chart config scan | success | 12 s |
| Build, Trivy image scan, push to GHCR | success | 97 s |
| Release (approval gate on environment `Local`, then bump `deploy/local`) | success after manual approval | 6 s |

The release job only starts after a reviewer approves the `Local` environment, so every change to the cluster (image, chart or config) is approved before Argo CD can see it.

## 3. Working user journey

Output of `scripts/journey.sh` through the Ingress at `http://library.localhost` ([raw](evidence/journey.txt)):

```
POST   /author                              200
POST   /book                                200
GET    /book/title/Book-1792051085          200
POST   /patron                              200
POST   /lending                             200
GET    /lending/patron/7                    200
PUT    /lending/7                           200
GET    /lending/7                           200
journey ok: author=8 book=7 patron=7 lending=7
```

The script exits non-zero on any non-2xx response and asserts the lending moves from `BORROWED` to `RETURNED`.

## 4. Runtime state

From [`cluster-state.txt`](evidence/cluster-state.txt):

- `library-app` 1/1 and `library-mysql-0` 1/1 Running, HPA at 2% of target (min 1, max 3 locally).
- NetworkPolicies active: `library-default-deny`, `library-app`, `library-mysql`.
- Argo CD application `library`: `Synced` / `Healthy`.
- Prometheus: 8 targets, all `up`, including `serviceMonitor/library/library-app/0` scraping the app's management port.

## 5. Fault and recovery: MySQL outage

Run with `scripts/fault-demo.sh` ([raw](evidence/fault-demo.txt)). Argo CD auto-sync is paused for the duration so self-heal does not undo the fault, then re-enabled to perform the recovery.

| Time | HTTP `/author` | Ready app endpoints | Alerts |
|---|---|---|---|
| 13:28:28 | 200 | 1 | none (baseline) |
| 13:28:29 | 500 | 1 | MySQL scaled to 0 |
| 13:28:49 | 000 | 0 | readiness failed, pod removed from the Service |
| 13:29:05 | 503 | 0 | Traefik has no ready backend |
| 13:29:37 | 503 | 0 | `LibraryAppUnavailable`, `LibraryDatabaseDown` pending |
| 13:31:42 | 503 | 0 | both **firing**; recovery started (auto-sync re-enabled) |
| 13:32:04 | 200 | 1 | Argo restored MySQL from git, app ready again |
| 13:32:51 | 200 | 1 | `LibraryAppUnavailable`, `LibraryDatabaseDown` resolved |

After recovery the full user journey passed again (`journey ok: author=9 book=8 patron=8 lending=8`).

- **Symptom:** requests fail, app endpoints drop to zero.
- **Hypothesis:** the database is unavailable, so readiness (which includes the `db` health check) fails.
- **Evidence:** `LibraryDatabaseDown` and `LibraryAppUnavailable` fire after their 2-minute `for` window; ready endpoints go to 0 while the app pod itself is not restarted, because liveness does not depend on the database.
- **Change:** re-enable Argo CD auto-sync; it restores the StatefulSet to the replica count in git.
- **Verification:** HTTP 200 and 1 ready endpoint 22 seconds after recovery started, alerts resolve, user journey passes, and no data was lost because the PVC survived.

Observations:

- One request returned `500` in the first seconds of the outage. That is the window before three failed readiness checks (5 s period) remove the pod from the Service; after that Traefik returns `503` instead of hanging.
- `LibraryHighErrorRate` and `LibraryHighLatency` went to `pending` but did not fire, because their `for` windows (5 and 10 minutes) are longer than the 3-minute outage. That is intended: they guard against sustained degradation, while the availability alerts react within 2 minutes.
- Alerts resolved about 45 seconds after recovery, which is the kube-state-metrics scrape interval plus the 30 s rule evaluation interval.

## 6. Earlier incidents on the laptop cluster

These happened during development and shaped the final configuration:

| Incident | Cause | Fix |
|---|---|---|
| App pods stuck at 0/1 with HPA pinned at max | CPU request (100m) below idle JVM usage, simultaneous JVM starts and a 150 s startup window on a shared 6-vCPU node | CPU request 250m, 300 s startup window, HPA scale-up stabilisation, JVM `ActiveProcessorCount`, probe timeouts |
| MySQL OOM-killed at 512Mi | `performance_schema` defaults | `--performance-schema=OFF`, 640Mi limit, TCP probes instead of `exec` |
| Control plane crash-looping after installing monitoring | kubelet/cAdvisor scraping, operator webhooks and log streaming through the API server on an 8 GB laptop | kube-prometheus-stack without kubelet scraping or admission webhooks, Alloy reads log files from the node, Argo CD resource inclusions, Grafana sidecar scoped to `library` |

## Limitations of this evidence

- Single-node local cluster; there is no node failure or multi-replica database scenario.
- Traces are stored in Jaeger's in-memory store and are lost on restart.
- Timestamps in the raw outputs are local time (IST); CI times on GitHub are UTC.
