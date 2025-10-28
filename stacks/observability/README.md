# Observability Stack

This stack attaches **Azure Monitor Diagnostic Settings** to resources created by the other stacks and routes logs/metrics to **Log Analytics Workspace (LAW)**. It also adds a couple of essential **Activity Log alerts** and a simple **Workbook**.

## How it finds resources
- Reads remote state for:
  - `shared-network` (by `plane`: nonprod/prod)
  - `core` (by `plane_code`: np/pr)
  - `platform-app` (by `env`: dev/qa/uat/prod)
- Picks IDs from each stack's `outputs`. LAW is taken from Core (`outputs.ids.law`) by default.

## What it configures
- `azurerm_monitor_diagnostic_setting` for: Key Vault, Storage Account, Service Bus Namespace, Event Hub Namespace, PostgreSQL Flexible, Redis, Recovery Services Vault, App Insights, VPN Gateway.
- Alerts:
  - Administrative changes in the platform resource group
  - Service Health incidents in the subscription
- Workbook: a small overview pinned to the Core RG.

## Inputs
See `variables.tf`. Keep backend init consistent with the rest of your repo (state RG/SA/container and key naming are already aligned).

## Apply
```
terraform init   # same backend as others
terraform plan   -var "product=hrz" -var "env=prod"
terraform apply  -auto-approve
```
