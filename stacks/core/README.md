# Core Stack

This stack manages **plane-level core infrastructure** that sits on top of the shared network, typically shared services used by multiple environments.

---

## Scope

- Core/shared services at the **plane** level (nonprod/prod), for both:
  - Azure Government (`hrz`)
  - Azure Commercial (`pub`)
- Consumes and builds upon the networking created by the `shared-network` stack.

---

## Files

```text
backend.tf       # Remote backend configuration
main.tf          # Core Terraform configuration
variables.tf     # Stack inputs
outputs.tf       # Stack outputs
tfvars/
  np.hrz.tfvars
  np.pub.tfvars
  pr.hrz.tfvars
  pr.pub.tfvars
```

---

## Inputs & tfvars

Planes are abbreviated in the tfvars filenames:

| Plane    | Abbrev | Product | tfvars file     |
|----------|--------|---------|-----------------|
| nonprod  | np     | hrz     | `np.hrz.tfvars` |
| nonprod  | np     | pub     | `np.pub.tfvars` |
| prod     | pr     | hrz     | `pr.hrz.tfvars` |
| prod     | pr     | pub     | `pr.pub.tfvars` |

Typical variables:

- `product` → `hrz` or `pub`
- `plane` or equivalent → `np` / `pr` (mapped to nonprod/prod)

> Recommended improvement: consider renaming `np`/`pr` to `nonprod`/`prod` over time for consistency with `shared-network`.

---

## Dependencies

- **Requires** `shared-network` to be deployed for the same plane and product.
- **Provides** shared/core services consumed by environment-specific stacks (`platform-app`, `observability`).

---

## Related Workflows

- Plan: `workflows/core-plan.yml`
- Apply: `workflows/core-apply.yml`

These workflows:

- Accept `product` (`hrz`, `pub`) and `plane` (`np`, `pr`) as inputs
- Run Terraform in `stacks/core/`
- Select the matching `tfvars` file

---

## How to Run (Example)

From GitHub:

1. Trigger **Core Plan**:
   - Workflow: `core-plan.yml`
   - Inputs: `product=hrz`, `plane=np`
2. Review the plan.
3. Trigger **Core Apply**:
   - Workflow: `core-apply.yml`
   - Same inputs.

From CLI (conceptually):

```bash
cd stacks/core

terraform init   -backend-config=...
terraform plan   -var-file=tfvars/np.hrz.tfvars
terraform apply  -var-file=tfvars/np.hrz.tfvars
```
