# Platform Application Stack

This stack defines **environment-specific application infrastructure** (e.g., app services, databases, supporting resources) for each environment and cloud product.

---

## Scope

- Deployed **per environment**:
  - `dev`, `qa`, `uat`, `prod`
- Supports both clouds:
  - `hrz` — Azure Government
  - `pub` — Azure Commercial

Resource-level details are defined in `main.tf` using shared modules (e.g., `modules/app-service-plan`, `modules/postgres-flex`, etc.).

---

## Files

```text
backend.tf       # Remote backend configuration
main.tf          # Core Terraform configuration
variables.tf     # Stack inputs
outputs.tf       # Stack outputs
tfvars/
  dev.hrz.tfvars
  dev.pub.tfvars
  qa.hrz.tfvars
  qa.pub.tfvars
  uat.hrz.tfvars
  uat.pub.tfvars
  prod.hrz.tfvars
  prod.pub.tfvars
```

---

## Inputs & tfvars

| Env  | Product | tfvars file       |
|------|---------|-------------------|
| dev  | hrz     | `dev.hrz.tfvars`  |
| dev  | pub     | `dev.pub.tfvars`  |
| qa   | hrz     | `qa.hrz.tfvars`   |
| qa   | pub     | `qa.pub.tfvars`   |
| uat  | hrz     | `uat.hrz.tfvars`  |
| uat  | pub     | `uat.pub.tfvars`  |
| prod | hrz     | `prod.hrz.tfvars` |
| prod | pub     | `prod.pub.tfvars` |

Typical variables:

- `product` → `hrz` or `pub`
- `env` → `dev` | `qa` | `uat` | `prod`
- App-specific settings as needed

---

## Dependencies

- Requires plane-level stacks:
  - `shared-network` for networking
  - `core` for shared/core services
- Should be deployed **before** `observability` for the same env/product, so observability settings can attach to existing resources.

---

## Related Workflows

- Plan: `workflows/platform-plan.yml`
- Apply: `workflows/platform-apply.yml`

These workflows:

- Accept `product` and `env` as inputs
- Map `env` to a plane internally (e.g., `dev/qa` → nonprod, `uat/prod` → prod)
- Run Terraform in `stacks/platform-app/`
- Select the matching `tfvars` file

---

## How to Run (Example)

From GitHub:

1. Trigger **Platform App Plan**:
   - Workflow: `platform-plan.yml`
   - Inputs: `product=pub`, `env=qa`
2. Review the plan.
3. Trigger **Platform App Apply**:
   - Workflow: `platform-apply.yml`
   - Same inputs.

From CLI (conceptually):

```bash
cd stacks/platform-app

terraform init   -backend-config=...
terraform plan   -var-file=tfvars/qa.pub.tfvars
terraform apply  -var-file=tfvars/qa.pub.tfvars
```
