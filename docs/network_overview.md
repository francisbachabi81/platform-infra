# Network Overview — Hub & Environment Subnets

This document summarizes the **hub** and **environment (spoke)** VNets and subnets for:

- **Plane:** `nonprod` (dev/qa) and `prod` (uat/prod)  
- **Products:**  
  - **`hrz`** – Azure Government (USGov Arizona)  
  - **`pub`** – Azure Commercial (Central US)

Only **hub** and **env VNets/subnets** are covered here (no DNS zones, tags, or gateway configuration details).

---

## 1. Nonprod Plane — `hrz` (Azure Gov, usgovarizona / usaz)

### 1.1 Hub VNet (nonprod_hub)

- **Resource Group:** `rg-hrz-np-usaz-net-01`  
- **VNet Name:** `vnet-hrz-np-hub-usaz-01`  
- **Address Space:** `10.10.0.0/16`

| Subnet Name                    | Address Prefixes    | Notes (role/pattern)                                  |
|--------------------------------|---------------------|-------------------------------------------------------|
| `GatewaySubnet`                | `10.10.0.0/24`      | VPN gateway                                           |
| `AzureFirewallSubnet`          | `10.10.1.0/26`      | Azure Firewall data plane                             |
| `AzureFirewallManagementSubnet`| `10.10.1.64/26`     | Azure Firewall management                             |
| `RouteServerSubnet`            | `10.10.1.128/27`    | Route Server                                          |
| `AzureBastionSubnet`           | `10.10.3.0/26`      | Azure Bastion                                         |
| `akshrz`                       | `10.10.2.0/24`      | AKS nodepool / control plane integration              |
| `internal`                     | `10.10.13.0/24`     | General internal workloads                            |
| `external`                     | `10.10.14.0/24`     | External-facing workloads / egress                    |
| `shared-svc`                   | `10.10.20.0/24`     | Shared services (plane-level)                         |
| `appgw`                        | `10.10.40.0/27`     | Application Gateway                                   |
| `dns-inbound`                  | `10.10.50.0/27`     | Private DNS Resolver inbound                          |
| `dns-outbound`                 | `10.10.50.32/27`    | Private DNS Resolver outbound                         |
| `identity`                     | `10.10.60.0/26`     | Managed identities / infra                              |
| `monitor`                      | `10.10.61.0/26`     | Monitoring-related services                           |
| `privatelink-hub`              | `10.10.30.0/27`     | Hub Private Endpoints (PEs); network policies disabled |

---

### 1.2 Dev Spoke VNet (dev_spoke)

- **Resource Group:** `rg-hrz-dev-usaz-net-01`  
- **VNet Name:** `vnet-hrz-dev-usaz-01`  
- **Address Space:** `10.11.0.0/16`

| Subnet Name               | Address Prefixes     | Notes (role/pattern)                                 |
|---------------------------|----------------------|------------------------------------------------------|
| `appsvc-int-linux-01`     | `10.11.11.0/27`      | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-linux-02`     | `10.11.11.32/27`     | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-linux-03`     | `10.11.11.64/27`     | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-linux-04`     | `10.11.11.96/27`     | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-windows-01`   | `10.11.12.0/27`      | Internal Windows App Service Plan (delegated)        |
| `appsvc-int-windows-02`   | `10.11.12.32/27`     | Internal Windows App Service Plan (delegated)        |
| `appsvc-int-windows-03`   | `10.11.12.64/27`     | Internal Windows App Service Plan (delegated)        |
| `appsvc-int-windows-04`   | `10.11.12.96/27`     | Internal Windows App Service Plan (delegated)        |
| `internal`                | `10.11.13.0/24`      | Internal app tiers / services                        |
| `external`                | `10.11.14.0/24`      | External-facing workloads / egress                   |
| `akshrz`                  | `10.11.2.0/24`       | AKS nodes / pods (env-level)                         |
| `pgflex`                  | `10.11.3.0/24`       | PostgreSQL Flexible Server (delegated)               |
| `privatelink`             | `10.11.30.0/24`      | Private Endpoints (PEs)                              |
| `privatelink-cdbpg`       | `10.11.31.0/27`      | Cosmos DB for PostgreSQL PEs                         |

---

### 1.3 QA Spoke VNet (qa_spoke)

- **Resource Group:** `rg-hrz-qa-usaz-net-01`  
- **VNet Name:** `vnet-hrz-qa-usaz-01`  
- **Address Space:** `10.12.0.0/16`

| Subnet Name               | Address Prefixes     | Notes (role/pattern)                                 |
|---------------------------|----------------------|------------------------------------------------------|
| `appsvc-int-linux-01`     | `10.12.11.0/27`      | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-linux-02`     | `10.12.11.32/27`     | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-linux-03`     | `10.12.11.64/27`     | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-linux-04`     | `10.12.11.96/27`     | Internal Linux App Service Plan (delegated)          |
| `appsvc-int-windows-01`   | `10.12.12.0/27`      | Internal Windows App Service Plan (delegated)        |
| `appsvc-int-windows-02`   | `10.12.12.32/27`     | Internal Windows App Service Plan (delegated)        |
| `appsvc-int-windows-03`   | `10.12.12.64/27`     | Internal Windows App Service Plan (delegated)        |
| `appsvc-int-windows-04`   | `10.12.12.96/27`     | Internal Windows App Service Plan (delegated)        |
| `internal`                | `10.12.13.0/24`      | Internal app tiers / services                        |
| `external`                | `10.12.14.0/24`      | External-facing workloads / egress                   |
| `akshrz`                  | `10.12.2.0/24`       | AKS nodes / pods (env-level)                         |
| `pgflex`                  | `10.12.3.0/24`       | PostgreSQL Flexible Server (delegated)               |
| `privatelink`             | `10.12.30.0/24`      | Private Endpoints (PEs)                              |
| `privatelink-cdbpg`       | `10.12.31.0/27`      | Cosmos DB for PostgreSQL PEs                         |

---

## 2. Nonprod Plane — `pub` (Azure Commercial, centralus / cus)

### 2.1 Hub VNet (nonprod_hub)

- **Resource Group:** `rg-pub-np-cus-net-01`  
- **VNet Name:** `vnet-pub-np-hub-cus-01`  
- **Address Space:** `172.10.0.0/16`

| Subnet Name                    | Address Prefixes     | Notes (role/pattern)                                  |
|--------------------------------|----------------------|-------------------------------------------------------|
| `GatewaySubnet`                | `172.10.0.0/24`      | VPN gateway                                            |
| `AzureFirewallSubnet`          | `172.10.1.0/26`      | Azure Firewall data plane                              |
| `AzureFirewallManagementSubnet`| `172.10.1.64/26`     | Azure Firewall management                              |
| `RouteServerSubnet`            | `172.10.1.128/27`    | Route Server                                           |
| `AzureBastionSubnet`           | `172.10.3.0/26`      | Azure Bastion                                          |
| `akspub`                       | `172.10.2.0/24`      | AKS nodepool / control plane integration               |
| `internal`                     | `172.10.13.0/24`     | General internal workloads                             |
| `external`                     | `172.10.14.0/24`     | External-facing workloads / egress                     |
| `shared-svc`                   | `172.10.20.0/24`     | Shared services (plane-level)                          |
| `appgw`                        | `172.10.40.0/27`     | Application Gateway                                    |
| `dns-inbound`                  | `172.10.50.0/27`     | Private DNS Resolver inbound                           |
| `dns-outbound`                 | `172.10.50.32/27`    | Private DNS Resolver outbound                          |
| `identity`                     | `172.10.60.0/26`     | Managed identities / infra                               |
| `monitor`                      | `172.10.61.0/26`     | Monitoring-related services                            |
| `privatelink-hub`              | `172.10.30.0/27`     | Hub Private Endpoints (PEs); network policies disabled |

---

### 2.2 Dev Spoke VNet (dev_spoke)

- **Resource Group:** `rg-pub-dev-cus-net-01`  
- **VNet Name:** `vnet-pub-dev-cus-01`  
- **Address Space:** `172.11.0.0/16`

| Subnet Name               | Address Prefixes      | Notes (role/pattern)                                  |
|---------------------------|-----------------------|-------------------------------------------------------|
| `appsvc-int-linux-01`     | `172.11.11.0/27`      | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-02`     | `172.11.11.32/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-03`     | `172.11.11.64/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-04`     | `172.11.11.96/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-windows-01`   | `172.11.12.0/27`      | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-02`   | `172.11.12.32/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-03`   | `172.11.12.64/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-04`   | `172.11.12.96/27`     | Internal Windows App Service Plan (delegated)         |
| `internal`                | `172.11.13.0/24`      | Internal app tiers / services                         |
| `external`                | `172.11.14.0/24`      | External-facing workloads / egress                    |
| `akspub`                  | `172.11.2.0/24`       | AKS nodes / pods (env-level)                          |
| `pgflex`                  | `172.11.3.0/24`       | PostgreSQL Flexible Server (delegated)                |
| `privatelink`             | `172.11.30.0/24`      | Private Endpoints (PEs)                               |
| `privatelink-cdbpg`       | `172.11.31.0/27`      | Cosmos DB for PostgreSQL PEs                          |

---

### 2.3 QA Spoke VNet (qa_spoke)

- **Resource Group:** `rg-pub-qa-cus-net-01`  
- **VNet Name:** `vnet-pub-qa-cus-01`  
- **Address Space:** `172.12.0.0/16`

| Subnet Name               | Address Prefixes      | Notes (role/pattern)                                  |
|---------------------------|-----------------------|-------------------------------------------------------|
| `appsvc-int-linux-01`     | `172.12.11.0/27`      | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-02`     | `172.12.11.32/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-03`     | `172.12.11.64/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-04`     | `172.12.11.96/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-windows-01`   | `172.12.12.0/27`      | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-02`   | `172.12.12.32/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-03`   | `172.12.12.64/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-04`   | `172.12.12.96/27`     | Internal Windows App Service Plan (delegated)         |
| `internal`                | `172.12.13.0/24`      | Internal app tiers / services                         |
| `external`                | `172.12.14.0/24`      | External-facing workloads / egress                    |
| `akspub`                  | `172.12.2.0/24`       | AKS nodes / pods (env-level)                          |
| `pgflex`                  | `172.12.3.0/24`       | PostgreSQL Flexible Server (delegated)                |
| `privatelink`             | `172.12.30.0/24`      | Private Endpoints (PEs)                               |
| `privatelink-cdbpg`       | `172.12.31.0/27`      | Cosmos DB for PostgreSQL PEs                          |

---

## 3. Prod Plane — `hrz` (Azure Gov, usgovarizona / usaz)

### 3.1 Hub VNet (prod_hub)

- **Resource Group:** `rg-hrz-pr-usaz-net-01`  
- **VNet Name:** `vnet-hrz-pr-hub-usaz-01`  
- **Address Space:** `10.13.0.0/16`

| Subnet Name                    | Address Prefixes    | Notes (role/pattern)                                  |
|--------------------------------|---------------------|-------------------------------------------------------|
| `GatewaySubnet`                | `10.13.0.0/24`      | VPN gateway                                           |
| `AzureFirewallSubnet`          | `10.13.1.0/26`      | Azure Firewall data plane                             |
| `AzureFirewallManagementSubnet`| `10.13.1.64/26`     | Azure Firewall management                             |
| `RouteServerSubnet`            | `10.13.1.128/27`    | Route Server                                          |
| `AzureBastionSubnet`           | `10.13.3.0/26`      | Azure Bastion                                         |
| `akshrz`                       | `10.13.2.0/24`      | AKS nodepool / control plane integration              |
| `internal`                     | `10.13.13.0/24`     | General internal workloads                            |
| `external`                     | `10.13.14.0/24`     | External-facing workloads / egress                    |
| `shared-svc`                   | `10.13.20.0/24`     | Shared services (plane-level)                         |
| `appgw`                        | `10.13.40.0/27`     | Application Gateway                                   |
| `dns-inbound`                  | `10.13.50.0/27`     | Private DNS Resolver inbound                          |
| `dns-outbound`                 | `10.13.50.32/27`    | Private DNS Resolver outbound                         |
| `identity`                     | `10.13.60.0/26`     | Managed identities / infra                               |
| `monitor`                      | `10.13.61.0/26`     | Monitoring-related services                           |
| `privatelink-hub`              | `10.13.30.0/27`     | Hub Private Endpoints (PEs); network policies disabled |

---

### 3.2 Prod Spoke VNet (prod_spoke)

- **Resource Group:** `rg-hrz-prod-usaz-01`  
- **VNet Name:** `vnet-hrz-prod-usaz-01`  
- **Address Space:** `10.14.0.0/16`

| Subnet Name               | Address Prefixes     | Notes (role/pattern)                                  |
|---------------------------|----------------------|-------------------------------------------------------|
| `appsvc-int-linux-01`     | `10.14.11.0/27`      | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-02`     | `10.14.11.32/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-03`     | `10.14.11.64/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-04`     | `10.14.11.96/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-windows-01`   | `10.14.12.0/27`      | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-02`   | `10.14.12.32/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-03`   | `10.14.12.64/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-04`   | `10.14.12.96/27`     | Internal Windows App Service Plan (delegated)         |
| `internal`                | `10.14.13.0/24`      | Internal app tiers / services                         |
| `external`                | `10.14.14.0/24`      | External-facing workloads / egress                    |
| `akshrz`                  | `10.14.2.0/24`       | AKS nodes / pods (env-level)                          |
| `pgflex`                  | `10.14.3.0/24`       | PostgreSQL Flexible Server (delegated)                |
| `privatelink`             | `10.14.30.0/24`      | Private Endpoints (PEs)                               |
| `privatelink-cdbpg`       | `10.14.31.0/27`      | Cosmos DB for PostgreSQL PEs                          |

---

### 3.3 UAT Spoke VNet (uat_spoke)

- **Resource Group:** `rg-hrz-uat-usaz-01`  
- **VNet Name:** `vnet-hrz-uat-usaz-01`  
- **Address Space:** `10.15.0.0/16`

| Subnet Name               | Address Prefixes     | Notes (role/pattern)                                  |
|---------------------------|----------------------|-------------------------------------------------------|
| `appsvc-int-linux-01`     | `10.15.11.0/27`      | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-02`     | `10.15.11.32/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-03`     | `10.15.11.64/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-04`     | `10.15.11.96/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-windows-01`   | `10.15.12.0/27`      | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-02`   | `10.15.12.32/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-03`   | `10.15.12.64/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-04`   | `10.15.12.96/27`     | Internal Windows App Service Plan (delegated)         |
| `internal`                | `10.15.13.0/24`      | Internal app tiers / services                         |
| `external`                | `10.15.14.0/24`      | External-facing workloads / egress                    |
| `akshrz`                  | `10.15.2.0/24`       | AKS nodes / pods (env-level)                          |
| `pgflex`                  | `10.15.3.0/24`       | PostgreSQL Flexible Server (delegated)                |
| `privatelink`             | `10.15.30.0/24`      | Private Endpoints (PEs)                               |
| `privatelink-cdbpg`       | `10.15.31.0/27`      | Cosmos DB for PostgreSQL PEs                          |

---

## 4. Prod Plane — `pub` (Azure Commercial, centralus / cus)

### 4.1 Hub VNet (prod_hub)

- **Resource Group:** `rg-pub-pr-cus-net-01`  
- **VNet Name:** `vnet-pub-pr-hub-cus-01`  
- **Address Space:** `172.13.0.0/16`

| Subnet Name                    | Address Prefixes     | Notes (role/pattern)                                  |
|--------------------------------|----------------------|-------------------------------------------------------|
| `GatewaySubnet`                | `172.13.0.0/24`      | VPN gateway                                           |
| `AzureFirewallSubnet`          | `172.13.1.0/26`      | Azure Firewall data plane                             |
| `AzureFirewallManagementSubnet`| `172.13.1.64/26`     | Azure Firewall management                             |
| `RouteServerSubnet`            | `172.13.1.128/27`    | Route Server                                          |
| `AzureBastionSubnet`           | `172.13.3.0/26`      | Azure Bastion                                         |
| `akspub`                       | `172.13.2.0/24`      | AKS nodepool / control plane integration              |
| `internal`                     | `172.13.13.0/24`     | General internal workloads                            |
| `external`                     | `172.13.14.0/24`     | External-facing workloads / egress                    |
| `shared-svc`                   | `172.13.20.0/24`     | Shared services (plane-level)                         |
| `appgw`                        | `172.13.40.0/27`     | Application Gateway                                   |
| `dns-inbound`                  | `172.13.50.0/27`     | Private DNS Resolver inbound                          |
| `dns-outbound`                 | `172.13.50.32/27`    | Private DNS Resolver outbound                         |
| `identity`                     | `172.13.60.0/26`     | Managed identities / infra                               |
| `monitor`                      | `172.13.61.0/26`     | Monitoring-related services                           |
| `privatelink-hub`              | `172.13.30.0/27`     | Hub Private Endpoints (PEs); network policies disabled |

---

### 4.2 Prod Spoke VNet (prod_spoke)

- **Resource Group:** `rg-pub-prod-cus-01`  
- **VNet Name:** `vnet-pub-prod-cus-01`  
- **Address Space:** `172.14.0.0/16`

| Subnet Name               | Address Prefixes      | Notes (role/pattern)                                  |
|---------------------------|-----------------------|-------------------------------------------------------|
| `appsvc-int-linux-01`     | `172.14.11.0/27`      | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-02`     | `172.14.11.32/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-03`     | `172.14.11.64/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-04`     | `172.14.11.96/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-windows-01`   | `172.14.12.0/27`      | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-02`   | `172.14.12.32/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-03`   | `172.14.12.64/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-04`   | `172.14.12.96/27`     | Internal Windows App Service Plan (delegated)         |
| `internal`                | `172.14.13.0/24`      | Internal app tiers / services                         |
| `external`                | `172.14.14.0/24`      | External-facing workloads / egress                    |
| `akspub`                  | `172.14.2.0/24`       | AKS nodes / pods (env-level)                          |
| `pgflex`                  | `172.14.3.0/24`       | PostgreSQL Flexible Server (delegated)                |
| `privatelink`             | `172.14.30.0/24`      | Private Endpoints (PEs)                               |
| `privatelink-cdbpg`       | `172.14.31.0/27`      | Cosmos DB for PostgreSQL PEs                          |

---

### 4.3 UAT Spoke VNet (uat_spoke)

- **Resource Group:** `rg-pub-uat-cus-01`  
- **VNet Name:** `vnet-pub-uat-cus-01`  
- **Address Space:** `172.15.0.0/16`

| Subnet Name               | Address Prefixes      | Notes (role/pattern)                                  |
|---------------------------|-----------------------|-------------------------------------------------------|
| `appsvc-int-linux-01`     | `172.15.11.0/27`      | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-02`     | `172.15.11.32/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-03`     | `172.15.11.64/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-linux-04`     | `172.15.11.96/27`     | Internal Linux App Service Plan (delegated)           |
| `appsvc-int-windows-01`   | `172.15.12.0/27`      | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-02`   | `172.15.12.32/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-03`   | `172.15.12.64/27`     | Internal Windows App Service Plan (delegated)         |
| `appsvc-int-windows-04`   | `172.15.12.96/27`     | Internal Windows App Service Plan (delegated)         |
| `internal`                | `172.15.13.0/24`      | Internal app tiers / services                         |
| `external`                | `172.15.14.0/24`      | External-facing workloads / egress                    |
| `akspub`                  | `172.15.2.0/24`       | AKS nodes / pods (env-level)                          |
| `pgflex`                  | `172.15.3.0/24`       | PostgreSQL Flexible Server (delegated)                |
| `privatelink`             | `172.15.30.0/24`      | Private Endpoints (PEs)                               |
| `privatelink-cdbpg`       | `172.15.31.0/27`      | Cosmos DB for PostgreSQL PEs                          |

---

## 5. How to Use This Document

- Use this as a **quick reference** when:
  - Adding new subnets or adjusting CIDR blocks.
  - Troubleshooting connectivity (hub ↔ spoke, AKS, App Service, DB).
  - Validating that new infrastructure fits within the existing IP plan.
