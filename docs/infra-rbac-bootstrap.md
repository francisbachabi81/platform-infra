# Infrastructure Bootstrap & RBAC Delegation Guide

This document describes **post–shared-network bootstrap steps**, **RBAC delegation patterns**, and **least-privilege role constraints** used by Terraform and GitHub Actions pipelines.

The approach follows Azure best practices:
- **User Access Administrator (UAA)** is delegated **with role assignment conditions**
- Pipelines can only assign **explicitly allowed roles**
- CMK, Storage, and AKS access are scoped tightly

---

## Environment Matrix

| Product | Plane    | Environments        |
|--------|----------|---------------------|
| PUB    | prod     | prod, uat (staging) |
| PUB    | nonprod  | dev, qa             |
| HRZ    | prod     | prod, uat           |
| HRZ    | nonprod  | dev, qa             |

---

## PUB / prod (prod, uat / staging)

### Prerequisites
#### Assign **Private DNS Zone Contributor** on:
```
privateDnsZones/privatelink.centralus.azmk8s.io
```

```bash
PDZ_CONTRIB_ROLE_ID="$(az role definition list \
  --name "Private DNS Zone Contributor" \
  --query "[0].name" -o tsv)"
```

```bash
echo "$PDZ_CONTRIB_ROLE_ID"
```

```bash
az role assignment create \
  --assignee-object-id "091b0bfa-694c-4bbf-8ebf-75c90cd2940b" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "/subscriptions/ec41aef1-269c-4633-8637-924c395ad181/resourceGroups/rg-pub-pr-cus-net-01/providers/Microsoft.Network/privateDnsZones/privatelink.centralus.azmk8s.io" \
  --condition-version "2.0" \
  --condition "(
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
          ForAnyOfAnyValues:GuidEquals { $PDZ_CONTRIB_ROLE_ID }
      )
    )
    AND
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
          ForAnyOfAnyValues:GuidEquals { $PDZ_CONTRIB_ROLE_ID }
      )
    )
  )"
```

#### Register resource provider:
  ```
  Microsoft.Communication
  ```

---

## Custom Role: Key Vault Keys Creator (Vault Scope)

Used for **infra bootstrap only** (key creation + metadata read).

### Role Definition (`kv-keys-creator.json`)
```json
{
  "Name": "Key Vault Keys Creator (vault-scope)",
  "IsCustom": true,
  "Description": "Can create Key Vault keys and read key metadata (no secrets/certs).",
  "Actions": [
    "Microsoft.KeyVault/vaults/keys/write",
    "Microsoft.KeyVault/vaults/keys/read"
  ],
  "NotActions": [],
  "AssignableScopes": [
    "/subscriptions/ec41aef1-269c-4633-8637-924c395ad181/resourceGroups/rg-pub-pr-cus-core-01/providers/Microsoft.KeyVault/vaults/kvt-pub-pr-cus-core-01",
    "/subscriptions/ee8a4693-54d4-4de8-842b-b6f35fc0674d/resourceGroups/rg-pub-np-cus-core-01/providers/Microsoft.KeyVault/vaults/kvt-pub-np-cus-core-01"
  ]
}
```

### Create / Update Role
```bash
az role definition create --role-definition ./kv-keys-creator.json
az role definition update --role-definition ./kv-keys-creator.json
```

---

## Delegated UAA (Key Vault — CMK only)

```bash
KV_CRYPTO_ROLE_ID="$(az role definition list --name "Key Vault Crypto Service Encryption User" --query "[0].name" -o tsv)"
```

```bash
az role assignment create --assignee-object-id "091b0bfa-694c-4bbf-8ebf-75c90cd2940b" --assignee-principal-type ServicePrincipal --role "User Access Administrator" --scope "/subscriptions/ec41aef1-269c-4633-8637-924c395ad181/resourceGroups/rg-pub-pr-cus-core-01/providers/Microsoft.KeyVault/vaults/kvt-pub-pr-cus-core-01"  --condition-version "2.0" --condition "(
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
          ForAnyOfAnyValues:GuidEquals { $KV_CRYPTO_ROLE_ID }
      )
    )
    AND
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
          ForAnyOfAnyValues:GuidEquals { $KV_CRYPTO_ROLE_ID }
      )
    )
  )"
```

---

## Delegated UAA (Storage — Blob & Queue only)

```bash
BLOB_ROLE_ID="$(az role definition list --name "Storage Blob Data Contributor" --query "[0].name" -o tsv)"

QUEUE_ROLE_ID="$(az role definition list --name "Storage Queue Data Contributor" --query "[0].name" -o tsv)"
```

```bash
az role assignment create --assignee-object-id "091b0bfa-694c-4bbf-8ebf-75c90cd2940b" --assignee-principal-type ServicePrincipal --role "User Access Administrator" --scope "subscriptions/7043433f-e23e-4206-9930-314695d94a6c/resourceGroups/rg-pub-prod-cus-01/providers/Microsoft.Storage/storageAccounts/sapubprodcus01" --condition-version "2.0" --condition "(
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
          ForAnyOfAnyValues:GuidEquals { $BLOB_ROLE_ID, $QUEUE_ROLE_ID }
      )
    )
    AND
    (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      OR (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId]
          ForAnyOfAnyValues:GuidEquals { $BLOB_ROLE_ID, $QUEUE_ROLE_ID }
      )
    )
  )"
```

---

## AKS Access (Prod)

```bash
az role assignment create --assignee-object-id "091b0bfa-694c-4bbf-8ebf-75c90cd2940b" --assignee-principal-type ServicePrincipal --role "Azure Kubernetes Service RBAC Cluster Admin" --scope "/subscriptions/7043433f-e23e-4206-9930-314695d94a6c/resourceGroups/rg-pub-prod-cus-01/providers/Microsoft.ContainerService/managedClusters/aks-pub-pr-cus-01"
```

## RBAC Role Assignments Writer (observability storage scope)

`rbac-roleassignments-writer.json`
```bash
{
  "Name": "RBAC Role Assignments Writer (observability storage scope)",
  "IsCustom": true,
  "Description": "Observability stack: allows creating RBAC role assignments at the storage account scope (e.g., Grafana/NSG flow logs/cost export destinations). WARNING: Without role-assignment conditions, this can assign any role at that scope.",
  "Actions": [
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/read"
  ],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/ec41aef1-269c-4633-8637-924c395ad181/resourceGroups/rg-pub-pr-cus-core-01/providers/Microsoft.Storage/storageAccounts/saobspubprcuscore"
  ]
}
```

```bash
az role definition create --role-definition ./rbac-roleassignments-writer.json
```

```bash
az role assignment create \
  --assignee-object-id "091b0bfa-694c-4bbf-8ebf-75c90cd2940b" \
  --assignee-principal-type ServicePrincipal \
  --role "RBAC Role Assignments Writer (observability storage scope)" \
  --scope "/subscriptions/ec41aef1-269c-4633-8637-924c395ad181/resourceGroups/rg-pub-pr-cus-core-01/providers/Microsoft.Storage/storageAccounts/saobspubprcuscore"
```

---

## Design Principles

- No unbounded **Owner**
- No unconstrained **UAA**
- Delegation limited via **RBAC conditions**
- CMK creation isolated from CMK usage
- Data-plane and control-plane roles are separated
