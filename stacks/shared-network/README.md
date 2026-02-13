# Shared Network Stack
# Test
This stack manages **plane-level shared networking** resources, such as hub virtual networks and related components, for both Azure Government (`hrz`) and Azure Commercial (`pub`).

---

## Network Architecture

A detailed breakdown of all hub and environment (dev / qa / uat / prod) virtual networks and subnets for both Azure Government (hrz) and Azure Commercial (pub) is available in the following document:

  - [`Network Overview`](../../docs/network_overview.md)

```(Includes CIDRs, subnet purposes, plane structure, and cross-subscription layout.)```

This document is designed to help contributors quickly understand how networking is structured across products and planes, and how the shared-network stack ties into application environments.

---

## Scope

- Creates and configures the shared network for a **plane**:
  - `nonprod` (shared for dev/qa, etc.)
  - `prod`
- Supports dual cloud:
  - `hrz` — Azure Government
  - `pub` — Azure Commercial

Resource-level details are defined in `main.tf` using shared modules (e.g., `modules/vnet`, `modules/network`).

---

## Files

```text
backend.tf       # Remote backend configuration
main.tf          # Core Terraform configuration
variables.tf     # Stack inputs
outputs.tf       # Stack outputs
tfvars/
  nonprod.hrz.tfvars
  nonprod.pub.tfvars
  prod.hrz.tfvars
  prod.pub.tfvars
```

---

## Inputs & tfvars

Use the `tfvars` files to select plane and product:

| Plane    | Product | tfvars file          |
|----------|---------|----------------------|
| nonprod  | hrz     | `nonprod.hrz.tfvars` |
| nonprod  | pub     | `nonprod.pub.tfvars` |
| prod     | hrz     | `prod.hrz.tfvars`    |
| prod     | pub     | `prod.pub.tfvars`    |

Typical variables (names may differ):

- `product` → `hrz` or `pub`
- `plane` → `nonprod` or `prod`
- Other network-related settings as required

---

## Dependencies

This is the **foundational network** stack for each plane. It should be deployed:

1. **Before** the `core` stack for the same plane/product
2. **Before** any environment-specific stacks (`platform-app`, `observability`) that rely on shared networking

---

## Related Workflows

- Plan: `workflows/network-plan.yml`
- Apply: `workflows/network-apply.yml`

These workflows:

- Accept `product` (`hrz`, `pub`) and `plane` (`nonprod`, `prod`) as inputs
- Run Terraform in `stacks/shared-network/`
- Select the matching `tfvars` file based on the inputs

---

## How to Run (Example)

From GitHub:

1. Trigger **Shared Network Plan**:
   - Workflow: `network-plan.yml`
   - Inputs: `product=hrz`, `plane=nonprod`
2. Review the plan output.
3. Trigger **Shared Network Apply**:
   - Workflow: `network-apply.yml`
   - Same inputs.

From CLI (conceptually):

```bash
cd stacks/shared-network

terraform init   -backend-config=...
terraform plan   -var-file=tfvars/nonprod.hrz.tfvars
terraform apply  -var-file=tfvars/nonprod.hrz.tfvars
```
