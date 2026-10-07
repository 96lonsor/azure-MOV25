#!/usr/bin/env bash
# Skapar det i Entra ID som ARM inte kan skapa: grupperna för Nordviks roller,
# appregistreringen som portalens inloggning använder och några testanvändare.
# Kan köras flera gånger, det som redan finns hoppas över.
#
#   ./scripts/entra.sh
#
# Hemligheter (klienthemlighet, testlösenord) hamnar i Nordvik/.env.local,
# som ligger i .gitignore.
set -euo pipefail
cd "$(dirname "$0")/.."

DOMAN=$(az rest --method get --url https://graph.microsoft.com/v1.0/domains \
  --query "value[?isDefault].id | [0]" -o tsv)
APPNAMN="app-nordvik-portal"
FORVALTARE_M365="azureuser@${DOMAN}"   # licensierat konto, får notiserna i Teams och Outlook
touch .env.local

grupp() {
  local namn=$1 beskrivning=$2
  local id
  id=$(az ad group list --display-name "$namn" --query "[0].id" -o tsv)
  if [ -z "$id" ]; then
    id=$(az ad group create --display-name "$namn" --mail-nickname "$namn" \
      --description "$beskrivning" --query id -o tsv)
  fi
  echo "$id"
}

GRUPP_HYRESGAST=$(grupp grp-nordvik-hyresgaster "Hyresgäster i Nordviks portal: skapar och ser egna felanmälningar")
GRUPP_FORVALTARE=$(grupp grp-nordvik-forvaltare "Förvaltare: hanterar alla felanmälningar och dokument")
GRUPP_EKONOMI=$(grupp grp-nordvik-ekonomi "Ekonomi: läsande insyn i sammanställningar, dokument och kostnader")

# Appregistrering. Gruppclaims gör att token innehåller gruppernas id:n, så
# portalen kan styra behörighet utan Entra ID P1 (som krävs för att tilldela
# app-roller till grupper).
APP_ID=$(az ad app list --display-name "$APPNAMN" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  APP_ID=$(az ad app create --display-name "$APPNAMN" --sign-in-audience AzureADMyOrg \
    --enable-id-token-issuance true --query appId -o tsv)
  az ad sp create --id "$APP_ID" -o none
fi
az ad app update --id "$APP_ID" --set groupMembershipClaims=SecurityGroup

if ! grep -q '^ENTRA_CLIENT_SECRET=' .env.local; then
  HEMLIGHET=$(az ad app credential reset --id "$APP_ID" --append --display-name containerapps \
    --years 1 --query password -o tsv)
  echo "ENTRA_CLIENT_SECRET='${HEMLIGHET}'" >> .env.local
fi

# Testanvändare: Blomman är förvaltare, Bubblan och Buttran är hyresgäster (två
# stycken för att visa att man inte ser varandras anmälningar) och Professorn är ekonomi.
anvandare() {
  local alias=$1 namn=$2 grupp_id=$3
  local upn="${alias}@${DOMAN}"
  local id
  id=$(az ad user list --upn "$upn" --query "[0].id" -o tsv)
  if [ -z "$id" ]; then
    local losen="Nv-$(openssl rand -hex 6)-$(openssl rand -hex 3 | tr a-f A-F)!"
    id=$(az ad user create --display-name "$namn" --user-principal-name "$upn" \
      --password "$losen" --force-change-password-next-sign-in false --query id -o tsv)
    echo "LOSEN_${alias//./_}='${losen}'" >> .env.local
  fi
  az ad group member check --group "$grupp_id" --member-id "$id" --query value -o tsv | grep -q true \
    || az ad group member add --group "$grupp_id" --member-id "$id"
}

anvandare blomman "Blomman" "$GRUPP_FORVALTARE"
anvandare bubblan "Bubblan" "$GRUPP_HYRESGAST"
anvandare buttran "Buttran" "$GRUPP_HYRESGAST"
anvandare professorn "Professorn" "$GRUPP_EKONOMI"

M365_ID=$(az ad user show --id "$FORVALTARE_M365" --query id -o tsv)
az ad group member check --group "$GRUPP_FORVALTARE" --member-id "$M365_ID" --query value -o tsv | grep -q true \
  || az ad group member add --group "$GRUPP_FORVALTARE" --member-id "$M365_ID"

cat <<EOF

Klart. Lägg in de här i infra/azuredeploy.parameters.*.json:
  entraClientId     $APP_ID
  gruppHyresgaster  $GRUPP_HYRESGAST
  gruppForvaltare   $GRUPP_FORVALTARE
  gruppEkonomi      $GRUPP_EKONOMI
Testanvändarnas lösenord står i .env.local.
EOF
