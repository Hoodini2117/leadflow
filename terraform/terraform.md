# Terraform architecture decisions

## Why the YAML wrapper was discarded

The previous Terraform configuration read Kubernetes YAML and passed generic
manifest objects to a provider. That is a useful migration bridge when YAML
must remain the executable source, but it does not meet the goal of having
Terraform define and own the infrastructure model.

The current implementation defines each Namespace, Secret, ConfigMap, PVC,
Deployment, Service, Job, and Ingress with its corresponding typed
`hashicorp/kubernetes` resource. No Terraform resource reads, decodes, writes,
or applies Kubernetes YAML. The `k8s/` directory remains in the repository as
the original reference implementation only.

Native resources expose the fields Terraform manages as typed attributes,
provide resource-specific validation and diffs, and allow dependencies to be
expressed through module outputs. They are more verbose than generic
manifests, but they make the ownership model explicit and catch more
configuration errors before the API receives a request.

## Deployment architecture

```text
Developer
    |
    v
Terraform local environment
    |
    v
Reusable native-resource modules
    |
    v
HashiCorp Kubernetes provider
    |
    v
Existing Kind cluster
    |
    v
LeadFlow Kubernetes resources
```

Kind is an external prerequisite. Terraform uses the selected kubeconfig
context to create resources inside the cluster; it does not create the cluster
or cloud infrastructure.

## Why modules

Each module owns one coherent part of the application:

- Namespace and configuration boundaries are isolated from workloads.
- PostgreSQL owns its persistent volume claim, Deployment, and Service.
- Migration is an independent Job that blocks backend rollout until
  completion.
- Backend and frontend each own their Deployment and Service.
- Networking owns the Ingress and can later grow to include related
  Kubernetes networking resources.

The `environments/local` root composes these modules, selects the Kind
context, provides configuration, and publishes consolidated outputs. Module
outputs carry names and ports to dependent modules so identifiers are not
repeated throughout the root.

## Terraform state and first deployment

The first Terraform apply creates the objects and records their Kubernetes
identities in local state. This configuration intentionally has no import
blocks or import workflow. Start from a clean namespace; if identically named
objects already exist outside this state, stop and resolve that lifecycle
before applying rather than allowing duplicate ownership.

Terraform state maps resource addresses to Kubernetes object identity and
records values needed to calculate future plans. Secret values are sensitive
in the CLI but remain present in state. Local state must be protected and
excluded from source control; team use should configure encrypted remote
state with access control and locking.

Terraform should remain the sole writer for these resources. Mixing manual
`kubectl apply` changes with Terraform can produce drift and confusing
ownership conflicts.

## PVC binding and provider waits

The Kind `standard` StorageClass uses `WaitForFirstConsumer`. The Kubernetes
provider defaults `kubernetes_persistent_volume_claim_v1.wait_until_bound` to
`true` and otherwise waits up to its PVC create timeout for `Bound`. Binding
cannot occur until Kubernetes schedules a Pod that consumes the claim. If
Terraform waits for `Bound` before creating the PostgreSQL Deployment, the
Deployment is downstream of a wait that only that Deployment's Pod can
resolve.

The PostgreSQL module therefore sets `wait_until_bound = false`. Terraform
returns after the API accepts the PVC, then creates the Deployment. Kubernetes
schedules its Pod and provisions/binds the volume. The Deployment's rollout
wait then confirms the database is running before the Service and migration
Job proceed. This is a provider-wait setting, not a manual workaround or a
change to the StorageClass.

## Tooling comparison

| Tool | Primary role | Role in this project |
|---|---|---|
| Terraform | Declarative infrastructure lifecycle, state, dependency graph, and plans | Owns typed Kubernetes resources and composes reusable modules |
| `kubectl` | Imperative Kubernetes API client | Useful for diagnostics and emergency inspection; not the deployment owner |
| Kustomize | Template-free YAML overlays and composition | Kept with the reference manifests; not invoked by Terraform |
| Helm | Package manager and templating/release mechanism for Kubernetes applications | A future option if the app becomes a versioned chart with many values |
| GitOps | Continuous reconciliation from version control by an in-cluster controller | A future alternative or complement for teams that prefer pull-based deployment |

Wrapping `kubectl apply` or applying generic YAML from Terraform tracks a
command or opaque manifest rather than a strongly typed resource graph. Native
resources are the direct fit for this assignment's requirement that Terraform
itself model each Kubernetes object.

## Scalability and maintainability

The module boundary keeps the local root readable and makes application
components easier to review independently. Reusable inputs and outputs allow
additional environments to use the same workload modules without duplicating
resource definitions.

The current deployment remains intentionally small: a single PostgreSQL
instance, one namespace, and a single Ingress. Module reuse does not make
single-instance PostgreSQL highly available; database replication, backup,
restore, and storage failure handling remain separate production concerns.

Native Terraform resources are explicit and somewhat more verbose than YAML
decoding. That trade-off buys typed plans, module-level APIs, lifecycle
ownership, and direct Terraform validation. Changes to Kubernetes resource
shape must be made in the Terraform module; the reference YAML should not be
treated as an alternate deployable source after Terraform adoption.

## Future improvements

1. **Remote state:** Move state to an encrypted, access-controlled backend
   with locking and recovery procedures.
2. **Terraform Cloud or another managed runner:** Centralize state, policy
   checks, approval gates, and audited plans.
3. **Multiple environments:** Add environment roots (for example `staging`
   and `production`) with separate state and environment-specific variables.
4. **CI/CD:** Run formatting, validation, security checks, and saved-plan
   review on changes; require approval before apply.
5. **Helm:** Consider a chart if the application needs a distributable,
   versioned package with a broad values interface. Avoid managing the same
   objects simultaneously through both Helm and native Terraform resources.
6. **GitOps:** Consider Flux or Argo CD if continuous pull-based reconciliation
   from Git becomes preferable to Terraform-driven deployment.
7. **Production data services:** Add tested backups, restore drills, storage
   monitoring, and a supported PostgreSQL HA approach before production use.
