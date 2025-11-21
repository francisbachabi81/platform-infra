# Workflows — Infrastructure & Secrets

This document describes the GitHub Actions workflows stored under `workflows/`, how they map to Terraform stacks, and the intended execution order.

All workflows are currently defined in the repo root under:

```text
workflows/
  core-apply.yml
  core-plan.yml
  govern-approval.yml
  infra-secrets-provision.yml
  network-apply.yml
  network-plan.yml
  observability-apply.yml
  observability-plan.yml
  platform-apply.yml
  platform-plan.yml
```

> Note: These are source workflow files. In a live GitHub repository they may be mirrored under `.github/workflows/`.

---

## 1. Workflow → Stack Mapping

| Workflow file                    | Stack path                    | Purpose level | Notes                                  |
|----------------------------------|-------------------------------|---------------|----------------------------------------|
| `network-plan.yml`               | `stacks/shared-network/`      | Plane         | Terraform plan for shared network      |
| `network-apply.yml`              | `stacks/shared-network/`      | Plane         | Terraform apply for shared network     |
| `core-plan.yml`                  | `stacks/core/`                | Plane         | Terraform plan for core infra          |
| `core-apply.yml`                 | `stacks/core/`                | Plane         | Terraform apply for core infra         |
| `platform-plan.yml`              | `stacks/platform-app/`        | Environment   | Plan for app stack per env/product     |
| `platform-apply.yml`             | `stacks/platform-app/`        | Environment   | Apply for app stack per env/product    |
| `observability-plan.yml`         | `stacks/observability/`       | Environment   | Plan for observability per env/product |
| `observability-apply.yml`        | `stacks/observability/`       | Environment   | Apply for observability per env/product|
| `infra-secrets-provision.yml`    | `stacks/provision-secrets/`   | Secrets       | Provision/hydrate secrets using schema |
| `govern-approval.yml`            | (no direct stack)             | Governance    | Processes `/approve`/`/reject` comments|

---

## 2. Parameter Patterns and Inputs

### 2.1 Shared Network Workflows

**Files**

- `network-plan.yml`
- `network-apply.yml`

**Typical inputs**

- `product`: `hrz` or `pub`
- `plane`: `nonprod` or `prod`
- `terraform_version`: e.g. `1.13.3` (or similar)

**Behavior**

- Selects correct Azure environment/tenant/subscription based on:
  - `product` → Gov vs Commercial.
  - `plane` → nonprod vs prod.
- Initializes Terraform in `stacks/shared-network/`.
- Runs `terraform plan` or `terraform apply` with the matching `tfvars` file:
  - `nonprod.hrz.tfvars`, `nonprod.pub.tfvars`
  - `prod.hrz.tfvars`, `prod.pub.tfvars`

---

### 2.2 Core Workflows

**Files**

- `core-plan.yml`
- `core-apply.yml`

**Typical inputs**

- `product`: `hrz` or `pub`
- `plane`: `np` or `pr`
- `terraform_version`

**Behavior**

- Similar selection pattern as `network-*`, but plane is abbreviated:
  - `np` → nonprod plane
  - `pr` → prod plane
- Operates in `stacks/core/`.
- Uses plane-specific tfvars:
  - `np.hrz.tfvars`, `np.pub.tfvars`
  - `pr.hrz.tfvars`, `pr.pub.tfvars`

> Recommended improvement: normalize plane naming (`nonprod`/`prod`) across stacks and workflows.

---

### 2.3 Platform App Workflows

**Files**

- `platform-plan.yml`
- `platform-apply.yml`

**Typical inputs**

- `product`: `hrz` or `pub`
- `env`: `dev`, `qa`, `uat`, `prod`
- `terraform_version`

**Behavior**

- Maps `env` to a plane internally (conventionally):
  - `dev`, `qa` → nonprod plane
  - `uat`, `prod` → prod plane
- Operates in `stacks/platform-app/`.
- Uses env/product tfvars:
  - `dev.hrz.tfvars`, `qa.hrz.tfvars`, `uat.hrz.tfvars`, `prod.hrz.tfvars`
  - `dev.pub.tfvars`, `qa.pub.tfvars`, `uat.pub.tfvars`, `prod.pub.tfvars`

This enables environment-level deployments per cloud.

---

### 2.4 Observability Workflows

**Files**

- `observability-plan.yml`
- `observability-apply.yml`

**Typical inputs**

- `product`: `hrz` or `pub`
- `env`: `dev`, `qa`, `uat`, `prod`
- `terraform_version`

**Behavior**

- Same env → plane mapping as Platform App (nonprod vs prod).
- Operates in `stacks/observability/`.
- Uses env/product tfvars:
  - `dev.hrz.tfvars`, `qa.hrz.tfvars`, `uat.hrz.tfvars`, `prod.hrz.tfvars`
  - `dev.pub.tfvars`, `qa.pub.tfvars`, `uat.pub.tfvars`, `prod.pub.tfvars`
- Attaches diagnostics and observability settings to resources defined by other stacks.

---

### 2.5 Secrets Provisioning Workflow

**File**

- `infra-secrets-provision.yml`

**Purpose**

- Hydrates needed secrets in the correct location (e.g., Azure Key Vault and/or GitHub secrets) using the JSON schemas in:

  ```text
  stacks/provision-secrets/hrz.secrets.schema.json
  stacks/provision-secrets/pub.secrets.schema.json
  ```

**Behavior (typical)**

- Accepts `product` (`hrz` or `pub`) and possibly `env`.
- Reads corresponding schema and prompts/validates required secrets.
- Writes secrets into the appropriate Azure or GitHub context.

---

### 2.6 Governance / Approval Workflow

**File**

- `govern-approval.yml`

**Purpose**

- Handles governance/approval via GitHub issues or comments.
- Typically listens for `/approve` or `/reject` commands and then:
  - Updates status checks
  - Signals whether `*-apply` workflows are allowed to proceed.

This workflow has no direct Terraform stack but orchestrates who can trigger applies and under what conditions.

---

## 3. Recommended Execution Order

While workflows are independently triggered (often with `workflow_dispatch`), the **intended logical order** for deploying infrastructure is:

1. **Secrets Bootstrap**
   - `infra-secrets-provision.yml`  
     Ensure required secrets exist for the chosen `product` and `env/plane`.

2. **Shared Network (Plane Level)**
   - `network-plan.yml`
   - `network-apply.yml`  
   Per plane (`nonprod`, `prod`) and product (`hrz`, `pub`).

3. **Core (Plane Level)**
   - `core-plan.yml`
   - `core-apply.yml`  
   After shared networking is available for the given plane.

4. **Platform App (Environment Level)**
   - `platform-plan.yml`
   - `platform-apply.yml`  
   Per environment (`dev`, `qa`, `uat`, `prod`) and product (`hrz`, `pub`).

5. **Observability (Environment Level)**
   - `observability-plan.yml`
   - `observability-apply.yml`  
   Attach diagnostics and monitoring on top of already-deployed app/core/network layers.

> Governance (`govern-approval.yml`) runs alongside this flow to ensure apply steps occur only after appropriate approvals.

---

## 4. Suggestions for Workflow Maintainability

- **Normalize plane naming**
  - Use `nonprod` / `prod` consistently across `network-*`, `core-*`, and code/variables to reduce mapping complexity.

- **Document stack mapping in each workflow**
  - At the top of each `.yml` file, include a short comment like:
    - `# This workflow runs Terraform for stacks/shared-network`
    - `# Plane: nonprod/prod, Product: hrz/pub`

- **Consider reusable workflows / composite actions**
  - Common steps (login to Azure, select subscription, init Terraform) can be moved to a reusable workflow or composite action, then called by each stack-specific workflow for easier future extension.
