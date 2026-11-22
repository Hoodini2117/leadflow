# LeadFlow Terraform

This project manages the application resources inside an already-running
local Kind cluster with native resources from the official
`hashicorp/kubernetes` provider. Terraform is the infrastructure source of
truth. The YAML under `../k8s/` remains the original, human-readable reference
implementation; Terraform does not read or apply those files.

Terraform provisions Kubernetes objects only. It does not create or configure
Kind, Docker images, or cloud infrastructure.

## Architecture

```text
Developer
   |
   v
terraform/environments/local
   |
   +-- namespace
   +-- secrets and ConfigMaps
   +-- PostgreSQL PVC, Deployment, Service
   +-- migration Job
   +-- backend Deployment and Service
   +-- frontend Deployment and Service
   +-- Ingress
   |
   v
Existing Kind cluster
```

The local environment composes small modules. Modules own their Kubernetes
resources; the environment passes settings and outputs between them. The
providers are configured only in the environment root.

## Module layout

| Module | Resources |
|---|---|
| `namespace` | Namespace |
| `secrets` | Database Secret |
| `configmaps` | Backend, frontend, and PostgreSQL ConfigMaps |
| `postgres` | PersistentVolumeClaim, PostgreSQL Deployment, Service |
| `migration` | One-shot database migration Job |
| `backend` | Backend Deployment and ClusterIP Service |
| `frontend` | Frontend Deployment and ClusterIP Service |
| `networking` | Ingress routing `/` to the frontend |

`environments/local` contains provider/version configuration, variables,
module composition, outputs, and a non-secret tfvars example. It does not
define workload resources directly.

## Dependency graph

```text
Namespace
  ├── Secret ───────────────┐
  ├── ConfigMaps ───────────┼── PostgreSQL Deployment (wait for rollout)
  └── PVC ──────────────────┘             |
        (create without waiting            v
         for Bound)                 PostgreSQL Service
                                          |
                                          v
                                    Migration Job
                                    (wait for success)
                                          |
                                          v
                                    Backend Deployment
                                    (wait for rollout)
                                          |
                                          v
                                    Backend Service
                                          |
                                          v
                                    Frontend Deployment
                                    (wait for rollout)
                                          |
                                          v
                                    Frontend Service
                                          |
                                          v
                                       Ingress
```

Resource references provide the Namespace, Secret, ConfigMap, and PVC
dependencies. The PVC is deliberately created with
`wait_until_bound = false`: the Kind `standard` StorageClass uses
`WaitForFirstConsumer`, so the PostgreSQL Pod must be scheduled before storage
can bind. The PostgreSQL Deployment then waits for its rollout, which allows
Kubernetes to schedule the Pod and bind the claim. Explicit dependencies
enforce the remaining required order: Postgres Deployment before Service,
database readiness before migrations, successful migration before backend,
and backend before frontend. The Ingress refers to the frontend Service.

## How to deploy

Use Terraform 1.5 or newer and an existing Kind cluster. In this environment
the configured kubeconfig context defaults to `kind-leadflow`; override
`kube_context` if the cluster uses a different context.

```sh
cd terraform
terraform fmt -recursive
cd environments/local
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with desired non-secret settings.
```

Provide database values through a protected environment or secret manager,
not the checked-in example:

```sh
export TF_VAR_postgres_user='your-database-user'
export TF_VAR_postgres_password='your-strong-password'
export TF_VAR_database_url='postgres://your-database-user:your-strong-password@postgres:5432/leadflow'
```

For passwords containing URL-reserved characters, URL-encode the username and
password components in `database_url`.

Run the standard workflow:

```sh
terraform init
terraform validate
terraform plan
terraform apply
```

Inspect the complete plan before applying. This configuration creates and
tracks resources directly; it does not import pre-existing objects. Use a
clean namespace for a first deployment. If objects with these names already
exist outside this state, do not apply until their lifecycle/state has been
resolved. Never apply a plan that unexpectedly replaces the PVC or changes
persistent storage.

The migration Job is waited on during apply. It runs on initial creation or
when Kubernetes requires the Job to be replaced after a spec change; the
application migration runner records applied SQL files and skips those on
subsequent executions.

## Variables and secrets

The local root exposes variables for the namespace, database, app version,
pool size, replica counts, storage, image repositories/tags, service/container
ports, CPU/memory requests and limits, ingress settings, and Kind kubeconfig
context. Defaults match the existing local deployment where safe.

`postgres_user`, `postgres_password`, and `database_url` are required and
sensitive. Terraform redacts them in normal CLI output, but the Kubernetes
provider stores Secret data in Terraform state. Do not commit state, tfvars
containing credentials, or plan files. Protect local state; use an encrypted,
access-controlled remote backend when state is shared.

## Outputs

After apply, inspect the environment outputs:

```sh
terraform output
```

The outputs include the namespace, Deployment names, migration Job name,
PostgreSQL PVC, Service names/ClusterIPs/ports, and Ingress class/hostname.

## Destroy

Review the destroy plan before removing resources:

```sh
terraform plan -destroy
terraform destroy
```

Destroying the PostgreSQL PVC can permanently delete database data. Back up
data first and verify that the PVC is included in the destroy plan. The
existing Kind cluster itself is not managed or destroyed by this project.

## Operational notes

- The frontend image must be built with `API_INTERNAL_URL=http://backend:3000`
  because the current Next.js API rewrite is configured at build time.
- Local image tags default to `latest` to match the existing Kind deployment.
  Prefer immutable tags from a registry for shared or production clusters.
- The PostgreSQL workload intentionally remains at one replica with one
  `ReadWriteOnce` volume. Horizontal database scaling needs a separate HA and
  storage design.
- This configuration does not install an Ingress controller. The Kind cluster
  must already have the `nginx` Ingress class available.
