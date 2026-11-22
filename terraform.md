# Terraform and the LeadFlow Kubernetes deployment

## Why Terraform was introduced

LeadFlow's Kubernetes YAML is already tested and remains the source of truth
for workload details. Terraform adds a repeatable, stateful deployment
workflow around those manifests without translating every Deployment,
Service, probe, and security setting into a second representation.

The Terraform root targets the existing local Kind cluster only. It does not
provision a cloud account, managed Kubernetes cluster, or cloud networking.

## Architecture

```text
Developer
    |
    v
Terraform configuration and local state
    |
    v
HashiCorp Kubernetes provider
    |
    v
Existing local Kind cluster
    |
    v
Namespace, Secret, ConfigMaps, PVC, Deployments,
Services, migration Job, and Ingress
```

The provider reads the kubeconfig context selected by `kube_context`. The
manifest resources read the individual YAML documents under `../k8s/`; the
Kubernetes API remains responsible for creating and reconciling the objects.

## Terraform state and adopting the existing cluster

Terraform state maps resource addresses such as
`kubernetes_manifest.backend_deployment` to concrete objects in the
`leadflow` namespace. It records object identity and the last values managed
by Terraform, enabling a plan to compare configuration with the cluster.

Because this Kind cluster was initially deployed with `kubectl apply -k`,
`imports.tf` includes declarative import blocks for the existing objects,
including the manually created database Secret. The first `terraform apply`
adopts them into state before reconciling the configured values. Review that
first plan carefully, especially Secret values and the PVC. Terraform must
then be the owner of these resources; avoid applying the same objects with
`kubectl` afterward.

The local state file can contain Secret contents. Terraform's `sensitive`
marking redacts normal CLI output but does not encrypt state. Keep local state
out of source control and use an encrypted, access-controlled remote backend
for team use.

## Why keep the Kubernetes manifests as the source of truth

The YAML has already been validated and successfully deployed to Kind.
Reading those files with `yamldecode(file(...))` avoids maintaining equivalent
resource bodies in HCL. Engineers can review Kubernetes-native settings in
their normal format, and those manifests remain available to `kubectl` and
Kustomize workflows.

Terraform only supplies deployment-time concerns that belong in its workflow:
the selected namespace/context, secret values, image references, replica
counts, database name, and storage request. It also reproduces Kustomize's
namespace assignment and adds explicit dependency/wait edges. This prevents
the Terraform configuration from silently becoming a second full copy of the
application architecture.

The trade-off is that each YAML file must be registered in `main.tf` and
`imports.tf` when the manifest set changes. The Terraform root deliberately
does not execute `kubectl apply -k`; that command would make Terraform track a
shell action rather than each Kubernetes object.

## Provider choice

The official Kubernetes provider's `kubernetes_manifest` resource is used for
the existing YAML. It supports arbitrary Kubernetes objects, server-side
apply, imports, explicit dependencies, and waits for Deployments and Jobs.
The native `kubernetes_secret_v1` resource is used for generated credentials
so passwords are not placed in checked-in YAML.

The third-party `kubectl` provider is a reasonable alternative for directly
applying a directory or Kustomize output. It is less suitable here because
Terraform needs to control an ordered migration workflow, override selected
manifest values, and track each object in state. A `local-exec` wrapper around
`kubectl apply -k` would be simpler but would not provide equivalent
per-resource state or drift plans.

## Deployment ordering

Terraform uses explicit `depends_on` edges and provider waits:

1. Namespace
2. Secret
3. ConfigMaps
4. PersistentVolumeClaim
5. PostgreSQL Deployment, waited until rollout
6. PostgreSQL Service
7. Migration Job, waited until `Complete=True`
8. Backend Deployment, waited until rollout
9. Backend Service
10. Frontend Deployment, waited until rollout
11. Frontend Service
12. Ingress

This preserves the existing design: the Job runs migrations separately, and
the backend Deployment does not run them on startup. Kubernetes API access is
required during planning because the manifest provider discovers resource
schemas from the target cluster.

## Team advantages

- One reviewable set of Kubernetes workload definitions instead of parallel
  YAML and HCL copies.
- Plans show per-object changes and imports before they reach the cluster.
- Terraform state records ownership and detects configuration drift.
- Explicit dependencies prevent the API rollout from racing database
  initialization or the migration Job.
- Variables allow the same manifests to use different image tags, replica
  counts, database credentials, and namespace values.
- A production team can later change the provider target or state backend
  without converting the workload definitions into cloud-specific
  infrastructure.

## Operational cautions

The defaults match the current Kind manifests, including local `latest` image
tags. Prefer immutable registry tags outside local development and ensure the
cluster can retrieve them. Terraform destroy removes managed resources and may
remove the PostgreSQL PVC; it does not back up database files. Always inspect
the destroy plan and preserve backups before cleanup.
