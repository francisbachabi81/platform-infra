# Core Stack

This stack manages **plane-level core infrastructure** that sits on top of the shared network, typically shared services used by multiple environments.

It **depends on the shared-network stack**, and it **must** be deployed before any environment-level stack (like `platform-app`).

---

## Scope

- Core/shared services at the **plane** level (nonprod/prod), for both:
  - Azure Government (`hrz`)
  - Azure Commercial (`pub`)
- Consumes and builds upon the networking created by the `shared-network` stack.

This stack deploys **core shared services** for each plane (`nonprod`, `prod`) across:

---

## Mandatory Step — Configure VM Self-Hosted Runner  
**Platform-App and downstream stacks WILL FAIL unless this VM is configured.**

The Core stack deploys a **Linux VM** into the internal hub subnet.  
This VM is required to run self-hosted GitHub Actions responsible for:

- AKS setup & initialization  
- Deployments into private AKS clusters  
- Secure CI/CD inside VNet-isolated environments  
- Running automation that cannot execute on public GitHub-hosted runners  

After running the Core Apply workflow, SSH into the VM and complete the following steps.

---

## 1. Prepare the Runner Directory

```bash
mkdir actions-runner && cd actions-runner

curl -o actions-runner-linux-x64-2.329.0.tar.gz -L   https://github.com/actions/runner/releases/download/v2.329.0/actions-runner-linux-x64-2.329.0.tar.gz

echo "194f1e1e4bd02f80b7e9633fc546084d8d4e19f3928a324d512ea53430102e1d  actions-runner-linux-x64-2.329.0.tar.gz"   | shasum -a 256 -c

tar xzf ./actions-runner-linux-x64-2.329.0.tar.gz
```

---

## 2. Configure the GitHub Actions Runner

```bash
./config.sh --url https://github.com/intterra-io/platform-infra --token BXQIBB4DCVHACGQVLGWKQUDJFXJU2

# Start the runner interactively
./run.sh

# Install as a service (preferred)
sudo ./svc.sh install
sudo ./svc.sh start
```

---

## 3. Install Azure CLI (Required for AKS access)

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg

curl -sL https://packages.microsoft.com/keys/microsoft.asc   | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg

AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main"   | sudo tee /etc/apt/sources.list.d/azure-cli.list

sudo apt-get update
sudo apt-get install -y azure-cli

az version
```

---

## 4. Install kubectl & Helm (Required for AKS Deployments)

```bash
sudo az aks install-cli
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

---

## 5. Required Runner Tags

Workflows reference runner tags like:

```yaml
runs-on:
  - self-hosted
  - nonprod/prod
```

Ensure these tags were added during `./config.sh`.

---

## 6. Next Steps

With the runner installed and online:

1. Proceed to the **Platform-App** workflows
2. These workflows will:
   - Bootstrap AKS
   - Deploy cluster prerequisites
   - Deploy application workloads

Failure to configure the runner will cause **AKS setup to fail**.

---

## Files

```text
backend.tf       # Remote backend configuration
main.tf          # Core Terraform configuration
variables.tf     # Stack inputs
outputs.tf       # Stack outputs
tfvars/
  np.hrz.tfvars
  np.pub.tfvars
  pr.hrz.tfvars
  pr.pub.tfvars
```

---

## Inputs & tfvars

Planes are abbreviated in the tfvars filenames:

| Plane    | Abbrev | Product | tfvars file     |
|----------|--------|---------|-----------------|
| nonprod  | np     | hrz     | `np.hrz.tfvars` |
| nonprod  | np     | pub     | `np.pub.tfvars` |
| prod     | pr     | hrz     | `pr.hrz.tfvars` |
| prod     | pr     | pub     | `pr.pub.tfvars` |

Typical variables:

- `product` → `hrz` or `pub`
- `plane` or equivalent → `np` / `pr` (mapped to nonprod/prod)

> Recommended improvement: consider renaming `np`/`pr` to `nonprod`/`prod` over time for consistency with `shared-network`.

---

## Dependencies

- **Requires** `shared-network` to be deployed for the same plane and product.
- **Provides** shared/core services consumed by environment-specific stacks (`platform-app`, `observability`).

---

## Related Workflows

- Plan: `workflows/core-plan.yml`
- Apply: `workflows/core-apply.yml`

These workflows:

- Accept `product` (`hrz`, `pub`) and `plane` (`np`, `pr`) as inputs
- Run Terraform in `stacks/core/`
- Select the matching `tfvars` file

---

## How to Run (Example)

From GitHub:

1. Trigger **Core Plan**:
   - Workflow: `core-plan.yml`
   - Inputs: `product=hrz`, `plane=np`
2. Review the plan.
3. Trigger **Core Apply**:
   - Workflow: `core-apply.yml`
   - Same inputs.

From CLI (conceptually):

```bash
cd stacks/core

terraform init   -backend-config=...
terraform plan   -var-file=tfvars/np.hrz.tfvars
terraform apply  -var-file=tfvars/np.hrz.tfvars
```
