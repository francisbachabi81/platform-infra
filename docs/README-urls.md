# Intterra URL Quick Reference

A living README to centralize environment URLs (Dev now; placeholders included for QA/UAT/Prod).

## How to use / update
- Add new links under the correct **Tenant** and **Environment**.
- Keep names consistent (e.g., *Grafana UI*, *Temporal UI*, *Admin UI*).
- Prefer stable paths (e.g., `/health/ready`, `/docs/swagger/`).

---

## Table of Contents
- [PUBLIC](#public)
  - [DEV](#public-dev)
  - [QA](#public-qa)
  - [UAT](#public-uat)
  - [PROD](#public-prod)
- [HRZ (Horizon)](#hrz-horizon)
  - [DEV](#hrz-dev)
  - [QA](#hrz-qa)
  - [UAT](#hrz-uat)
  - [PROD](#hrz-prod)

---

# PUBLIC

## PUBLIC DEV

### AGW / Internal

| Name | URL | Notes |
|---|---|---|
| Public Layers Health (Origin) | https://origin-publiclayers.dev.public.intterra.io/public-layers/health.txt | Public-layers health endpoint |
| Grafana UI | https://internal.dev.public.intterra.io/logs | Observability (Grafana) |

### AFD

| Name | URL | Notes |
|---|---|---|
| Public Layers Health | https://publiclayers.dev.public.intterra.io/public-layers/health.txt | Public-layers health endpoint |
| Health Ready | https://public.dev.public.intterra.io/health/ready | Readiness probe |
| OpenAPI JSON | https://public.dev.public.intterra.io/docs/openapi.json | Swagger/OpenAPI spec endpoint |
| Swagger / Scalar | https://public.dev.public.intterra.io/docs/swagger/ | Swagger UI / Scalar entry |
| API Reference (Scalar) | https://public.dev.public.intterra.io/docs/api-reference/ | API reference |

## PUBLIC QA

> _Add QA URLs here._

### AGW / Internal

| Name | URL | Notes |
|---|---|---|
| Public Layers Health (Origin) |  |  |
| Grafana UI |  |  |
| Temporal UI |  |  |
| Admin UI |  |  |

### AFD

| Name | URL | Notes |
|---|---|---|
| Public Layers Health |  |  |
| Health Ready |  |  |
| OpenAPI JSON |  |  |
| Swagger / Scalar |  |  |
| API Reference (Scalar) |  |  |

## PUBLIC UAT

> _Add UAT URLs here._

### AGW / Internal

| Name | URL | Notes |
|---|---|---|
| Public Layers Health (Origin) |  |  |
| Grafana UI |  |  |
| Temporal UI |  |  |
| Admin UI |  |  |

### AFD

| Name | URL | Notes |
|---|---|---|
| Public Layers Health |  |  |
| Health Ready |  |  |
| OpenAPI JSON |  |  |
| Swagger / Scalar |  |  |
| API Reference (Scalar) |  |  |

## PUBLIC PROD

> _Add Prod URLs here._

### AGW / Internal

| Name | URL | Notes |
|---|---|---|
| ~~Public Layers Health (Origin)~~ | ~~https://origin-publiclayers.public.intterra.io/public-layers/health.txt~~ | ~~Public-layers health endpoint~~ |
| Grafana UI | https://internal.public.intterra.io/logs | Observability (Grafana) |

### AFD

| Name | URL | Notes |
|---|---|---|
| Public Layers Health | https://publiclayers.public.intterra.io/public-layers/health.txt | Public-layers health endpoint |
| Health Ready | https://public.intterra.io/health/ready | Readiness probe |
| OpenAPI JSON | https://public.intterra.io/docs/openapi.json | Swagger/OpenAPI spec endpoint |
| Swagger / Scalar | https://public.intterra.io/docs/swagger/ | Swagger UI / Scalar entry |
| API Reference (Scalar) | https://public.intterra.io/docs/api-reference/ | API reference |

---

# HRZ (Horizon)

## HRZ DEV

### AGW

| Name | URL | Notes |
|---|---|---|
| Public Layers Health (Origin) | https://origin-publiclayers.dev.horizon.intterra.io/public-layers/health.txt | Public-layers health endpoint |
| Grafana UI | https://internal.dev.horizon.intterra.io/logs | Observability (Grafana) |
| Temporal UI | https://internal.dev.horizon.intterra.io/temporal | Workflow UI (Temporal) |
| Admin UI | https://internal.dev.horizon.intterra.io/admin | Admin portal |

### AFD

| Name | URL | Notes |
|---|---|---|
| Agency UI | https://dev.horizon.intterra.io/agency | Agency portal |
| Docs / Swagger | https://dev.horizon.intterra.io/docs/swagger | Swagger UI |
| API Reference (Scalar) | https://dev.horizon.intterra.io/docs/api-reference | API reference |

## HRZ QA

> _Add QA URLs here._

### AGW

| Name | URL | Notes |
|---|---|---|
| Public Layers Health (Origin) |  |  |
| Grafana UI |  |  |
| Temporal UI |  |  |
| Admin UI |  |  |

### AFD

| Name | URL | Notes |
|---|---|---|
| Agency UI |  |  |
| Docs / Swagger |  |  |
| API Reference (Scalar) |  |  |

## HRZ UAT

> _Add UAT URLs here._

### AGW

| Name | URL | Notes |
|---|---|---|
| Public Layers Health (Origin) |  |  |
| Grafana UI |  |  |
| Temporal UI |  |  |
| Admin UI |  |  |

### AFD

| Name | URL | Notes |
|---|---|---|
| Agency UI |  |  |
| Docs / Swagger |  |  |
| API Reference (Scalar) |  |  |

## HRZ PROD

> _Add Prod URLs here._

### AGW

| Name | URL | Notes |
|---|---|---|
| Public Layers Health (Origin) | https://origin-publiclayers.horizon.intterra.io/public-layers/health.txt | Public-layers health endpoint |
| Grafana UI | https://internal.horizon.intterra.io/logs | Observability (Grafana) |
| Temporal UI | https://internal.horizon.intterra.io/temporal | Workflow UI (Temporal) |
| Admin UI | https://internal.horizon.intterra.io/admin | Admin portal |

### AFD

| Name | URL | Notes |
|---|---|---|
| Agency UI | https://horizon.intterra.io/agency | Agency portal |
| Docs / Swagger | https://horizon.intterra.io/docs/swagger | Swagger UI |
| API Reference (Scalar) | https://horizon.intterra.io/docs/api-reference | API reference |

