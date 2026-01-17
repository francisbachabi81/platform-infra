#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# INPUTS (match workflow_dispatch)
# ---------------------------
ENV_IN="${ENV_IN:-dev}"          # dev|qa|uat|prod
PRODUCT_IN="${PRODUCT_IN:-hrz}"  # hrz|pub

# ---------------------------
# REQUIRED LOCAL SECRETS (set these in your shell before running)
# ---------------------------
: "${TENANT_ID:?set TENANT_ID}"
: "${STATE_SUB:?set STATE_SUB}"      # backend state subscription
: "${HUB_SUB:?set HUB_SUB}"          # core/hub subscription for lookups
: "${TARGET_SUB:?set TARGET_SUB}"    # observability subscription for this env

# ---------------------------
# Derive plane from env (same logic)
# ---------------------------
case "$ENV_IN" in
  dev|qa|np)   PLANE="nonprod" ;;
  uat|prod|pr) PLANE="prod" ;;
  *) echo "Unknown env: $ENV_IN"; exit 1 ;;
esac

# ---------------------------
# Resolve tfvars (same candidates)
# ---------------------------
# STACK_DIR="stacks/observability"
# TFVARS_DIR="${STACK_DIR}/tfvars"
TFVARS_DIR="tfvars"

candidates=(
  "${ENV_IN}.${PRODUCT_IN}.tfvars"
  "${ENV_IN}.tfvars"
  "default.${ENV_IN}.tfvars"
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
# Backend config (same values as workflow)
# ---------------------------
STATE_RG="rg-core-tfstate-01"
STATE_SA="sacoretfstateinfra"
STATE_CONTAINER="tfstate"
STATE_KEY="observability/${PRODUCT_IN}/${ENV_IN}/terraform.tfstate"

# ---------------------------
# Export env vars (same as workflow)
# ---------------------------
export ARM_USE_CLI=true
export ARM_USE_AZUREAD=true
export ARM_ENVIRONMENT="$([ "$PRODUCT_IN" = "hrz" ] && echo usgovernment || echo public)"
export ARM_TENANT_ID="$TENANT_ID"

export TF_VAR_tenant_id="$TENANT_ID"
export TF_VAR_product="$PRODUCT_IN"
export TF_VAR_env="$ENV_IN"
export TF_VAR_plane="$PLANE"
export TF_VAR_subscription_id="$TARGET_SUB"

export TF_VAR_core_tenant_id="$TENANT_ID"
export TF_VAR_core_subscription_id="$HUB_SUB"
export TF_VAR_env_tenant_id="$TENANT_ID"

export TF_VAR_dev_subscription_id="$DEV_SUB"
export TF_VAR_dev_tenant_id="$TENANT_ID"
# export TF_VAR_qa_subscription_id="$QA_SUB"
# export TF_VAR_qa_tenant_id="$TENANT_ID"

# export TF_VAR_prod_subscription_id="$PROD_SUB"
# export TF_VAR_prod_tenant_id="$TENANT_ID"
# export TF_VAR_uat_subscription_id="$UAT_SUB"
# export TF_VAR_uat_tenant_id="$TENANT_ID"

# ---------------------------
# Login + INIT on STATE subscription (backend)
# ---------------------------
echo "🔐 az login (STATE_SUB=$STATE_SUB)"
az cloud set --name AzureUSGovernment
# az account clear 2>/dev/null || true
az cloud show --query name -o tsv
az account show --query "{tenantId:tenantId, subscriptionId:id, name:name}" -o json
az account set --subscription "$STATE_SUB"

# pushd "$STACK_DIR" >/dev/null

terraform init -input=false -reconfigure \
  -backend-config="environment=usgovernment" \
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
  -var "env=${ENV_IN}" \
  -detailed-exitcode -out=tfplan \
  -var "hub_subscription_id=${HUB_SUB}" \
  -var "tenant_id=${TENANT_ID}"
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

# popd >/dev/null

exit "$ec"


# export ENV_IN=dev
# export PRODUCT_IN=hrz
# export TENANT_ID="ed7990c3-61c2-477d-85e9-1a396c19ae94"
# export STATE_SUB="641d3872-8322-4bdb-83ce-bfbc119fa3cd"
# export HUB_SUB="df6dc63f-c4dc-4590-ba4b-f2ce9639ca6c"
# export TARGET_SUB="62ae6908-cbcb-40cb-8773-54bd318ff7f9"
# export DEV_SUB="62ae6908-cbcb-40cb-8773-54bd318ff7f9"
# export QA_SUB="d4c1d472-722c-49c2-857f-4243441104c8"
# export PROD_SUB="641d3872-8322-4bdb-83ce-bfbc119fa3cd"
# export UAT_SUB="4d2bdae0-9da9-4657-827d-d44867ec2f0a"

# env | grep -E '^(ENV_IN|PRODUCT_IN|TENANT_ID|STATE_SUB|HUB_SUB|TARGET_SUB|DEV_SUB|QA_SUB|PROD_SUB|UAT_SUB)='

# unset ENV_IN
# unset PRODUCT_IN
# unset TENANT_ID
# unset STATE_SUB
# unset HUB_SUB
# unset TARGET_SUB
# unset DEV_SUB
# unset QA_SUB
# unset PROD_SUB
# unset UAT_SUB

# bash ./local-plan-observability.sh
