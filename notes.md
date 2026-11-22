# Backend Dockerfile – Design Decisions

## Objective

The objective of the backend Dockerfile is to package the Express + TypeScript API into a portable, production-ready container that can be deployed consistently across local development, CI/CD pipelines, and Kubernetes environments.

The container is designed with the following goals:

- Reproducible builds
- Lightweight runtime image
- Secure by default
- Fast build times through Docker layer caching
- Easy deployment across multiple environments
- No secrets embedded in the image

---

# Dockerfile Architecture

The Dockerfile follows a **multi-stage build** approach, separating dependency installation, application compilation, and runtime execution. This ensures that the final image only contains what is required to execute the application while excluding unnecessary development tooling.

```
Base Image
      │
      ▼
Dependencies
      │
      ▼
Builder
      │
      ▼
Production Dependencies
      │
      ▼
Runtime Image
```

---

# Stage 1 – Base Image

```dockerfile
FROM node:22.18.0-bookworm-slim AS base
```

The first stage establishes a common base image that is shared across all subsequent stages.

### Why?

Using a common base image avoids repeating configuration across multiple stages and ensures consistency throughout the build process.

The selected image:

```
node:22.18.0-bookworm-slim
```

was chosen because:

# Docker Compose Architecture

## Objective

The goal of Docker Compose is to orchestrate the entire LeadFlow application using a single command.

Instead of manually starting PostgreSQL, the backend, and the frontend separately, Docker Compose defines the complete application stack as code.

This provides:

- Consistent local development
- Simplified onboarding
- Production-like networking
- Service dependency management
- Persistent database storage

The application consists of three services:

- PostgreSQL
- Backend API
- Frontend

Each service communicates over Docker's internal network using service names instead of localhost.

# Kubernetes Implementation

## Objective

After successfully containerizing the application using Docker and Docker Compose, the next step was to deploy the same architecture on Kubernetes. The goal was to preserve the existing application structure while leveraging Kubernetes features such as Deployments, Services, Persistent Volumes, ConfigMaps, Secrets, health probes, and an Ingress controller.

Rather than redesigning the application, the Kubernetes implementation mirrors the Docker Compose architecture as closely as possible, making the transition straightforward and easier to understand.

---

## Architecture

The Kubernetes deployment consists of four primary workloads:

- PostgreSQL Database
- Database Migration Job
- Backend API (Express + TypeScript)
- Frontend Application (Next.js)

Traffic flows through the application as follows:

Browser → Ingress → Frontend Service → Backend Service → PostgreSQL Service

Instead of using `localhost`, Kubernetes Services provide stable DNS names (`frontend`, `backend`, and `postgres`) for communication between components.

---

## Kubernetes Resources

The implementation was divided into separate manifests to keep the deployment modular and maintainable.

### Namespace

A dedicated `leadflow` namespace isolates all project resources and provides a clean logical boundary for the application.

### PostgreSQL

The database is deployed as a single Deployment backed by a PersistentVolumeClaim. Persistent storage ensures that database data survives pod restarts or rescheduling.

A ClusterIP Service exposes PostgreSQL internally to the backend and migration job.

### Backend

The backend runs as a Deployment with multiple replicas for availability. Runtime configuration is supplied through a ConfigMap, while database credentials are referenced through a Secret.

Liveness and readiness probes continuously verify application health before traffic is routed to the pods.

### Frontend

The frontend is deployed separately and exposed through its own Service. An Ingress routes external traffic to the frontend while the Next.js application communicates with the backend using Kubernetes Service DNS.

### Migration Job

Database migrations are executed using a dedicated Kubernetes Job instead of running them inside the backend container.

This ensures migrations execute exactly once before new backend pods are deployed, closely matching production deployment practices.

---

## Networking

Kubernetes Services replace Docker Compose networking.

Each workload communicates using internal DNS:

- Frontend → Backend Service
- Backend → PostgreSQL Service

This eliminates any dependency on localhost or hardcoded IP addresses and allows pods to be replaced without changing application configuration.

---

## Configuration Management

Application configuration is separated into two categories:

- ConfigMaps for non-sensitive configuration such as application ports and runtime settings.
- Secrets for sensitive information including database credentials and connection strings.

Separating configuration from credentials follows Kubernetes best practices while making deployments easier to manage.

---

## Health Monitoring

Every application component includes health checks.

- Startup probes allow containers sufficient initialization time.
- Liveness probes detect failed containers and automatically restart them.
- Readiness probes ensure traffic is only sent to healthy pods.

These mechanisms improve application reliability and reduce downtime during deployments.

---

## Storage

A PersistentVolumeClaim replaces the Docker Compose named volume used for PostgreSQL.

This allows the database to retain its data independently of the lifecycle of the PostgreSQL pod.

---

## Deployment Strategy

The deployment follows a controlled sequence:

1. Deploy PostgreSQL and persistent storage.
2. Wait for the database to become healthy.
3. Execute the migration Job.
4. Deploy the backend API.
5. Deploy the frontend application.
6. Expose the application through the Ingress.

This sequence ensures that the backend never starts against an outdated database schema.

---

## Security

Several Kubernetes security best practices were incorporated into the manifests:

- Containers run as non-root users.
- Linux capabilities are minimized.
- Privilege escalation is disabled.
- Runtime configuration is separated from secrets.
- Database credentials are never stored directly inside the manifests.

---

## Outcome

The Kubernetes implementation successfully reproduces the Docker Compose architecture while introducing production-oriented orchestration features.

Compared to the Docker Compose deployment, Kubernetes provides:

- Automated pod recovery
- Rolling application updates
- Service discovery through DNS
- Persistent storage management
- Centralized configuration
- Health monitoring
- Improved scalability
- Better separation of infrastructure responsibilities

The resulting deployment provides a strong foundation for future enhancements such as Horizontal Pod Autoscaling, monitoring, external secret management, TLS-enabled Ingress, and a fully automated CI/CD deployment pipeline.This architecture closely mirrors how the application will later be deployed in Kubernetes, making the transition from local development to orchestration much smoother.- Node.js 22 is the current LTS release.

# LeadFlow Kubernetes Deployment Notes

## Overview

Successfully deployed the complete LeadFlow application onto a local Kind Kubernetes cluster using OpenTofu and native HashiCorp Kubernetes resources.

Final deployment includes:

- Namespace
- Secrets
- ConfigMaps
- Persistent Volume Claim
- PostgreSQL Deployment
- PostgreSQL Service
- Database Migration Job
- Backend Deployment (2 replicas)
- Backend Service
- Frontend Deployment (2 replicas)
- Frontend Service
- NGINX Ingress
- Persistent Storage

Application is accessible via:

http://localhost

---

# Deployment Flow

Infrastructure is provisioned in the following order:

Namespace
↓
Secrets
↓
ConfigMaps
↓
Persistent Volume Claim
↓
PostgreSQL Deployment
↓
PostgreSQL Service
↓
Migration Job
↓
Backend Deployment
↓
Backend Service
↓
Frontend Deployment
↓
Frontend Service
↓
Ingress

The migration job must complete successfully before the backend starts, ensuring the database schema is available before the application launches.

---

# Challenges Faced

## 1. Namespace Already Exists

### Issue

Terraform failed with:

```
namespaces "leadflow" already exists
```

### Cause

The namespace had been created manually during previous testing but was not tracked in Terraform state.

### Resolution

Deleted the existing namespace and recreated the infrastructure entirely through OpenTofu so Terraform became the single source of truth.

---

## 2. PVC Deadlock During Apply

### Issue

Terraform stopped with:

```
client rate limiter Wait returned an error:
context deadline exceeded
```

PostgreSQL Deployment was never created.

### Cause

The Kubernetes provider waited for the Persistent Volume Claim to become Bound.

The default Kind StorageClass uses:

```
VolumeBindingMode: WaitForFirstConsumer
```

A PVC in this mode only binds after a Pod is scheduled.

Terraform was waiting for the PVC.

The Deployment could not be created until Terraform finished waiting.

This created a provider-side deadlock.

### Resolution

Configured the PVC resource with:

```hcl
wait_until_bound = false
```

Terraform now creates the PVC and immediately continues.

Kubernetes performs the binding automatically after the PostgreSQL Pod is scheduled.

---

## 3. Missing NGINX Ingress Controller

### Issue

The application was only accessible using:

```
kubectl port-forward
```

The Ingress resource existed but localhost returned errors.

### Cause

An Ingress resource alone does not process traffic.

No Ingress Controller was installed in the Kind cluster.

### Resolution

Installed the official NGINX Ingress Controller.

Verified:

```
kubectl get pods -n ingress-nginx
kubectl get ingress -n leadflow
```

Ingress received the localhost address and routing worked correctly.

---

## 4. Local Docker Images Missing After Cluster Recreation

### Issue

Migration Job failed with:

```
ImagePullBackOff
```

```
ErrImagePull
```

### Cause

Kind clusters do not automatically use Docker images from the host machine.

Recreating the Kind cluster removed all previously loaded images.

Kubernetes attempted to pull:

```
docker.io/library/leadflow-migrate:latest
```

which does not exist.

### Resolution

Loaded locally built images into the Kind cluster:

```bash
kind load docker-image leadflow-backend:latest --name leadflow
kind load docker-image leadflow-frontend:latest --name leadflow
kind load docker-image leadflow-migrate:latest --name leadflow
```

After loading the images, the Job started successfully.

---

## 5. Migration Job Timeout

### Issue

Migration Job failed after five minutes.

Terraform reported:

```
Job is in failed state
```

### Cause

Initially investigated database connectivity, Kubernetes resources, ConfigMaps and Secrets.

Eventually determined the failure occurred because the migration image was not available inside the recreated Kind cluster.

The timeout was a consequence of the Job never starting successfully.

### Resolution

Loaded the migration image into Kind and reran the deployment.

The migration completed successfully in approximately two seconds.

---

## 6. Understanding Infrastructure Responsibilities

### Observation

Initially expected Terraform to create the Kubernetes cluster.

### Learning

OpenTofu provisions Kubernetes resources only.

Cluster lifecycle is separate from infrastructure lifecycle.

The Kind cluster must exist before executing:

```
tofu init
```

or

```
tofu apply
```

---

# Final Healthy Deployment

Pods

- PostgreSQL Running
- Backend Running (2 replicas)
- Frontend Running (2 replicas)
- Migration Job Completed

Deployments

- PostgreSQL Ready
- Backend Ready
- Frontend Ready

Services

- PostgreSQL Service
- Backend Service
- Frontend Service

Ingress

- NGINX Ingress Controller
- localhost routing functional

Application

```
http://localhost
```

---

# Useful Verification Commands

View all application resources

```bash
kubectl get all -n leadflow
```

Check Deployments

```bash
kubectl get deployments -n leadflow
```

Check Services

```bash
kubectl get svc -n leadflow
```

Check Ingress

```bash
kubectl get ingress -n leadflow
```

Check Migration Job

```bash
kubectl get jobs -n leadflow
kubectl logs job/leadflow-migrate -n leadflow
```

Check Cluster Health

```bash
kubectl get pods -A
```

---

# Key Learnings

- OpenTofu provisions infrastructure but does not create Kubernetes clusters.
- Kind clusters are ephemeral and lose locally loaded Docker images when recreated.
- Native HashiCorp Kubernetes resources are sufficient to deploy a production-style application without Helm or YAML manifests.
- Persistent Volume Claims using `WaitForFirstConsumer` require careful handling with the Kubernetes provider to avoid deployment deadlocks.
- Ingress resources require an Ingress Controller to route external traffic.
- Database migrations should execute as a Kubernetes Job before application deployments.
- Validating each infrastructure layer individually (storage, database, migration, backend, frontend, ingress) significantly simplifies troubleshooting.