# Startpaket, IaC med ARM-templates (v38)

Det här är en startpunkt att bygga vidare på, inte en färdig lösning. Filerna visar mönstret för hur en ARM-template och en Bicep-fil ser ut, så att du slipper stirra på ett tomt dokument. Själva miljön bygger du själv, det är det du ska lära dig den här veckan, och det är grunden för examinationen.

Allt deployas mot din resursgrupp (rg-novatrix i exemplen), enklast i Cloud Shell.

## Filerna

- `storage.bicep`, ett enda storage account skrivet i Bicep. Kortast av allt, bra för att se strukturen.
    - `az deployment group create -g rg-novatrix --template-file storage.bicep`
- `azuredeploy-enkel.json`, samma storage account i ARM JSON. Den första mallen du kan deploya för att se hela flödet från fil till resurs.
    - `az deployment group create -g rg-novatrix --template-file azuredeploy-enkel.json --parameters storageName=stn+dittnamn`
- `azuredeploy-parametriserad.json` plus `azuredeploy.parameters.json`, samma enda resurs men parametriserad. Här ser du hur parametrar, allowedValues och en parameterfil hänger ihop.
    - Förhandsgranska: `az deployment group what-if -g rg-novatrix --template-file azuredeploy-parametriserad.json --parameters @azuredeploy.parameters.json`
    - Deploya: `az deployment group create -g rg-novatrix --template-file azuredeploy-parametriserad.json --parameters @azuredeploy.parameters.json`
- `miljo-skelett.json`, ett tomt men giltigt skelett med rätt struktur ($schema, parameters, variables, resources, outputs). Det är här du bygger din egen miljö.

## Vad du ska bygga själv i skelettet

Använd de enkla exemplen som mönster. Varje resurs har samma fem fält: type, apiVersion, name, location och properties.

- För godkänt: lägg till en NSG med en webbregel (portar 80 och 443), ett VNet med ett subnät, och ett storage account. Gör namn och region till parametrar.
- För väl godkänt: ta med huvudsakligen hela miljön (även en VM), koppla ihop resurserna med dependsOn, och se till att allt kan återskapas från ditt repo utan klick i portalen.

## Kom ihåg

- Storage-kontonamn måste vara globalt unikt och med små bokstäver.
- Kör alltid what-if innan en skarp deploy, och verifiera i portalen efteråt.
- Committa ofta med tydliga meddelanden, historiken är en del av inlämningen.
- Inga hemligheter (lösenord, nycklar) i klartext i ett publikt repo.
