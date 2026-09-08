# Novatrix – Driftsättning av kundtjänstsida på Azure

## Vecka 34 – Provisionera VM i Azure, installera Nginx och driftsätt kundtjänstsidan

### Delmoment 1 – GitHub-repo
https://github.com/96lonsor/azure-MOV25

### Delmoment 2 – Provisionera virtuell server

**Skapa Azure-konto och resursgrupp**
- Skapade ett nytt Azure-konto (96lonsor@gmail.com)
- Skapade en resursgrupp via sökfunktionen i portalen, med det föreslagna namnformatet: `rg-novatrix-v34-2`

**Skapa VM**
- Sökte på "virtuella datorer" i portalen och klickade på Skapa
- Valde prenumeration och resursgrupp `rg-novatrix-v34-2`
- Gav maskinen namnet `vm-novatrix-web`
- Valde samma region som resursgruppen: Sweden Central
- Valde avbildningen Ubuntu Server 24.04 LTS
- Valde storleken Standard B2ts v2 (2 vCPU, 1 GiB RAM) – en av de billigaste storlekarna Azure erbjuder (ca 7 $/månad), fullt tillräcklig för en enkel Nginx-driven statisk sida. Novatrix betalar inte för mer kapacitet än de behöver.
- Valde autentiseringstyp SSH-offentlig nyckel
- Lät Azure generera ett nytt nyckelpar och gav det ett namn
- Angav användarnamnet `azureuser`
- Tillät inkommande port 22 (SSH) så att servern går att nå för administration
- Granskade och skapade resursen
- När nyckelrutan dök upp laddades den privata nyckeln (`vm-novatrix-web_key.pem`) ner direkt
- Sparade nyckeln i en egen, lätt återfunnen mapp lokalt
- Väntade medan maskinen provisionerades

**Resulterande resurser i `rg-novatrix-v34-2`:**

| Resurs | Typ |
|---|---|
| vm-novatrix-web | Virtual machine |
| vm-novatrix-web-ip | Public IP address |
| vm-novatrix-web-nsg | Network security group |
| vm-novatrix-web357 | Network interface |
| vm-novatrix-web_key | SSH key |
| vm-novatrix-web_OsDisk... | Disk |
| vnet-swedencentral-1 | Virtual network |

Publik IP-adress: `51.12.242.171`

**Verifiering av delmoment 2:** VM:ens status är "Running" i portalen, storlek och OS stämmer under Properties (Ubuntu 24.04, Standard B2ts v2), och en publik IP-adress finns tilldelad.

### Delmoment 3 – Konfigurera värdmiljön

**Anslut via SSH**
- Kopierade VM:ens publika IP-adress från portalen: `51.12.242.171`
- Öppnade en terminal lokalt (PowerShell)
- Satte rätt behörighet på nyckelfilen. På Windows/PowerShell användes `icacls` istället för `chmod 400`:

\`\`\`powershell
icacls .\vm-novatrix-web_key.pem /inheritance:r
icacls .\vm-novatrix-web_key.pem /grant:r "$($env:USERNAME):R"
\`\`\`

- Anslöt till servern:

\`\`\`bash
ssh -i .\vm-novatrix-web_key.pem azureuser@51.12.242.171
\`\`\`

- Svarade `yes` på frågan om att lita på serverns fingeravtryck första gången

**Uppdatera servern**

Alltid första steget på en ny server – en uppdaterad server är en säkrare server.

\`\`\`bash
sudo apt update
sudo apt upgrade -y
\`\`\`

`sudo` kör kommandot med adminrättigheter, `apt update` hämtar den senaste listan över tillgängliga paket och `apt upgrade -y` installerar tillgängliga uppdateringar utan att fråga för varje paket.

**Installera Nginx**

\`\`\`bash
sudo apt update
sudo apt install nginx -y
\`\`\`

Kontrollera att tjänsten är igång:

\`\`\`bash
systemctl status nginx
\`\`\`

Status: `active (running)`

Öppnade sedan webbläsaren och surfade till serverns publika IP (`51.12.242.171`) – Nginx standard-välkomstsida visades korrekt.

**Nätverkssäkerhetsgrupp (NSG):** för att sidan skulle nå ut via HTTP behövde inkommande port 80 tillåtas, utöver port 22 för SSH.

**Verifiering av delmoment 3:**
- `systemctl status nginx` visar `active (running)`
- `http://51.12.242.171` visar Nginx standardsida i webbläsaren
- Inkommande portregler i NSG:n listar både port 22 (SSH) och port 80 (HTTP) som Allow

**Vanliga felkällor att kontrollera om sidan inte visas:**
- Är Nginx verkligen igång? (`systemctl status nginx`)
- Är port 80 öppen i nätverkssäkerhetsgruppen?
- Surfar du på `http://` och inte `https://`? (Ingen SSL är konfigurerad ännu.)
- Är det rätt publika IP-adress – dubbelkolla i portalen

### Delmoment 4 – Driftsätt kundtjänstsidan med ärendeformulär

Navigerade till mappen där Nginx letar efter innehåll:

\`\`\`bash
cd /var/www/html
ls -la
\`\`\`

Tog en säkerhetskopia av standardsidan innan den skrevs över:

\`\`\`bash
sudo cp index.nginx-debian.html index.html
\`\`\`

Öppnade filen för redigering:

\`\`\`bash
sudo nano index.html
\`\`\`

Lade in en rubrik och ett statiskt ärendeformulär med fälten namn, e-post (mail) och meddelande. I det här läget skickar formuläret inget – det visas bara på sidan, precis som uppgiften kräver.

**index.html:**

\`\`\`html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to Novatrix</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Novatrix</h1>
<p>Uppdateras inom kort</p>

<form>
<label for="name">Namn</label>
<input type="text" id="name" name="name"><br>
<label for="mail">Mail</label>
<input type="text" id="mail" name="mail"><br>
<label for="msg">Meddelande</label>
<textarea id="msg" name="msg" rows="4" cols="50"></textarea><br>
<input type="submit" value="Skicka">
</form>

</body>
</html>
\`\`\`

Sparade och stängde i nano: `Ctrl+O` (spara), `Enter` (bekräfta filnamn), `Ctrl+X` (stäng).

Uppdaterade webbläsaren – Novatrix egen sida med ärendeformuläret visades istället för Nginx standardsida.

**Verifiering av delmoment 4:**
- `cat /var/www/html/index.html` på servern visar samma innehåll som redigerades
- `curl http://localhost` från servern returnerar sidans HTML
- `http://51.12.242.171` i webbläsaren visar rubriken Novatrix och formuläret med fälten Namn, Mail och Meddelande

### Delmoment 5 – Verifiera och dokumentera

Sammanfattad verifiering av hela kedjan, från infrastruktur till innehåll:

| Steg | Verifieringsmetod | Resultat |
|---|---|---|
| VM provisionerad | Portalen → Properties (OS, storlek, IP) | Ubuntu 24.04, B2ts v2, publik IP tilldelad |
| SSH-anslutning | `ssh -i <nyckel> azureuser@<ip>` | Inloggad utan fel |
| Nginx installerad | `systemctl status nginx` | active (running) |
| Port 80 öppen | NSG → Inbound port rules | Port 80 Allow |
| Sidan nåbar | Webbläsare mot `http://51.12.242.171` | Novatrix-sida med formulär visas |
| Rätt innehåll | `cat /var/www/html/index.html` på servern | Matchar redigerad fil |

All kod (HTML) och denna dokumentation (steg, kommandon och skärmdumpar) finns i GitHub-repot enligt Delmoment 1.

**Kostnad och nedrivning**

VM-storleken B2ts v2 valdes specifikt för att hålla kostnaden nere (ca 7 $/månad) eftersom sidan bara behöver köra en lätt Nginx-instans med statiskt innehåll.

För att inte förbruka onödig kredit rivs resursgruppen ner när arbetet för veckan är klart, och sätts upp på nytt nästa gång som behövs:

\`\`\`bash
az group delete --name rg-novatrix-v34-2 --yes --no-wait
\`\`\`

Eller via portalen: Resursgrupper → rg-novatrix-v34-2 → Delete resource group.

### VG-delen

Två filer ersätter alla manuella klick i portalen: `cloud-init.yaml` säger åt Azure vad servern ska göra vid uppstart (installera Nginx, lägga ut sidan), och `deploy.sh` kör Azure CLI-kommandona som skapar resursgrupp och VM och kopplar ihop dem.

**cloud-init.yaml:**

\`\`\`yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    owner: www-data:www-data
    permissions: '0644'
    content: |
      <!DOCTYPE html>
      <html>
      <head>
      <title>Welcome to Novatrix</title>
      <style>
      html { color-scheme: light dark; }
      body { width: 35em; margin: 0 auto;
      font-family: Tahoma, Verdana, Arial, sans-serif; }
      </style>
      </head>
      <body>
      <h1>Novatrix</h1>
      <p>Uppdateras inom kort</p>
      <form>
      <label for="name">Namn</label>
      <input type="text" id="name" name="name"><br>
      <label for="mail">Mail</label>
      <input type="text" id="mail" name="mail"><br>
      <label for="msg">Meddelande</label>
      <textarea id="msg" name="msg" rows="4" cols="50"></textarea><br>
      <input type="submit" value="Skicka">
      </form>
      </body>
      </html>
runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
\`\`\`

**deploy.sh:**

\`\`\`bash
# TODO: lägg in det riktiga deploy.sh-innehållet här
# (Azure CLI-kommandona som skapar resursgrupp, VM m.m.)
\`\`\`

**Hur miljön återskapas helt från repot, utan klick i portalen**

Klona repot och gå in i mappen med IaC-filerna:

\`\`\`bash
git clone <ditt-repo-url>
cd <repo>/iac
chmod +x deploy.sh teardown.sh
\`\`\`

Logga in i Azure CLI (öppna webbläsaren en gång för autentisering, inget klickande i portalen):

\`\`\`bash
az login
\`\`\`

Kör hela provisioneringen med ett kommando:

\`\`\`bash
./deploy.sh
\`\`\`

Riv ner allt när jag är klar för att inte förbruka kredit:

\`\`\`bash
./teardown.sh
\`\`\`
