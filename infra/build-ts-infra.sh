#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
[[ -f "$SCRIPT_DIR/env.sh" ]] && source "$SCRIPT_DIR/env.sh" || true

if ! az account show --output none 2>/dev/null; then
  echo "Error: not logged in to Azure CLI. Run 'az login' first."
  exit 1
fi

echo "=== tidal-sonics infrastructure provisioning ==="
echo "  Resource group : $RG"
echo "  Location       : $LOCATION"
echo "  ACR            : $ACR_NAME"
echo ""

# [1/7] Resource group
echo "[1/7] Resource group..."
az group create -n $RG -l $LOCATION --output none

# [2/7] ACR
echo "[2/7] Container registry..."
if az acr show -g $RG -n $ACR_NAME --output none 2>/dev/null; then
  echo "  already exists, skipping."
else
  az acr create -g $RG -n $ACR_NAME --sku Basic --admin-enabled false --output none
fi
ACR_ID=$(az acr show -g $RG -n $ACR_NAME --query id -o tsv)
ACR_LOGIN_SERVER=$(az acr show -g $RG -n $ACR_NAME --query loginServer -o tsv)

# [3/7] Managed identity
echo "[3/7] User-assigned managed identity..."
if az identity show -g $RG -n $UAMI_NAME --output none 2>/dev/null; then
  echo "  already exists, skipping."
else
  az identity create -g $RG -n $UAMI_NAME --output none
fi
UAMI_ID=$(az identity show -g $RG -n $UAMI_NAME --query id -o tsv)
UAMI_PRINCIPAL_ID=$(az identity show -g $RG -n $UAMI_NAME --query principalId -o tsv)

# [4/7] AcrPull role assignment
echo "[4/7] AcrPull role assignment..."
EXISTING=$(az role assignment list \
  --assignee $UAMI_PRINCIPAL_ID \
  --scope $ACR_ID \
  --query "[?roleDefinitionName=='AcrPull']" \
  -o tsv 2>/dev/null)
if [ -n "$EXISTING" ]; then
  echo "  already assigned, skipping."
else
  az role assignment create \
    --assignee-object-id $UAMI_PRINCIPAL_ID \
    --assignee-principal-type ServicePrincipal \
    --role AcrPull \
    --scope $ACR_ID \
    --output none
fi

# [5/7] Build and push image
echo "[5/7] Building and pushing image ($IMAGE_TAG)..."
if az acr repository show-tags -n $ACR_NAME --repository tidal-sonics-server -o tsv 2>/dev/null | grep -q "^${IMAGE_TAG}$"; then
  echo "  tag $IMAGE_TAG already exists, skipping."
else
  az acr build \
    -r $ACR_NAME \
    -t tidal-sonics-server:$IMAGE_TAG \
    -f "$REPO_ROOT/src/TidalSonics.Server/Dockerfile" \
    "$REPO_ROOT"
fi

# [6/7] Container Apps environment
echo "[6/7] Container Apps environment..."
if az containerapp env show -g $RG -n $ENV_NAME --output none 2>/dev/null; then
  echo "  already exists, skipping."
else
  az containerapp env create -g $RG -n $ENV_NAME -l $LOCATION --output none
fi

# [7/7] Container App
echo "[7/7] Container App..."
if az containerapp show -g $RG -n $APP_NAME --output none 2>/dev/null; then
  echo "  already exists, skipping."
else
  az containerapp create \
    -g $RG \
    -n $APP_NAME \
    --environment $ENV_NAME \
    --image $ACR_LOGIN_SERVER/tidal-sonics-server:$IMAGE_TAG \
    --registry-server $ACR_LOGIN_SERVER \
    --registry-identity $UAMI_ID \
    --user-assigned $UAMI_ID \
    --ingress external \
    --target-port 8080 \
    --transport auto \
    --min-replicas 0 \
    --max-replicas 1 \
    --cpu 0.25 \
    --memory 0.5Gi \
    --output none
fi
APP_FQDN=$(az containerapp show -g $RG -n $APP_NAME --query properties.configuration.ingress.fqdn -o tsv)

# Write all vars back to env.sh
cat > "$SCRIPT_DIR/env.sh" <<EOF
export LOCATION=$LOCATION
export RG=$RG
export ACR_NAME=$ACR_NAME
export ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
export UAMI_NAME=$UAMI_NAME
export ENV_NAME=$ENV_NAME
export APP_NAME=$APP_NAME
export IMAGE_TAG=$IMAGE_TAG
export UAMI_ID=$UAMI_ID
export UAMI_PRINCIPAL_ID=$UAMI_PRINCIPAL_ID
export ACR_ID=$ACR_ID
export APP_FQDN=$APP_FQDN
EOF

echo ""
echo "=== Done. All vars written to infra/env.sh ==="
echo "  ACR_LOGIN_SERVER  : $ACR_LOGIN_SERVER"
echo "  UAMI_ID           : $UAMI_ID"
echo "  UAMI_PRINCIPAL_ID : $UAMI_PRINCIPAL_ID"
echo "  ACR_ID            : $ACR_ID"
echo "  APP_FQDN          : $APP_FQDN"
echo ""
echo "To load all vars into your shell:"
echo "  source infra/env.sh"
