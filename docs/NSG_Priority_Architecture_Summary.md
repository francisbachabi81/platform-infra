# NSG Priority & Segmentation Strategy
# TEST

## Overview

This document summarizes the NSG restructuring and priority strategy
implemented across:

-   Baseline (shared boundary & plane isolation)
-   AKS (Ingress, Intra-cluster, Egress, PrivateLink, PGFlex)
-   App Gateway PrivateLink (AFD backend integration)
-   Private Endpoint subnet isolation

The primary goal was to:

-   Eliminate priority conflicts
-   Clearly segment functional rule groups
-   Preserve evaluation order
-   Improve long-term maintainability
-   Reduce accidental overrides

------------------------------------------------------------------------

# Global Priority Band Strategy

We separated rule families into **dedicated, non-overlapping bands** to
prevent conflicts and accidental precedence overrides.

  -----------------------------------------------------------------------
  Rule Category              Priority Range             Purpose
  -------------------------- -------------------------- -----------------
  Baseline Boundary Controls 800--899                   Shared isolation
                                                        & subnet boundary
                                                        rules

  Baseline Plane Hard Deny   4000--4099                 Strict
                                                        cross-plane
                                                        isolation

  AKS Dedicated Band         900--999                   All AKS-related
                                                        traffic rules

  AppGW PrivateLink Band     1200--1299                 Azure Front Door
                                                        → AppGW PL
                                                        enforcement
  -----------------------------------------------------------------------

------------------------------------------------------------------------

# 1️⃣ Baseline (Shared Controls)

## Boundary Controls (800--899)

Used for: - Private Endpoint lane isolation - Allow lane peers - Deny
non-lane VNets - Internet deny (for PE subnets)

Example structure:

-   800 -- Allow lane peers
-   810 -- Deny non-lane VNets (Inbound)
-   820 -- Deny non-lane VNets (Outbound)
-   830 -- Deny Internet outbound (PE only)

These are shared across hub/dev/qa/prod/uat.

------------------------------------------------------------------------

## Plane Isolation (4000--4099)

Used for strict cross-plane separation:

### Nonprod

-   DEV ↔ QA isolation

### Prod

-   PROD ↔ UAT isolation

Priority pattern:

-   4000 -- Outbound deny (A → B)
-   4010 -- Inbound deny (mirror)

This range is intentionally high to act as a **hard security boundary**.

------------------------------------------------------------------------

# 2️⃣ AKS Priority Band (900--999)

All AKS rules moved into a dedicated band to eliminate overlap with
baseline.

## Ingress

  Rule                  Priority
  --------------------- ----------
  HTTPS from Internet   900

------------------------------------------------------------------------

## Intra-Cluster (Preserved Order)

  Rule             Priority
  ---------------- ----------
  Node ↔ Node      910
  Pod ↔ Pod        911
  Node ↔ Pod       912
  Node ↔ Service   913
  Pod ↔ Service    914
  DNS UDP          915

Order preserved exactly as original design.

------------------------------------------------------------------------

## AKS Edge Egress

  Rule               Priority
  ------------------ ----------
  HTTPS → Internet   940
  HTTP → Internet    941
  ACR                942
  ServiceBus         943
  SMTP 465           944

------------------------------------------------------------------------

## AKS → PrivateLink / PGFlex

### Hub → Env

  Target                   Priority
  ------------------------ ----------
  PrivateLink (dev/prod)   950
  PrivateLink (qa/uat)     951
  PGFlex (dev/prod)        960
  PGFlex (qa/uat)          961

------------------------------------------------------------------------

### Same-Plane (dev/dev, qa/qa, etc.)

  Rule          Priority
  ------------- -----------
  PrivateLink   952 / 953
  PGFlex 5432   962 / 963

Preserved original relative ordering (352/353/362/363 equivalents).

------------------------------------------------------------------------

# 3️⃣ App Gateway PrivateLink Band (1200--1299)

Dedicated band created to avoid baseline conflicts.

Purpose: - Lock down AppGW PrivateLink subnet - Allow only Azure Front
Door backend traffic - Restrict everything else

## Rule Order

  Rule                            Priority
  ------------------------------- ----------
  Allow AFD Backend HTTPS         1200
  Allow AFD Backend HTTP          1201
  Allow AzureLoadBalancer         1210
  Allow VNet → VNet (temporary)   1220
  Deny Other HTTPS                1290
  Deny Other HTTP                 1291

Optional hardening recommendation: - Replace VNet→VNet allow with
targeted CIDRs - Add Deny-All-Inbound at 1299

------------------------------------------------------------------------

# 4️⃣ Private Endpoint Subnet Isolation

Applied per lane (hub/dev/qa/prod/uat):

-   Allow lane peers (800)
-   Deny non-lane VNets (810 inbound / 820 outbound)
-   Deny Internet outbound (830)

This ensures PE subnets cannot initiate arbitrary traffic.

------------------------------------------------------------------------

# Key Design Principles

-   Every rule family has a dedicated band.
-   Order within each band preserves original logic.
-   Hard-deny plane isolation is isolated at 4000+.
-   AppGW PrivateLink isolated from baseline.
-   AKS rules fully separated from baseline egress.
-   No overlapping priorities across major rule groups.

------------------------------------------------------------------------
End of Document.
