# Vecka 38 – Infrastructure as Code (CLI & ARM-template)

Tidigare veckor har miljön (VM, nätverk, NSG, storage m.m.) byggts upp grafiskt via Azure Portal. Den här veckan återskapas samma typ av miljö helt i kod via Azure CLI, ARM-templates och Bicep, så att den kan driftsättas reproducerbart utan manuella klick i portalen.

## Filerna

- `storage.bicep` – ett enda storage account skrivet i Bicep.
- `azuredeploy-enkel.json` – samma storage account i ARM JSON.
- `azuredeploy-parametriserad.json` + `azuredeploy.parameters.json` – samma resurs, men parametriserad med `location` och `sku`.
- `miljo-skelett.json` – skelettet där själva miljön byggs: NSG med webbregel (port 80/443), VNet med subnät och storage account, samt (för VG) en VM kopplad med `dependsOn`.

## Status

Startpaketet med exempelfiler är på plats. Nästa steg är att fylla i `miljo-skelett.json` med den faktiska miljön och dokumentera deployment via `az deployment group create` / `what-if`.
