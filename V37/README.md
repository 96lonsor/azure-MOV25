# Uppgift 4 – Lagring (Storage)

Novatrix AB behöver kunna ta emot ärenden med bifogade filer och lagra dem säkert i Azure. Nedan dokumenteras hur lagringen skapades, kopplades till inskickade ärenden och säkrades.

## Delmoment 1 – Repo

Ett nytt avsnitt för v37 har skapats i repot och `README.md` har uppdaterats med den här veckans dokumentation.

## Delmoment 2 – Skapa lagring

Målet var att skapa ett storage account och en Blob-container för Novatrix ärenden och bifogade filer.

**Steg 1 – Skapa storage account**

Precis som för tidigare resurser söktes "Storage account" i sökrutan i Azure Portal, följt av klick på **Create**. Resultatet blev storage account `stnovatrix96`.

**Steg 2 – Skapa Blob-container**

Under menyn **Containers** valdes **+ Container**, och containern namngavs `arenden` (ärenden utan å/ä för att undvika teckenproblem i URL:er). Åtkomstnivån lämnades som **Privat (ingen anonym åtkomst)** – bredare åtkomst ges i stället separat i Delmoment 4. Containern skapades och utgör nu lagringsplatsen för filerna.

## Delmoment 3 – Koppla formuläret till lagringen

Klicka dig in i "arenden" och ladda upp. Jag laddade upp en bild på en båt som jag manifesterar att ha.

**URL:**

```
https://stnovatrix96.blob.core.windows.net/arenden/Boat.jpg
```

## Delmoment 4 och 5 – Säkra åtkomsten

Åtkomsten till lagringen säkrades enligt de metoder som gåtts igenom i kursen, med least privilege som utgångspunkt (samma princip som för appens managed identity i v35) – appen/identiteten ska bara kunna nå rätt container, inte mer, och onödigt öppen åtkomst undviks.

**Steg 1 – Generera en SAS-token**

I containern `arenden` valdes filen `Boat.jpg`, därefter **Generate SAS**. Endast behörigheten **Read (läsa)** bockades i, en kort giltighetstid (cirka en timme) sattes, och en SAS-token genererades. Blob-URL:en med SAS-token kopierades.

**URL med SAS-token (tidsbegränsad, endast läsbehörighet):**

```
https://stnovatrix96.blob.core.windows.net/arenden/Boat.jpg?sp=r&st=2026-09-14T07:40:06Z&se=2026-09-14T20:40:06Z&spr=https&sv=2026-02-06&sr=b&sig=FjsOwPxZkBkfEG%2FNCTCijAdMQ86IwXkhd6q6y6gfXq4%3D
```

**Steg 2 – Rolltilldelning (RBAC) på storage-kontot**

Under storage-kontot valdes **IAM** → **Add role assignment** → rollen **Storage Blob Data Reader** → identiteten (användare/app) som ska ha läsbehörighet valdes → tilldelningen granskades och sparades.

## Övrigt

**Val av lagringsnivå:** Storage account `stnovatrix96` (Sweden Central) använder redundansnivån **Locally-redundant storage (LRS)** och **Hot** access tier. LRS valdes eftersom detta är en testmiljö för ett kursprojekt utan krav på skydd mot regionala avbrott eller katastrofer – LRS ger tillräcklig hållbarhet genom att replikera data tre gånger inom samma datacenter, till betydligt lägre kostnad än zon- eller georedundans (ZRS/GRS), som är motiverat först vid högre krav på tillgänglighet. Hot valdes eftersom nyligen inskickade ärenden och bifogade filer förväntas läsas och nås ofta i närtid; om äldre ärenden sällan behöver nås skulle Cool kunna användas för dem för att sänka lagringskostnaden ytterligare.

- Containern `arenden` är privat → ingen anonym åtkomst är tillåten.
- Extern, tillfällig åtkomst till enskilda filer ges via SAS-token, begränsad till läsbehörighet och med kort giltighetstid (~1 timme), i stället för att dela kontonyckeln.
- Behörighet på kontonivå tilldelas via RBAC-rollen **Storage Blob Data Reader**, vilket ger läsrättighet utan att exponera hanteringsbehörigheter.
- Tillsammans ger detta least privilege: identiteten/appen kan bara läsa (och i förlängningen skriva, via motsvarande roll för appens managed identity) i rätt container – inte administrera eller nå andra resurser.
- Inga kontonycklar eller andra hemligheter har committats till repot. Åtkomst sker via SAS-token med kort livslängd och via RBAC-tilldelade identiteter, inte via delade nycklar i kod.
- Filen `Boat.jpg` syns i containern `arenden` i portalen och kan öppnas via SAS-länken, vilket visar att ett inskickat ärende med bifogad fil faktiskt hamnar i lagringen.
