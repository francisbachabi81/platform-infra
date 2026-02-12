#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# INPUTS
# ---------------------------
PLANE_IN="${PLANE_IN:-nonprod}"  # nonprod|prod|np|pr
PRODUCT_IN="${PRODUCT_IN:-hrz}"  # hrz|pub

# ---------------------------
# REQUIRED LOCAL SECRETS (set these in your shell before running)
# ---------------------------
: "${TENANT_ID:?set TENANT_ID}"
: "${STATE_SUB:?set STATE_SUB}"      # backend state subscription
: "${HUB_SUB:?set HUB_SUB}"          # core/hub subscription for lookups
: "${TARGET_SUB:?set TARGET_SUB}"    # target subscription
: "${CORE_VM_ADMIN_PASSWORD:?set CORE_VM_ADMIN_PASSWORD}"

# ---------------------------
# Validate / normalize PLANE
# ---------------------------
case "$PLANE_IN" in
  nonprod|prod) PLANE="$PLANE_IN" ;;
  np) PLANE="nonprod" ;;
  pr) PLANE="prod" ;;
  *) echo "❌ Unknown plane: $PLANE_IN (expected nonprod|prod|np|pr)"; exit 1 ;;
esac

# ---------------------------
# Resolve tfvars (plane-based)
# ---------------------------
TFVARS_DIR="tfvars"

candidates=(
  "${PLANE_IN}.${PRODUCT_IN}.tfvars"
  "${PLANE_IN}.tfvars"
  "default.${PLANE_IN}.tfvars"
  "default.tfvars"
)

TFVARS_PATH=""
for f in "${candidates[@]}"; do
  if [ -f "${TFVARS_DIR}/${f}" ]; then
    TFVARS_PATH="${TFVARS_DIR}/${f}"
    echo "✅ Using tfvars: ${TFVARS_PATH}"
    break
  fi
done
[ -n "${TFVARS_PATH}" ] || { echo "❌ Missing tfvars. Tried: ${candidates[*]}"; exit 1; }

# ---------------------------
# Backend config
# ---------------------------
STATE_RG="rg-core-tfstate-01"
STATE_SA="sacoretfstateinfra"
STATE_CONTAINER="tfstate"
STATE_KEY="core/${PRODUCT_IN}/${PLANE_IN}/terraform.tfstate"

# ---------------------------
# Export env vars
# ---------------------------
export ARM_USE_CLI=true
export ARM_USE_AZUREAD=true
export ARM_ENVIRONMENT="$([ "$PRODUCT_IN" = "hrz" ] && echo usgovernment || echo public)"
export ARM_TENANT_ID="$TENANT_ID"

export TF_VAR_tenant_id="$TENANT_ID"
export TF_VAR_product="$PRODUCT_IN"
export TF_VAR_plane="$PLANE_IN"
export TF_VAR_subscription_id="$TARGET_SUB"
export TF_VAR_hub_tenant_id="$TENANT_ID"
export TF_VAR_hub_subscription_id="$HUB_SUB"
export TF_VAR_core_vm_admin_password="$CORE_VM_ADMIN_PASSWORD"

# ---------------------------
# Cloud selection
# ---------------------------
echo "☁️ Setting Azure cloud based on product..."
if [ "$PRODUCT_IN" = "hrz" ]; then
  az cloud set --name AzureUSGovernment
else
  az cloud set --name AzureCloud
fi
az cloud show --query name -o tsv

# ---------------------------
# INIT on STATE subscription (backend)
# ---------------------------
echo "🔐 Using STATE_SUB=$STATE_SUB"
az cloud show --query name -o tsv
az account show --query "{tenantId:tenantId, subscriptionId:id, name:name}" -o json
az account set --subscription "$STATE_SUB"

terraform init -input=false -reconfigure \
  -backend-config="environment=${ARM_ENVIRONMENT}" \
  -backend-config="tenant_id=${TENANT_ID}" \
  -backend-config="subscription_id=${STATE_SUB}" \
  -backend-config="resource_group_name=${STATE_RG}" \
  -backend-config="storage_account_name=${STATE_SA}" \
  -backend-config="container_name=${STATE_CONTAINER}" \
  -backend-config="key=${STATE_KEY}" \
  -backend-config="use_azuread_auth=true" \
  -backend-config="use_cli=true"

terraform fmt -recursive
terraform validate

# ---------------------------
# Switch to TARGET subscription + PLAN
# ---------------------------
echo "🎯 az account set (TARGET_SUB=$TARGET_SUB)"
az account set --subscription "$TARGET_SUB"

set +e
terraform plan -input=false -lock-timeout=5m \
  -var-file="${TFVARS_PATH}" \
  -var "product=${PRODUCT_IN}" \
  -var "plane=${PLANE_IN}" \
  -detailed-exitcode -out=tfplan \
  2>&1 | tee plan-raw.txt
ec=${PIPESTATUS[0]}
set -e

echo "Terraform plan exit code: $ec"
if [ "$ec" = "0" ] || [ "$ec" = "2" ]; then
  terraform show -no-color tfplan > plan.txt
  terraform show -json tfplan > plan.json
  COUNT=$(jq '[.resource_changes[] | select((.change.actions | index("no-op")) | not)] | length' plan.json)
  echo "changes_count=${COUNT}"
fi

exit "$ec"
# PUB -----------------------------------------------------------------------------
# export PLANE_IN=np
# export PRODUCT_IN=pub
# export TENANT_ID="dd58f16c-b85a-4d66-99e1-f86905453853"
# export STATE_SUB="ee8a4693-54d4-4de8-842b-b6f35fc0674d"
# export HUB_SUB="ee8a4693-54d4-4de8-842b-b6f35fc0674d"
# export TARGET_SUB="ee8a4693-54d4-4de8-842b-b6f35fc0674d"
# export CORE_VM_ADMIN_PASSWORD='VTB0xuy2cxd8ntr*mep'

# export PLANE_IN=pr
# export PRODUCT_IN=pub
# export TENANT_ID="dd58f16c-b85a-4d66-99e1-f86905453853"
# export STATE_SUB="ee8a4693-54d4-4de8-842b-b6f35fc0674d"
# export HUB_SUB="ec41aef1-269c-4633-8637-924c395ad181"
# export TARGET_SUB="ec41aef1-269c-4633-8637-924c395ad181"
# export CORE_VM_ADMIN_PASSWORD='ufn8tqt_kpq0uta6EHG'
# PUB -----------------------------------------------------------------------------


# HRZ -----------------------------------------------------------------------------
# export PLANE_IN=np
# export PRODUCT_IN=hrz
# export TENANT_ID="ed7990c3-61c2-477d-85e9-1a396c19ae94"
# export STATE_SUB="641d3872-8322-4bdb-83ce-bfbc119fa3cd"
# export HUB_SUB="df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
# export TARGET_SUB="df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
# export CORE_VM_ADMIN_PASSWORD='myu1HBE_xnd2tby4rqu'

# export PLANE_IN=pr
# export PRODUCT_IN=hrz
# export TENANT_ID="ed7990c3-61c2-477d-85e9-1a396c19ae94"
# export STATE_SUB="641d3872-8322-4bdb-83ce-bfbc119fa3cd"
# export HUB_SUB="d072f6c1-7c2d-4d27-8ffb-fd96f828c3b6"
# export TARGET_SUB="d072f6c1-7c2d-4d27-8ffb-fd96f828c3b6"
# export CORE_VM_ADMIN_PASSWORD='quf2cwg1BXB0guv_guj'
# HRZ -----------------------------------------------------------------------------

# env | grep -E '^(PLANE_IN|PRODUCT_IN|TENANT_ID|STATE_SUB|HUB_SUB|TARGET_SUB|CORE_VM_ADMIN_PASSWORD)='

# unset PLANE_IN
# unset PRODUCT_IN
# unset TENANT_ID
# unset STATE_SUB
# unset HUB_SUB
# unset TARGET_SUB
# unset CORE_VM_ADMIN_PASSWORD

# bash ./local-plan-platform-app.sh


# az cloud set -n AzureUSGovernment
# az account set --subscription 641d3872-8322-4bdb-83ce-bfbc119fa3cd

# # 1) recreate the missing RG
# az group create \
#   -n DefaultResourceGroup-USGA \
#   -l usgovarizona

# # 2) recreate the missing Log Analytics workspace (same name)
# az monitor log-analytics workspace create \
#   -g DefaultResourceGroup-USGA \
#   -n DefaultWorkspace-641d3872-8322-4bdb-83ce-bfbc119fa3cd-USGA \
#   -l usgovarizona