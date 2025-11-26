# Platform Registry Stack

## Overview

The **Platform Registry** stack provisions a **shared Azure Container Registry (ACR)** that is:

- Deployed **only in Azure Government**
- Always **production** plane (no nonprod variant)
- Intended to be **shared by multiple workloads** (AKS clusters, app services, jobs, etc.)

This stack is designed to be deployed once per Gov subscription and then referenced by other stacks and CI/CD pipelines.

---

## What This Stack Creates

In its current form, the stack creates:

1. A **resource group** to hold the registry (for example: `rg-core-pr-usaz-01-reg`).
2. A single **Azure Container Registry** (ACR) (for example: `acrintterra`).

The ACR is configured with:

- Configurable **SKU** (default: `Premium`)
- Optional **zone redundancy** (where supported)
- **Retention policy** for untagged manifests
- Optional **RBAC role assignments** (e.g., `AcrPull`, `AcrPush`) for specific principals

---

## Terraform Layout

```text
stacks/platform-registry/
  main.tf
  variables.tf
  outputs.tf
  tfvars/
    pr.hrz.tfvars
  README.md   (this file)
```

- **`main.tf`** – Provider, RG, and ACR module wiring.
- **`variables.tf`** – Inputs such as `subscription_id`, `tenant_id`, `location`, `registry_name`, etc.
- **`outputs.tf`** – Exposes the registry name, ID, and login server.
- **`tfvars/prod.tfvars`** – Opinionated defaults for the Gov / prod deployment.
- **`README.md`** – Stack documentation.

---

## Inputs (`variables.tf`)

Key inputs:

- `subscription_id` (**string**, required)  
  Subscription where the registry will be created (Azure Gov).

- `tenant_id` (**string**, required)  
  Entra ID tenant ID used by the provider.

- `location` (**string**, default: `USGov Arizona`)  
  Azure Gov region display name for the RG/ACR.

- `resource_group_name` (**string**, default: `rg-core-pr-usaz-01-reg`)  
  Name of the resource group that will host the ACR.

- `registry_name` (**string**, default: `acrintterra`)  
  ACR name (5–50 lowercase alphanumeric). Must be globally unique across Azure.

- `acr_sku` (**string**, default: `Standard`)  
  ACR SKU — typically `Standard` or `Premium`.

- `zone_redundancy_enabled` (**bool**, default: `true`)  
  Whether to enable zone redundancy (where supported in the region).

- `retention_untagged_days` (**number**, default: `7`)  
  Number of days after which **untagged** manifests are automatically deleted.

- `role_assignments` (**list(object)**, default: `[]`)  
  Optional list of role assignments to grant on the registry. Example:
  ```hcl
  role_assignments = [
    { principal_id = "00000000-....", role_definition_name = "AcrPull" },
    { principal_id = "11111111-....", role_definition_name = "AcrPush" }
  ]
  ```

- `tags` (**map(string)**)  
  Base tag set applied to the RG and ACR. You can use this to align with your org standards (product, plane, region, owner, etc.).

---

## Outputs (`outputs.tf`)

This stack exposes the following outputs:

- `resource_group_name` – Name of the resource group created/used for the ACR.
- `acr_name` – Name of the ACR.
- `acr_id` – Full resource ID of the ACR.
- `acr_login_server` – Login server for the ACR (e.g., `acrintterra.azurecr.us`).

These can be consumed by:

- Other Terraform stacks via `terraform_remote_state`.
- CI/CD pipelines (e.g., GitHub Actions) via `terraform output` to configure docker push/pull endpoints.

---

## State & Backend

The stack is intended to use its own backend key, for example:

- **Resource group**: `rg-core-infra-state`
- **Storage account**: `sacoretfstateinfra`
- **Container**: `tfstate`
- **Key**: `platform-registry/global/prod/terraform.tfstate`

This keeps registry state isolated from the plane/env stacks while still sharing the same state storage account.

> Actual values are configured in your GitHub Actions workflows (e.g., `registry-plan.yml` / `registry-apply.yml`).

---

## GitHub Actions Workflows

Typical workflows for this stack:

- **Plan** – `registry-plan.yml`
  - Logs in to Azure Gov using OIDC.
  - Points the backend at the state subscription.
  - Runs `terraform plan` with `tfvars/prod.tfvars`.
  - Uploads the `tfplan` as an artifact and opens an approval issue.

- **Apply** – `registry-apply.yml`
  - Downloads the approved `tfplan` artifact from the plan run.
  - Runs `terraform apply tfplan` in the Gov target subscription.

These workflows follow the same patterns as the **core** stack (subscription selection, state subscription vs target subscription, approvals, etc.), but are simplified because:

- There is no nonprod variant for the registry.

---

## Usage Notes

- Deploy this stack **once**.
- Treat the ACR as a **shared global registry** for Gov workloads (AKS clusters, web apps, background workers, etc.).
- Use RBAC (`role_assignments`) to control which identities can push/pull images.

Once deployed, reference the `acr_login_server` in your CI/CD pipelines and your AKS/app-service configuration.

