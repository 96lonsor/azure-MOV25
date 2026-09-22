# Vecka 38 – Infrastructure as Code (CLI & ARM-template)

Tidigare veckor har miljön (VM, nätverk, NSG, storage m.m.) byggts upp grafiskt via Azure Portal. Den här veckan återskapas samma typ av miljö helt i kod via Azure CLI, ARM-templates och Bicep, så att den kan driftsättas reproducerbart utan manuella klick i portalen.

## Filerna

- `storage.bicep` – ett enda storage account skrivet i Bicep.
- `azuredeploy-enkel.json` – samma storage account i ARM JSON.
- `azuredeploy-parametriserad.json` + `azuredeploy.parameters.json` – samma resurs, men parametriserad med `location` och `sku`.
- `miljo-skelett.json` – skelettet där själva miljön byggs: NSG med webbregel (port 80/443), VNet med subnät och storage account, samt (för VG) en VM kopplad med `dependsOn`.

## Status

`miljo-skelett.json` innehåller nu hela miljön: NSG med webbregel (80/443), VNet med subnät, storage account, samt (för VG) publik IP, nätverkskort och en Ubuntu-VM, ihopkopplade med `dependsOn`. VM:en loggar in via SSH-nyckel istället för lösenord, så ingen hemlighet behöver lagras i repot.

Nästa steg är att deploya via `az deployment group create` / `what-if` och verifiera resultatet mot resursgruppen.
