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
