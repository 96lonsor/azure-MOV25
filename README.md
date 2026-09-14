# Azure-MOV25

**Luna Lindström** – Detta är mitt repo för Azure-kursen.

## Innehåll

| Vecka | Ämne | Länk |
|---|---|---|
| 34 | Provisionera VM, installera Nginx och driftsätt kundtjänstsidan | [V34](./V34/README.md) |
| 35 | IAM & RBAC | [V35](./V35/README.md) |
| 36 | Nätverk och säkerhet | [V36](./V36/README.md) |
| 37 | Lagring (Storage) | [V37](V37) |

## Vecka 34 – Provisionera VM, Nginx och kundtjänstsida

Provisionerade en virtuell maskin i Azure, installerade Nginx och driftsatte Novatrix kundtjänstsida med ett statiskt ärendeformulär. Se [V34/README.md](./V34/README.md) för fullständig dokumentation, kommandon och verifiering.

## Vecka 35 — IAM & RBAC

Se [V35](./V35/README.md) för anteckningar om Azure IAM, Entra ID och RBAC.

## Vecka 36 - Nätverk och säkerhet

Byggt vidare på nätverket med flera nätverkskort (NIC) och konfigurerat NSG-regler för att säkra trafiken (HTTP/HTTPS öppet, SSH begränsat till specifik IP). Se [V36/README.md](./V36/README.md) för detaljer.

## Vecka 37 — Lagring (Storage)

Skapade ett storage account (`stnovatrix96`) och en privat Blob-container (`arenden`) för att ta emot inskickade ärenden och bifogade filer. Säkrade åtkomsten med tidsbegränsad SAS-token (endast läsbehörighet) och RBAC-rollen Storage Blob Data Reader, enligt least privilege. Se [V37/README.md](V37/README.md) för fullständig dokumentation, kommandon och verifiering.
