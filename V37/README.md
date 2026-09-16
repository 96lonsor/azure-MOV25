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

Bra påpekande, då delar vi upp det exakt som din lärares instruktion säger. Här är Delmoment 3, 4 och 5 omstrukturerade som separata avsnitt:

Delmoment 3 – Koppla formuläret till lagringen

Ärendeformuläret (index.html) och en Flask-backend (app.py) driftsattes på VM:en vm-novatrix-web, körandes som en systemd-tjänst (arendeapp.service) bakom nginx som reverse proxy. När ett ärende skickas in via formuläret tar backenden emot namn, e-post, meddelande och en eventuell bifogad fil, och laddar automatiskt upp ärendet som en JSON-fil till containern arenden — samt, om en bild bifogats, bilden som en separat blob bredvid.

Som en tidigare, enklare demonstration laddades även en bild upp manuellt via portalen, för att visa grundfunktionen innan hela formulärflödet var på plats:

URL:

https://stnovatrix96.blob.core.windows.net/arenden/Boat.jpg

Delmoment 4 – Säkra åtkomsten

Åtkomsten säkrades enligt de metoder som gåtts igenom i kursen, med least privilege som utgångspunkt. Flera metoder utforskades för att jämföra dem, och den som faktiskt används av appen beskrivs sist.

Steg 1 – Generera en SAS-token
I containern arenden valdes filen Boat.jpg, därefter Generate SAS. Endast behörigheten Read (läsa) bockades i, en kort giltighetstid (cirka en timme) sattes, och en SAS-token genererades. Blob-URL:en med SAS-token kopierades.

URL med SAS-token (tidsbegränsad, endast läsbehörighet):

https://stnovatrix96.blob.core.windows.net/arenden/Boat.jpg?sp=r&st=2026-09-14T07:40:06Z&se=2026-09-14T20:40:06Z&spr=https&sv=2026-02-06&sr=b&sig=FjsOwPxZkBkfEG%2FNCTCijAdMQ86IwXkhd6q6y6gfXq4%3D

Steg 2 – Rolltilldelning (RBAC) på storage-kontot
Under storage-kontot valdes IAM → Add role assignment → rollen Storage Blob Data Reader → identiteten (användare/app) som ska ha läsbehörighet valdes → tilldelningen granskades och sparades.

Steg 3 – Hanterad identitet (Managed Identity) + RBAC scopead till containern — metoden appen faktiskt använder
En system-tilldelad hanterad identitet (System-assigned managed identity) aktiverades på VM:en vm-novatrix-web. Backend-koden använder DefaultAzureCredential från azure-identity, som automatiskt hämtar en token via VM:ens identitet (IMDS) — ingen nyckel eller hemlighet lagras i koden.

Under containern arenden (inte hela storage-kontot) valdes Access Control (IAM) → Add role assignment → rollen Storage Blob Data Contributor → medlem: den hanterade identiteten för vm-novatrix-web. Genom att scopa rollen till just containern, istället för hela storage-kontot, begränsas åtkomsten ytterligare: appen kan bara läsa och skriva blobar i arenden, ingenting annat i prenumerationen.

Val av lagringsnivå: Storage account stnovatrix96 (Sweden Central) använder redundansnivån Locally-redundant storage (LRS) och Hot access tier. LRS valdes eftersom detta är en testmiljö för ett kursprojekt utan krav på skydd mot regionala avbrott eller katastrofer. Hot valdes eftersom nyligen inskickade ärenden förväntas läsas och nås ofta i närtid.

Delmoment 5 – Verifiera och dokumentera

Att ett inskickat ärende faktiskt hamnar i lagringen:

Formuläret testades genom att skicka in ett ärende med en bifogad skärmbild via http://4.165.139.190/. Svaret blev en bekräftelsesida: "Tack för ditt ärende! Ärende-id: ff064538". I Azure Portal, under containern arenden, syns därefter två nya filer med tidsstämpel som matchar inskickningen:

arende-ff064538.json
arende-ff064538-Skärmbild 2026-09-16 160940.png

Detta bevisar end-to-end att ett riktigt inskickat ärende hamnar i lagringen automatiskt, utan manuellt portal-arbete.

Att åtkomsten är säkrad:

Containern arenden har åtkomstnivån Private (no anonymous access) — bekräftat i portalen under "Change access level".
Appen autentiserar via den system-tilldelade hanterade identiteten på vm-novatrix-web, inte via kontonyckel eller lösenord i kod.
Identiteten har enbart rollen Storage Blob Data Contributor, scopead specifikt till containern arenden — inte till hela storage-kontot eller prenumerationen.
Inga hemligheter (nycklar, lösenord, tokens) finns hårdkodade i app.py eller committade till repot.

Motivering av valen:

Managed identity + RBAC scopead till containern valdes som den metod appen faktiskt använder, eftersom det ger starkast least privilege av de alternativ som testades: SAS-token (Steg 1) kräver manuell generering och distribution per fil och riskerar att läcka om token delas; RBAC på kontonivå (Steg 2) ger bredare åtkomst än vad appen behöver. Managed identity scopead till en enskild container eliminerar helt behovet av att hantera, rotera eller skydda hemligheter, samtidigt som åtkomsten är så snävt avgränsad som möjligt — appen kan varken läsa andra containrar eller administrera kontot.
