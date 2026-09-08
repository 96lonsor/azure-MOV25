# Vecka 36 – Nätverkskort, NSG och nätverkssäkerhet

## Sammanfattning
Den här veckan har jag byggt vidare på det virtuella nätverket från tidigare veckor, med fokus på nätverkskort (NIC) på virtuella maskiner och att säkra trafiken med Network Security Groups (NSG).

## Vad jag har gjort

- Lärt mig varför en VM kan behöva flera nätverkskort (NIC:ar) – t.ex. för att separera publik och intern trafik, eller för nätverksapplianser som brandväggar och lastbalanserare.
- Skapat och kopplat en ny intern NIC (`nic2-vm-novatrix-web-internal`) till VM:et `vm-novatrix-web`, som komplement till den befintliga publika NIC:en (`vm-novatrix-web357`):
  - **Publik NIC** – har en publik IP-adress och hanterar webbtrafik från internet.
  - **Intern NIC** – ingen publik IP, avsedd för intern kommunikation.
- Konfigurerat NSG:n på den publika NIC:en enligt principen om minsta möjliga öppna yta:
  - Öppnat port 80 och 443 (HTTP/HTTPS) för webbtrafik, källa: Internet.
  - Begränsat SSH (port 22) till endast min egen publika IP-adress, istället för att lämna den öppen mot hela internet.
- Verifierat trafikreglerna med **Network Watcher → IP flow verify**, för att kontrollera vilka portar/regler som faktiskt släpps igenom respektive blockeras.
- Kontrollerat att VM:arna står som "Stopped (deallocated)" i Azure Portal när jag är klar, för att undvika onödig kostnad.

Uppgift 3 - Nätverk och säkerhet

## Delmoment 1 – Repo - Skapa avsnitt för v36 och uppdatera README.

## Delmoment 2 – Bygg det virtuella nätverket
Skapa ett VNet med lämpliga subnät: ett publikt subnät för webben och formuläret, och ett privat subnät förberett för lagringen och backend som kommer senare.
DEMO: Skapa ett VNet i portalen
Logga in på portal.azure.com
Sök på "Virtual networks" i sökrutan högst upp
Klicka Skapa, välj resursgruppen rg-novatrix
Ge nätverket namnet vnet-novatrix och välj region
Sätt adressrymden till 10.0.0.0/16
Gå vidare till fliken för IP-adresser och subnät


## Delmoment 3 – Säkra trafiken
Konfigurera NSG:er så att endast nödvändig trafik tillåts: HTTP och HTTPS in mot formuläret, och begränsad administrativ åtkomst. Stäng allt annat.
Portar: 22, 80 och 443
Vi öppnar minsta möjliga antal portar – bara nödvändiga portar och källor. En port är som en specifik dörr in till servern.
Port 80: Vanlig webbtrafik (HTTP)
Port 443: Krypterad webbtrafik (HTTPS)
Port 22: SSH (administrativ inloggning till Linux)
Webb får vara öppen brett, SSH ska vara hårt begränsad.

DEMO: Skapa en NSG
Sök på "Network security groups" i portalen
Klicka Skapa, välj resursgruppen rg-novatrix
Ge den namnet nsg-web och samma region som nätet
Klicka Granska + skapa, och sedan Skapa
Öppna NSG:n och titta på Inkommande regler – notera default-reglerna som redan ligger där

DEMO: Tillåt HTTP och HTTPS (80/443)
Under Inkommande regler, klicka Lägg till
Källa: Service Tag, välj Internet
Destinationsportar: 80,443
Protokoll: TCP, Åtgärd: Allow, Prioritet: 100
Namnge regeln allow-web och klicka Lägg till
Nu släpps webbtrafik in till servern.

## Delmoment 4 – Placera webbservern rätt -Se till att webbservern med formuläret ligger i det publika subnätet och skyddas av dina regler, och att det privata subnätet är redo för nästa vecka.


## Delmoment 5 – Verifiera med Network Watcher
Här kan du via Network Watcher → IP flow verify se vilka portar/regler som släpps igenom och vilka som inte gör det.







