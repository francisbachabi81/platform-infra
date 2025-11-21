# Provision-Secrets Stack

This folder contains **JSON schema definitions** that describe the secrets required for each cloud product and environment. It is not a Terraform stack by itself.

---

## Scope

- Defines schemas for:
  - `hrz` — Azure Government secrets (`hrz.secrets.schema.json`)
  - `pub` — Azure Commercial secrets (`pub.secrets.schema.json`)
- Used by automation (GitHub Actions) to:
  - Validate required secrets
  - Guide provisioning of secrets into Azure Key Vault and/or GitHub secrets

---

## Files

```text
hrz.secrets.schema.json   # Schema for Azure Gov secrets
pub.secrets.schema.json   # Schema for Azure Commercial secrets
```

Each schema describes:

- Which secrets are required
- Naming patterns
- Any validation rules used by the provisioning workflow

---

## Related Workflow

- `workflows/infra-secrets-provision.yml`

This workflow:

- Uses the appropriate schema based on `product` (`hrz` or `pub`)
- Prompts/validates secrets
- Writes them into the appropriate secret stores

---

## Usage (Conceptual)

From GitHub:

1. Trigger **Infra Secrets Provision**:
   - Workflow: `infra-secrets-provision.yml`
   - Inputs: `product=hrz` (and possibly `env`)
2. Follow the workflow’s guidance to provide/update secrets as needed.
3. After secrets are in place, run the infrastructure plan/apply workflows.

---

## Notes

- This folder intentionally does **not** contain Terraform code.
- Changes here affect how secrets are provisioned for all stacks that rely on those secrets.
