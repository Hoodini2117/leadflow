# LeadFlow Kubernetes Architecture

## 1. Objective

This directory translates the existing LeadFlow Docker Compose stack into
Kubernetes objects. It keeps the same application boundaries—Next.js frontend,
Express API, PostgreSQL, and a one-shot migration process—while using cluster
service discovery, health probes, persistent storage, resource controls, and
an Ingress entry point.

The manifests are a deployment baseline, not a claim that a single PostgreSQL
pod is a highly available production database. Image references and credentials
are intentionally templates and must be replaced before deployment.

## 2. Overall architecture

```text
Browser
  |
  v
NGINX Ingress
  |
  v
frontend Service :80 -> Next.js Pods :3000
  |  Next.js rewrites /api/* to http://backend:3000/api/*
  v
backend Service :3000 -> Express Pods :3000
  |
  v
postgres Service :5432 -> PostgreSQL Pod
                               |
                               v
                         postgres-data PVC

leadflow-migrate Job ----------> postgres Service
```

The frontend image must be built with
`API_INTERNAL_URL=http://backend:3000`. This is a build argument in the
existing frontend Dockerfile because Next.js writes rewrites into its
production build. The `backend` Service name is stable within the `leadflow`
namespace and resolves through Kubernetes DNS.

## 3. Why Kubernetes instead of Docker Compose

Compose remains the local, single-host workflow. Kubernetes adds orchestration
for a cluster: it continually reconciles Deployments, routes traffic through
Services, restarts unhealthy containers, supports rolling application
releases, and requests persistent storage from the cluster. The Compose
services map directly to Kubernetes workloads and Services; the Compose named
PostgreSQL volume maps to a PVC.

This migration does not make the single PostgreSQL instance highly available.
For production database availability, use a managed PostgreSQL service or a
purpose-built PostgreSQL operator.

## 4. Namespace

`namespace.yaml` creates the `leadflow` namespace. It gives the application
resources a dedicated scope and lets services use short DNS names such as
`backend` and `postgres`. This replaces Compose's project-scoped network
boundary; it does not create network isolation by itself.

The root Kustomization applies the `leadflow` namespace to namespaced
resources. The example Secret is deliberately excluded.

## 5. Deployments

Deployments keep the desired number of replaceable pods running:

| Deployment | Replicas | Purpose and Compose mapping |
|---|---:|---|
| `postgres` | 1 | Runs PostgreSQL 16, mounts the database PVC, and provides the database target used by both the API and migration Job. It maps to Compose's `database` service. `Recreate` avoids overlapping pods attempting to mount a single-writer volume during updates. |
| `backend` | 2 | Runs the existing Express image and exposes port 3000 to the backend Service. It maps to Compose's API service. Rolling updates keep an unavailable pod count at zero, subject to readiness and available capacity. |
| `frontend` | 2 | Runs the existing standalone Next.js image on port 3000. It maps to Compose's web service and is reached through the Ingress-facing frontend Service. |

Both application Deployments use `RollingUpdate`, `maxUnavailable: 0`, and
`maxSurge: 1`. Their image values are examples under the reserved
`registry.example.com` domain; replace them with the actual pushed images.
`IfNotPresent` avoids repeated downloads of an already cached, version-tagged
image.

## 6. Services

Services provide stable DNS names and select pods using
`app.kubernetes.io/name` labels:

- `postgres` exposes TCP 5432 only inside the cluster. The backend and Job use
  this Service instead of `localhost`.
- `backend` exposes TCP 3000 inside the cluster. The frontend's Next.js server
  proxies `/api/*` requests to `http://backend:3000`.
- `frontend` exposes port 80 inside the cluster and forwards to container port
  3000. The Ingress routes `/` to this Service.

All three are `ClusterIP`; no database or API NodePort/LoadBalancer is created.
The Ingress is the external HTTP entry point.

## 7. ConfigMaps

ConfigMaps hold non-sensitive runtime settings:

- `postgres-config` sets `POSTGRES_DB` and `PGDATA`; the PostgreSQL Deployment
  consumes those keys.
- `backend-config` sets `PORT`, `APP_VERSION`, and `DB_POOL_MAX`; both the API
  Deployment and migration Job consume it.
- `frontend-config` sets `NODE_ENV`, `PORT`, and `HOSTNAME` for the standalone
  Next.js server.

This maps Compose environment entries to Kubernetes configuration objects.
`API_INTERNAL_URL` is intentionally not a ConfigMap value: it is a Next.js
build-time input and is already baked into the frontend image.

## 8. Secret

`backend/secret-example.yaml` documents the Secret named
`leadflow-db-credentials`. PostgreSQL reads `POSTGRES_USER` and
`POSTGRES_PASSWORD`; the API and migration Job read `DATABASE_URL`.

The sample is not included in Kustomize and must not be applied unchanged.
Copy it outside the repository, replace the placeholders, and apply that
private copy. The URL must address `postgres:5432/leadflow`; percent-encode
reserved characters in its username or password. Kubernetes Secrets are
base64-encoded data, not an encrypted secret manager—enable encryption at rest
and restrict RBAC in a real cluster.

Compose interpolates local environment variables into its service settings.
Kubernetes separates credentials from ConfigMaps and references them by key.

## 9. PersistentVolumeClaim

`postgres/pvc.yaml` requests 5 GiB with `ReadWriteOnce`, matching the Compose
named volume's role of keeping data outside the replaceable database
container. The PostgreSQL Deployment mounts it at
`/var/lib/postgresql/data` and stores its cluster under the configured `PGDATA`
subdirectory.

No `storageClassName` is pinned; Kubernetes uses the cluster's default Storage
Class. A cluster without a default class needs an explicit class name. The
claim is not removed by deleting a Deployment, but the PV reclaim policy is
controlled by the cluster's StorageClass.

## 10. Migration Job

`migration-job.yaml` runs `node dist/migrate.js` from the backend image once per
Job creation. It uses the same ConfigMap and database URL Secret as the API,
waits operationally for PostgreSQL through the documented deployment sequence,
and retries a failed run up to three times. It does not run in the backend
Deployment.

This maps Compose's one-shot `migrate` service to a Kubernetes Job. Kubernetes
does not guarantee ordering between arbitrary resources in one `kubectl apply`,
so deploy in phases: start PostgreSQL, wait for it to be ready, run and wait
for the migration Job, then apply the application Deployments. For a release
with new migrations, delete and recreate the completed Job with the new backend
image before rolling out the backend. Job pod templates are immutable, so
remove the completed Job before applying its changed image:

```sh
kubectl delete job leadflow-migrate -n leadflow
kubectl apply -n leadflow -f k8s/migration-job.yaml
kubectl wait --for=condition=complete job/leadflow-migrate \
  -n leadflow --timeout=5m
```

Prefer backward-compatible, expand / contract database changes when old and
new API pods can overlap.

## 11. Health probes

- PostgreSQL uses `pg_isready` for startup, liveness, and readiness probes.
- The backend uses `/healthz` for startup and liveness. Its `/readyz` probe
  checks the database connection and controls whether a pod receives Service
  traffic.
- The frontend probes `/`, an existing route also used by its Docker
  HEALTHCHECK. No new application health endpoint is assumed.

Startup probes give slow-starting processes time to initialize before
liveness checks begin. Readiness failures remove pods from Service endpoints
without restarting them.

## 12. Resource requests and limits

Each container defines CPU and memory requests and limits, including the
migration and PostgreSQL permission-init containers. Requests provide scheduler
reservations; limits cap consumption. These are conservative starting values
for the assignment, not measured production sizing. Tune them using load tests,
container metrics, and PostgreSQL workload data.

## 13. Rolling updates

The frontend and backend use Deployment rolling updates with one extra pod
allowed and no unavailable replicas during rollout. Readiness probes prevent
traffic reaching a new pod before it can serve. The API's 30-second
termination grace period accommodates its existing graceful shutdown handler.

PostgreSQL is a single-replica Deployment with `Recreate`, not a rolling
database cluster. Its persistent volume survives pod replacement, but there
is a brief database outage during rescheduling or restart.

## 14. Ingress

`ingress.yaml` uses the `networking.k8s.io/v1` API, declares the `nginx`
IngressClass, and routes the `/` prefix to `frontend:80`. This is the
Kubernetes equivalent of publishing the frontend entry point in Compose.

No hostname or TLS certificate is present in the repository, so the rule has
no host constraint and no TLS section. Before public deployment, set the
application hostname, configure TLS (for example via cert-manager), and
confirm the NGINX Ingress Controller is installed.

## 15. Networking

Kubernetes Services replace Compose service discovery:

- API `DATABASE_URL` points to `postgres:5432`.
- The frontend image's build-time Next.js rewrite points to
  `backend:3000`.
- Ingress points to the `frontend` Service.

These are DNS names, not pod IPs. The backend and Postgres Services are
cluster-internal. The frontend communicates with the API through its own
Next.js server, so browser code continues to use the existing relative
`/api/...` paths.

## 16. Security context

The backend, frontend, migration Job, and PostgreSQL process run as non-root.
Application containers drop all Linux capabilities, disallow privilege
escalation, use the runtime-default seccomp profile, and use read-only root
filesystems. Writable temporary/cache paths are mounted as `emptyDir`.
Service-account token mounting is disabled because these workloads do not call
the Kubernetes API.

The PostgreSQL pod has a narrowly scoped init container that runs as UID 0
with only `CHOWN` capability to set ownership on a newly provisioned volume.
The database process itself runs as UID/GID 999. This avoids running the
database server as root while making PVC ownership explicit. Do not mark the
pod privileged.

## 17. Why ConfigMaps and Secrets are separate

ConfigMaps contain values that can be reviewed and versioned as ordinary
configuration. The database username/password and full connection URL are
credentials and belong in a Secret. Deployments reference each resource
explicitly, reducing accidental exposure of credentials in the
Kustomization or ConfigMaps. Secret manifests still require careful access
control and encryption at rest.

## 18. Failure recovery

Kubernetes restarts failed containers according to the owning workload's
controller. Liveness probes recover stuck application processes; readiness
probes stop routing traffic to unhealthy pods. A failed migration Job blocks
the documented rollout sequence and must be investigated before deploying the
API. PostgreSQL pod replacement reuses the PVC.

The PVC is persistence, not backup. Back up PostgreSQL and test restoration.
The single database pod remains a single point of failure.

## 19. Scaling

Frontend and backend replicas are set to two for basic availability and can be
adjusted. The frontend Service and Ingress distribute requests across ready
frontend pods; the backend Service distributes API requests across ready API
pods. At the configured pool size of 10, two backend replicas can open up to
20 PostgreSQL connections, so scale with the database connection budget in
mind.

PostgreSQL remains at one replica and must not be scaled by increasing the
Deployment replica count; multiple independent database pods must not share
this single-writer PVC.

## 20. Production considerations and deployment

The image references are placeholders because no registry or image tags are
defined in Compose. Build and push the existing Dockerfiles under real,
versioned registry references, then update the image fields in the backend,
frontend, and migration manifests. The frontend image must be built with
`API_INTERNAL_URL=http://backend:3000`, as required by its existing Dockerfile
and Next.js rewrite configuration. For example, after replacing the registry
placeholder:

```sh
docker build -t registry.example.com/team/leadflow-api:1.0.0 ./backend
docker build \
  --build-arg API_INTERNAL_URL=http://backend:3000 \
  -t registry.example.com/team/leadflow-web:1.0.0 \
  ./frontend
docker push registry.example.com/team/leadflow-api:1.0.0
docker push registry.example.com/team/leadflow-web:1.0.0
```

Prepare a private copy of the Secret example with actual credentials. Do not
commit the populated file. The deployment sequence is:

1. Apply `namespace.yaml`, the Secret, and the ConfigMaps and storage/service
   resources needed by PostgreSQL and the migration Job.

   ```sh
   kubectl apply -f k8s/namespace.yaml
   # Apply a privately edited copy of the Secret example.
   kubectl apply -n leadflow -f /secure/path/leadflow-db-secret.yaml
   kubectl apply -n leadflow \
     -f k8s/postgres/configmap.yaml \
     -f k8s/postgres/pvc.yaml \
     -f k8s/postgres/service.yaml \
     -f k8s/postgres/deployment.yaml
   kubectl apply -n leadflow -f k8s/backend/configmap.yaml
   ```

2. Wait for PostgreSQL readiness:

   ```sh
   kubectl wait --for=condition=Ready pod \
     -l app.kubernetes.io/name=postgres -n leadflow --timeout=5m
   ```

3. Apply `migration-job.yaml` and wait for completion:

   ```sh
   kubectl apply -n leadflow -f k8s/migration-job.yaml
   kubectl wait --for=condition=complete job/leadflow-migrate \
     -n leadflow --timeout=5m
   ```

4. Apply the remaining manifests, or reconcile the complete set with
   `kubectl apply -k k8s` after the migration has succeeded.

Inspect the rendered resources with `kubectl kustomize k8s` before applying.
For a real production environment, configure private registry pull credentials
if needed, TLS and a real hostname, storage capacity/class, database backup
and restore, monitoring/alerts, and resource values based on measurements.

## 21. Future improvements

- Replace the single PostgreSQL Deployment with a managed database or a
  PostgreSQL operator providing backups and failover.
- Use an external Secret manager and enable cluster Secret encryption.
- Add NetworkPolicies, PodDisruptionBudgets, and resource autoscaling for the
  stateless services.
- Automate the pre-rollout migration Job in a release pipeline while
  preserving explicit success gating.
- Add hostname/TLS configuration, metrics, dashboards, and database connection
  monitoring.

## Kubernetes object mapping

| Object | Why it exists and how it interacts | Compose equivalent |
|---|---|---|
| Namespace `leadflow` | Scopes project resources and DNS. | Compose project boundary. |
| PostgreSQL ConfigMap | Supplies non-secret database name and data directory. | Database environment. |
| PostgreSQL PVC | Persists database files across pod replacement. | `postgres_data` named volume. |
| PostgreSQL Service | Stable internal endpoint `postgres:5432`. | `database` service name/network. |
| PostgreSQL Deployment | Runs one database pod with probes and PVC. | `database` container. |
| Backend ConfigMap and Secret | Supplies API settings separately from DB credentials. | Backend environment interpolation. |
| Backend Deployment | Reconciles API replicas and rollout health. | `backend` service container. |
| Backend Service | Stable internal API endpoint `backend:3000`. | Compose backend network name. |
| Frontend ConfigMap | Supplies Next.js runtime host/port settings. | Frontend environment. |
| Frontend Deployment | Reconciles Next.js replicas and rollout health. | `frontend` service container. |
| Frontend Service | Internal HTTP target for Ingress. | Published frontend port within Compose. |
| Migration Job | Applies the checked-in SQL migrations before API rollout. | One-shot `migrate` service. |
| Ingress | Routes cluster entry traffic to frontend Service. | Host-published frontend plus proxy routing. |
| Kustomization | Groups manifests and applies the namespace. | No direct Compose object; deployment bundle. |
