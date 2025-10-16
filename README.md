# Unified Infrastructure Repository

This repo merges Horizon (hrz) and Public infrastructure into a single codebase.
- Shared code lives under `stacks/` and `modules/`.
- Behavior switches by `var.product` (`hrz` or `public`) and `var.env` (`dev|qa|uat|prod`).
- `locals.product_logic.tf` exposes feature flags like `enable_public_features`.

## Product-specific resources
- Public-only (enabled when `var.product == "public"`): Event Hub, Azure Functions (see `stacks/envs/main.public-features.example.tf`).
- Horizon-only: wire up using `local.enable_hrz_features` in your modules.

## TFVars
Store opinionated tfvars in `tfvars/<product>/<env>.auto.tfvars` if desired.
