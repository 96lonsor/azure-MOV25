#!/usr/bin/env bash
# Bygger hela Nordvik-miljön från repot.
#
#   ./scripts/deploy.sh          # prod -> rg-nordvik
#   ./scripts/deploy.sh test     # test -> rg-nordvik-test
#
# Hemligheterna läses från .env.local (ENTRA_CLIENT_SECRET och FLOW_URL) och
# skickas in som parametrar. De sparas aldrig i någon fil i repot.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # annars skriver Git Bash om sökvägar som börjar med /
cd "$(dirname "$0")/.."

MILJO=${1:-prod}
PARAMS="infra/azuredeploy.parameters.${MILJO}.json"
if [ "$MILJO" = prod ]; then RG=rg-nordvik; else RG="rg-nordvik-${MILJO}"; fi
[ -f "$PARAMS" ] || { echo "Hittar inte $PARAMS"; exit 1; }
[ -f .env.local ] && source .env.local
# Testmiljön ska inte skicka anmälningar till produktionens flöde och SharePoint-lista
[ "$MILJO" = prod ] || FLOW_URL=""
TID=$(date +%Y%m%d-%H%M%S)

# Regionen står i parameterfilen, så att en miljö kan flyttas utan att mallen ändras
LOCATION=$(grep -o '"location": { "value": "[^"]*"' "$PARAMS" | sed 's/.*"value": "//; s/"$//')
LOCATION=${LOCATION:-swedencentral}

echo "== Resursgrupp $RG i $LOCATION"
az group create -n "$RG" -l "$LOCATION" -o none

echo "== Steg 1: nätverk, lagring, registry, identitet och Container Apps-miljö"
az deployment group create -g "$RG" -n "nordvik-infra-$TID" \
  --template-file infra/azuredeploy.json --parameters "@$PARAMS" deployPortal=false -o none
REGISTRY=$(az deployment group show -g "$RG" -n "nordvik-infra-$TID" --query properties.outputs.registry.value -o tsv)

# Imagen taggas med commit-id, så det syns exakt vilken version av koden som kör.
TAGG=$(git rev-parse --short HEAD)
# Ändringar som inte är committade ger en egen tagg, så de inte förväxlas med commiten.
[ -z "$(git status --porcelain -- app)" ] || TAGG="${TAGG}-lokal-$(date +%m%d%H%M)"
IMAGE="${REGISTRY}.azurecr.io/nordvik-portal:${TAGG}"

echo "== Bygger $IMAGE i ACR"
if ! az acr repository show -n "$REGISTRY" --image "nordvik-portal:${TAGG}" -o none 2>/dev/null; then
  az acr build -r "$REGISTRY" -t "nordvik-portal:${TAGG}" app --no-logs -o none
fi

echo "== Steg 2: portalen"
az deployment group create -g "$RG" -n "nordvik-portal-$TID" \
  --template-file infra/azuredeploy.json --parameters "@$PARAMS" \
  deployPortal=true containerImage="$IMAGE" \
  entraClientSecret="${ENTRA_CLIENT_SECRET:-}" flowUrl="${FLOW_URL:-}" -o none
URL=$(az deployment group show -g "$RG" -n "nordvik-portal-$TID" --query properties.outputs.portalUrl.value -o tsv)

# Inloggningen behöver portalens adress som redirect-URI i appregistreringen.
CLIENT_ID=$(az deployment group show -g "$RG" -n "nordvik-portal-$TID" \
  --query properties.parameters.entraClientId.value -o tsv)
if [ -n "$CLIENT_ID" ]; then
  CALLBACK="${URL}/.auth/login/aad/callback"
  BEFINTLIGA=$(az ad app show --id "$CLIENT_ID" --query "web.redirectUris" -o tsv | tr -d '\r')
  if ! grep -qx "$CALLBACK" <<< "$BEFINTLIGA"; then
    az ad app update --id "$CLIENT_ID" --web-redirect-uris $BEFINTLIGA "$CALLBACK"
  fi
fi

echo "== Tagg-policyerna gäller nya resurser, så befintliga åtgärdas också"
for TAGGNAMN in foretag avdelning fastighet kostnadsstalle miljo; do
  ASSIGN="pol-nordvik-tagg-${TAGGNAMN}$([ "$MILJO" = prod ] || echo "-$MILJO")"
  az policy remediation create -g "$RG" -n "rem-nordvik-tagg-${TAGGNAMN}-${TID}" \
    --policy-assignment "$ASSIGN" --resource-discovery-mode ReEvaluateCompliance -o none 2>/dev/null || true
done

echo
echo "Klart: $URL"
echo "Hälsokoll: curl $URL/health"
