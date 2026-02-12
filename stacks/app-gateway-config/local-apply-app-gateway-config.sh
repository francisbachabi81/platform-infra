#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# INPUTS
# ---------------------------
PLANE_IN="${PLANE_IN:-nonprod}"        # nonprod|prod|np|pr
PRODUCT_IN="${PRODUCT_IN:-hrz}"        # hrz|pub
TFPLAN_PATH="${TFPLAN_PATH:-tfplan}"   # path to existing plan file

LOCK_TIMEOUT="${LOCK_TIMEOUT:-10m}"
APPLY="${APPLY:-no}"                   # set APPLY=yes to actually apply
AUTO_APPROVE="${AUTO_APPROVE:-no}"     # set AUTO_APPROVE=yes to skip prompt

# ---------------------------
# REQUIRED LOCAL SECRETS
# ---------------------------
: "${TENANT_ID:?set TENANT_ID}"
: "${STATE_SUB:?set STATE_SUB}"        # backend/state subscription
: "${HUB_SUB:?set HUB_SUB}"            # core/hub subscription for lookups
: "${TARGET_SUB:?set TARGET_SUB}"      # target subscription for apply

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
# Backend config (plane-based)
# ---------------------------
STATE_RG="rg-core-tfstate-01"
STATE_SA="sacoretfstateinfra"
STATE_CONTAINER="tfstate"
STATE_KEY="app-gateway-config/${PRODUCT_IN}/${PLANE}/terraform.tfstate"

# ---------------------------
# Export env vars (same as workflow)
# ---------------------------
export ARM_USE_CLI=true
export ARM_USE_AZUREAD=true
export ARM_ENVIRONMENT="$([ "$PRODUCT_IN" = "hrz" ] && echo usgovernment || echo public)"
export ARM_TENANT_ID="$TENANT_ID"

export TF_VAR_tenant_id="$TENANT_ID"
export TF_VAR_product="$PRODUCT_IN"
export TF_VAR_plane="$PLANE"
export TF_VAR_subscription_id="$TARGET_SUB"
export TF_VAR_hub_tenant_id="$TENANT_ID"
export TF_VAR_hub_subscription_id="$HUB_SUB"

# ---------------------------
# Preflight: ensure tfplan exists
# ---------------------------
if [ ! -f "$TFPLAN_PATH" ]; then
  echo "❌ tfplan not found at: $TFPLAN_PATH"
  echo "   Set TFPLAN_PATH=/path/to/tfplan or run your plan script first."
  exit 1
fi

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
echo "🔐 Backend init on STATE_SUB=$STATE_SUB"
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

# ---------------------------
# Switch to TARGET subscription + APPLY existing plan
# ---------------------------
echo "🎯 Applying on TARGET_SUB=$TARGET_SUB"
az account set --subscription "$TARGET_SUB"

echo
echo "🚨 About to APPLY existing plan:"
echo " - product:      $PRODUCT_IN"
echo " - plane:        $PLANE"
echo " - state key:    $STATE_KEY"
echo " - tfplan:       $TFPLAN_PATH"
echo " - lock timeout: $LOCK_TIMEOUT"
echo

# if [ "$APPLY" != "yes" ]; then
#   echo "Dry-run mode: set APPLY=yes to actually apply."
#   exit 0
# fi

# if [ "$AUTO_APPROVE" = "yes" ]; then
#   terraform apply -input=false -lock-timeout="$LOCK_TIMEOUT" -auto-approve "$TFPLAN_PATH"
# else
#   terraform apply -input=false -lock-timeout="$LOCK_TIMEOUT" "$TFPLAN_PATH"
# fi

terraform apply -input=false tfplan

echo "✅ Apply complete."