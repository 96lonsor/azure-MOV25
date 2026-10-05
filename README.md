# Azure-MOV25

**Luna Lindström** – Detta är mitt repo för Azure-kursen.

## Innehåll

| Vecka | Ämne | Länk |
|---|---|---|
| 34 | Provisionera VM, installera Nginx och driftsätt kundtjänstsidan | [V34](./V34/README.md) |
| 35 | IAM & RBAC | [V35](./V35/README.md) |
| 36 | Nätverk och säkerhet | [V36](./V36/README.md) |
| 37 | Lagring (Storage) | [V37](V37) |
| 38 | Infrastructure as Code (CLI & ARM-template) | [V38](./V38/README.md) |
| 39 | Power Automate & Microsoft 365-integration | [V39](./V39/README.md) |
| 40 | Container i Azure Container Instances (ACI) | [V40](./V40/README.md) |

## Vecka 34 – Provisionera VM, Nginx och kundtjänstsida

Provisionerade en virtuell maskin i Azure, installerade Nginx och driftsatte Novatrix kundtjänstsida med ett statiskt ärendeformulär. Se [V34/README.md](./V34/README.md) för fullständig dokumentation, kommandon och verifiering.

## Vecka 35 — IAM & RBAC

Se [V35](./V35/README.md) för anteckningar om Azure IAM, Entra ID och RBAC.

## Vecka 36 - Nätverk och säkerhet

Byggt vidare på nätverket med flera nätverkskort (NIC) och konfigurerat NSG-regler för att säkra trafiken (HTTP/HTTPS öppet, SSH begränsat till specifik IP). Se [V36/README.md](./V36/README.md) för detaljer.

## Vecka 37 — Lagring (Storage)

Skapade ett storage account (`stnovatrix96`) och en privat Blob-container (`arenden`) för att ta emot inskickade ärenden och bifogade filer. Säkrade åtkomsten med tidsbegränsad SAS-token (endast läsbehörighet) och RBAC-rollen Storage Blob Data Reader, enligt least privilege. Se [V37/README.md](V37/README.md) för fullständig dokumentation, kommandon och verifiering.

## Vecka 38 — Infrastructure as Code (CLI & ARM-template)

Återskapar samma miljö som byggdes grafiskt i tidigare veckor, men nu helt i kod via Azure CLI och ARM-templates, för reproducerbar driftsättning utan manuella klick i portalen. Se [V38/README.md](./V38/README.md) för fullständig dokumentation, kommandon och verifiering.

## Vecka 39 — Power Automate & Microsoft 365-integration

Byggde ett Power Automate-flöde som triggas när ett nytt ärende skickas in, skapar en post i SharePoint-listan "Novatrix ärenderegister" och notifierar kundtjänst i Teams. Flödet kopplades till den befintliga Azure-lösningen (VM + Flask-backend) så att ett inskickat ärende går hela vägen från formuläret till en post och notis i Microsoft 365. Se [V39/README.md](./V39/README.md) för fullständig dokumentation av flödets steg och verifiering.

## Vecka 40 — Container i Azure Container Instances

Körde Novatrix kundtjänstsida som en container i ACI i stället för på en VM. Imagen (nginx:alpine + sidan) byggdes i Azure Container Registry med `az acr build` och startades med `az container create`. README:n tar också upp varför containernivån passar Novatrix bättre än en VM när det gäller kostnad, skalning och drift. Se [V40/README.md](./V40/README.md).

---

# Slutuppgift – Nordvik Fastigheter

Slutuppgiften är ett nytt företag och ligger därför i en egen mapp, [Nordvik](./Nordvik/README.md), och inte bland veckorna ovan.

Nordvik förvaltar bostäder och lokaler och ville ha en portal där hyresgäster kan göra felanmälan med bild. Jag körde portalen i Azure Container Apps, lade lagringen bakom private endpoints och styrde hyresgäst, förvaltare och ekonomi med grupper i Entra ID. Hela Azure-delen byggs från en ARM-mall, och ett Power Automate-flöde lägger varje anmälan i en SharePoint-lista och skickar notis till förvaltaren i Teams, plus ett mejl om felet är akut.
