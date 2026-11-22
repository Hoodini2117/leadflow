# LeadFlow

A small lead-management app: track leads, log discussions, set follow-up reminders.

| Part | What it is | Folder |
|------|-----------|--------|
| Web UI | Next.js 16 (React, Tailwind) | `frontend/` |
| API | Express + TypeScript | `backend/` |
| Database | PostgreSQL 16 | Docker Compose or bring your own |

## Run the full stack with Docker Compose

From the repository root:

```bash
docker compose up --build
```

Compose starts PostgreSQL, applies migrations, then starts the API and web UI.
Open <http://localhost:3000>. API requests are proxied by the Next.js server to
the `backend` service over the Compose network.

The Compose defaults (`postgres` / `postgres`) match the local examples and are
for development only. Override `POSTGRES_PASSWORD` for any shared or deployed
environment. `docker compose down` stops and removes the containers but keeps
the database volume.

The UI calls the API with relative URLs (`/api/...`).

## Run it locally

You need Node 20 or newer and a PostgreSQL database.

```bash
# 0. A throwaway database (or use any Postgres you have)
docker run -d --name leadflow-db -p 5432:5432 -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=leadflow postgres:16

# 1. API
cd backend
cp .env.example .env            # then export the variables, or use your shell's way of loading them
npm ci
npm run migrate                 # creates the tables
npm run seed                    # optional sample data
npm run dev                     # http://localhost:3001

# 2. Web UI (another terminal)
cd frontend
cp .env.example .env
npm ci
npm run dev                     # http://localhost:3000
```

## Useful commands

| Where | Command | What it does |
|-------|---------|--------------|
| backend | `npm test` | Integration tests. Need `DATABASE_URL`; they empty the tables. |
| backend | `npm run lint` | Type check. |
| backend | `npm run build` / `npm start` | Compile to `dist/` and run it. |
| backend | `npm run migrate:prod` | Apply migrations from the compiled build. |
| frontend | `npm run lint` | ESLint. |
| frontend | `npm run build` | Production build (standalone output). |

## Configuration

| Variable | Where | Notes |
|----------|-------|-------|
| `DATABASE_URL` | backend | PostgreSQL connection string. Required. |
| `PORT` | backend | Default 3000. |
| `APP_VERSION` | backend | Shown by `/version`. |
| `DB_POOL_MAX` | backend | Default 10. |
| `DEV_API_URL` | frontend | Dev only. Not used in production builds. |
| `API_INTERNAL_URL` | frontend build | Compose sets this to `http://backend:3000` for the production API rewrite. |

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Liveness |
| GET | `/readyz` | Readiness (checks the database) |
| GET | `/version` | Running version |
| GET | `/api/leads` | List leads. Optional `?status=` and `?search=` |
| POST | `/api/leads` | Create a lead (`name`, `company?`, `phone?`) |
| GET | `/api/leads/:id` | Lead with its discussions |
| PATCH | `/api/leads/:id` | Update status |
| GET | `/api/leads/:id/discussions` | List discussions |
| POST | `/api/leads/:id/discussions` | Add a discussion (`note`, `follow_up_at?`) |
| GET | `/api/stats` | Dashboard numbers |

# 🚀 LeadFlow - Production Inspired DevOps Pipeline

![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)
![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?logo=terraform&logoColor=black)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)

LeadFlow is a full-stack application deployed using a production-inspired DevOps workflow. The project demonstrates Infrastructure as Code, containerization, Kubernetes orchestration, CI/CD automation, secure secret handling, automated database migrations, and rolling deployments. Every infrastructure component is provisioned from code and deployments are fully automated using GitHub Actions.

---

# 🏗️ Architecture

```text
                  GitHub Repository
                         │
                  Push to main branch
                         │
              GitHub Actions (CI/CD)
                         │
        ┌────────────────┴────────────────┐
        │                                 │
   Build & Test                    Self Hosted Runner
        │                                 │
   Docker Images                    Build Images
        │                                 │
        └──────────────┬──────────────────┘
                       │
                 OpenTofu Apply
                       │
               Kubernetes (Kind)
                       │
        ┌──────────────┼──────────────┐
        │              │              │
    Frontend       Backend      PostgreSQL
                       │
               Migration Job
                       │
                 NGINX Ingress
                       │
                 http://localhost
```

---

# ⚙️ Technology Choices

| Tool | Why it was chosen |
|------|-------------------|
| **Docker** | Ensures consistent environments across development, CI and deployment. |
| **Kind** | Lightweight local Kubernetes cluster ideal for development and testing. |
| **OpenTofu** | Open-source Infrastructure as Code tool used to provision all Kubernetes resources declaratively. |
| **GitHub Actions** | Automates testing, image building and deployment on every push. |
| **PostgreSQL** | Reliable relational database with migration support. |
| **NGINX Ingress** | Provides a single entry point and routes traffic to backend services. |

---

# 📦 Infrastructure

Infrastructure is completely managed using OpenTofu. Instead of manually creating Kubernetes resources, every deployment, service, ingress, namespace, secret and migration job is declared in code. This makes deployments reproducible, version controlled and easy to recreate on any machine.

---

# 🐳 Containerization

Each application component was containerized separately.

- Frontend
- Backend API
- Database Migration Job

Building independent images allows individual components to be deployed, updated and rolled back without affecting the rest of the system.

---

# ☸️ Kubernetes Deployment

The application is deployed onto a Kind Kubernetes cluster using OpenTofu.

Resources include:

- Namespace
- Deployments
- Services
- PostgreSQL
- Migration Job
- Ingress
- ConfigMaps
- Secrets

Rolling deployments ensure application updates occur with minimal downtime.

---

# 🔄 CI/CD Pipeline

## Continuous Integration

On every push to **main**, GitHub Actions automatically:

- Validates OpenTofu configuration
- Builds Docker images
- Runs project validation
- Deploys infrastructure
- Executes database migrations
- Performs health checks

## Continuous Deployment

A self-hosted GitHub Actions runner deploys directly to the local Kubernetes cluster by:

- Building new Docker images
- Loading images into Kind
- Running OpenTofu Apply
- Waiting for rollout completion
- Verifying application availability

---

# 🔐 Secrets Management

Security was considered throughout the project.

- No secrets are committed to Git.
- `.env.example` and `terraform.tfvars.example` are provided as templates.
- Sensitive values are stored as GitHub Secrets.
- Kubernetes Secrets are used for runtime database credentials.

This approach prevents accidental exposure of credentials while keeping deployments reproducible.

---

# 🔄 Rollback Strategy

Kubernetes provides built-in deployment rollback support.

```bash
kubectl rollout history deployment/backend -n leadflow

kubectl rollout undo deployment/backend -n leadflow
```

A failed release can be reverted using a single command while maintaining application availability.

---

# ⚠️ Challenges Faced

### Kubernetes Migration Job

The migration Job initially failed due to incorrect database connectivity and image loading. This was resolved by verifying environment variables, correcting the database connection string and ensuring images were loaded into the Kind cluster.

---

### ImagePullBackOff

Locally built Docker images were unavailable inside Kind, causing Kubernetes to pull nonexistent images from Docker Hub. Using `kind load docker-image` ensured locally built images were available to the cluster.

---

### OpenTofu State Management

Managing local state during repeated deployments caused existing Kubernetes resources to appear unmanaged. The deployment workflow was adjusted to ensure infrastructure remained synchronized with the cluster state.

---

### GitHub Actions Self-Hosted Runner

Deployments initially remained queued because no self-hosted runner was registered. After configuring the runner and required repository secrets, deployments executed successfully on the local machine.

---

### Ingress & Health Checks

Ingress validation initially returned HTTP 404 due to timing during application startup. Additional rollout verification and health checks ensured services were fully available before smoke testing.

---

# 📚 Key Learnings

- Infrastructure should always be managed as code.
- Containerization guarantees consistent environments.
- Kubernetes simplifies scaling and rolling deployments.
- GitHub Actions enables reliable CI/CD automation.
- Proper secret management is essential for production-ready systems.
- Automated migrations and health checks improve deployment reliability.

---

# 🚀 Future Improvements

- Blue/Green deployments
- Canary deployments
- Prometheus & Grafana monitoring
- Horizontal Pod Autoscaler
- TLS using cert-manager
- GitOps using ArgoCD
- Remote OpenTofu state backend

---

# ✅ Outcome

This project successfully demonstrates a production-inspired DevOps workflow by integrating Docker, Kubernetes, OpenTofu and GitHub Actions into a fully automated deployment pipeline. The infrastructure, application deployment, database migrations and CI/CD processes are all managed through code, resulting in a reproducible, scalable and maintainable deployment solution.