#!/bin/bash

set -e

if [ -z "$REGIONS" ]; then
  echo "REGIONS environment variable is not set."
  exit 1
fi

IMAGE_TAG=${1:-latest}
ACR_NAME="olehnest"
APP_NAME_PREFIX="my-nest"
PLAN_SKU="B1"

IFS=',' read -ra REGION_LIST <<< "$REGIONS"

for REGION in "${REGION_LIST[@]}"; do
  RG_NAME="rg-$REGION"
  APP_NAME="${APP_NAME_PREFIX}-${REGION}"
  PLAN_NAME="plan-${REGION}"

  echo "Deploying to region: $REGION"

  if ! az group show --name "$RG_NAME" &>/dev/null; then
    echo "Creating resource group: $RG_NAME"
    az group create --name "$RG_NAME" --location "$REGION"
  else
    echo "Resource group $RG_NAME exists"
  fi

  if ! az appservice plan show --name "$PLAN_NAME" --resource-group "$RG_NAME" &>/dev/null; then
    echo "Creating App Service plan: $PLAN_NAME"
    az appservice plan create \
      --name "$PLAN_NAME" \
      --resource-group "$RG_NAME" \
      --is-linux \
      --location "$REGION" \
      --sku "$PLAN_SKU"
  else
    echo "App Service plan $PLAN_NAME exists"
  fi

  if ! az webapp show --name "$APP_NAME" --resource-group "$RG_NAME" &>/dev/null; then
    echo "Creating web app: $APP_NAME"
    az webapp create \
      --name "$APP_NAME" \
      --resource-group "$RG_NAME" \
      --plan "$PLAN_NAME" \
      --deployment-container-image-name "${ACR_NAME}.azurecr.io/${APP_NAME_PREFIX}-app:${IMAGE_TAG}"
  else
    echo "Web app $APP_NAME exists"
  fi


  echo "Setting settings for container for $APP_NAME"
  VAR_NAME="ENVS_${REGION}"
  echo "${!VAR_NAME}"
  echo "${!VAR_NAME}" > settings.json
  az webapp config appsettings set \
      --resource-group "$RG_NAME" \
      --name "$APP_NAME" \
      --settings @settings.json

  echo "Configuring container for $APP_NAME"
  az webapp config container set \
    --name "$APP_NAME" \
    --resource-group "$RG_NAME" \
    --docker-custom-image-name "${ACR_NAME}.azurecr.io/${APP_NAME_PREFIX}-app:${IMAGE_TAG}" \
    --docker-registry-server-url "https://${ACR_NAME}.azurecr.io"

  echo "Deployed to $REGION"
done
