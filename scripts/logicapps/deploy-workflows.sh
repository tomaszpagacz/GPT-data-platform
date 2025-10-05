#!/usr/bin/env bash
set -euo pipefail
APP_NAME="${1:?logic app standard app name}"
RG="$(az resource list --name "$APP_NAME" --resource-type Microsoft.Web/sites --query "[0].resourceGroup" -o tsv)"
ZIP="src/logic-apps/.dist.zip"
rm -f "$ZIP"
( cd src/logic-apps && zip -r ".dist.zip" "workflows" )
az webapp deploy --resource-group "$RG" --name "$APP_NAME" --src-path "$ZIP" --type zip
echo "Deployed workflows from src/logic-apps to $APP_NAME"