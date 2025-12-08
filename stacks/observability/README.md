# Observability Stack

This stack manages **environment-specific observability and diagnostics** configuration for platform and core resources.

It now also includes:

- **NSG Flow Logs & Traffic Analytics** (enabled per environment/product)
- **Policy Non-Compliance Alerting Pipeline** using a Logic App that receives Microsoft Policy Insights events and generates **email alerts**

These additions extend the monitoring coverage beyond basic diagnostic settings by ensuring network visibility and compliance visibility.

---

## Scope

- Configures diagnostics and log routing per **environment** and **product**, such as:
  - Diagnostic settings for compute, networking, storage, PaaS resources
  - Log Analytics workspace ingestion & retention
  - **NSG Flow Logs + Traffic Analytics** via Network Watcher
  - **Logic App subscription to Policy State Change Events** for compliance alerts
  - Other monitoring configuration

- Environments:
  - `dev`, `qa`, `uat`, `prod`
- Products:
  - `hrz` — Azure Government
  - `pub` — Azure Commercial

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
README.md
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
- Log Analytics configuration  
- Diagnostic category enablement  
- **NSG Flow Logs enablement toggle**  
- **Policy Compliance Alerts (Logic App) enablement + email targets**

---

## New Features in This Stack

### NSG Flow Logs + Traffic Analytics
This stack now automatically:

- Detects the correct Network Watcher for the environment
- Creates an NSG Flow Logs diagnostic resource
- Routes flow logs and traffic analytics to the environment Log Analytics Workspace
- Can be enabled/disabled using a variable:  
  - `enable_nsg_flow_logs = true | false`

Flow logs provide deep visibility into network allow/deny events for auditing and security analysis.

---

### Logic App for Policy Non-Compliance Alerts
A new pipeline is deployed that:

1. Creates an **Event Grid System Topic** bound to Microsoft Policy Insights  
2. Connects it to a **Logic App**  
3. Sends **email alerts** to configured addresses whenever Azure Policy reports:
   - *NonCompliance*,  
   - *DeployIfNotExists failed*,  
   - *Audit events*, etc.

This ensures real-time visibility into configuration drift and FedRAMP-related compliance gaps.

---

## Dependencies

This stack assumes that the following have already been deployed:

- `shared-network` (for private DNS + subnets)
- `core` (for Log Analytics + Application Insights)
- `platform-app` (for application resources producing logs)

It should be deployed **after** the `platform-app` stack for the same env/product.

---

## Related Workflows

- Plan: `workflows/observability-plan.yml`
- Apply: `workflows/observability-apply.yml`

These workflows:

- Accept `product` and `env` as inputs
- Run Terraform in `stacks/observability/`
- Select the corresponding `tfvars` file
- Deploy diagnostics, NSG flow logs, and compliance alerting logic

---

## How to Run (Example)

### GitHub Actions

1. Trigger **Observability Plan**:
   - Workflow: `observability-plan.yml`
   - Inputs:  
     `product=hrz`, `env=prod`
2. Review the plan.
3. Trigger **Observability Apply**  
   using the same inputs.

### CLI

```bash
cd stacks/observability

terraform init   -backend-config=...
terraform plan   -var-file=tfvars/prod.hrz.tfvars
terraform apply  -var-file=tfvars/prod.hrz.tfvars
```