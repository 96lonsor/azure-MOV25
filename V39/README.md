# Vecka 39 – Power Automate och Microsoft 365

Novatrix ärendeformulär skickar redan idag in ärenden till Flask-backend på `vm-novatrix-web`, som sparar dem i Blob Storage (se [V37](../V37/README.md)). Den här veckan är målet att koppla på Microsoft 365 så att ett ärende även dyker upp i ett register i SharePoint och att kundtjänst får en notis om det, via ett Power Automate-flöde.

## Delmoment 1 – Repo

Skapat ett nytt avsnitt för v39 och uppdaterat `README.md` i roten.

## Delmoment 2 – Bygg ett flöde

Uppgift: skapa ett Power Automate-flöde som triggas när ett nytt ärende kommer in.

Ärenden sparas redan automatiskt som filer i Blob Storage-containern `arenden` när någon skickar in formuläret (se Delmoment 4). Därför byggdes flödet för att bevaka containern direkt, istället för att vänta på ett anrop utifrån.

- Skapade ett nytt automatiserat molnflöde i Power Automate.
- Trigger: **When a blob is added or modified (properties only) (V2)**, kopplad mot storage account `stnovatrixw7exi6thpfmeq` (Access Key-anslutning), och pekar på containern `arenden`.
- La till ett **Send an email (V2)**-steg direkt efter triggern, för att kunna testa hela kedjan innan resten av flödet (SharePoint-listan, den riktiga notisen) byggs ut.
- Testade genom att skicka in riktiga ärenden via formuläret — containern `arenden` har nu flera filer (bl.a. `arende-27727c98...`), och flödeskörningen visar grönt både på triggern och mejlsteget:

  ![Flödeskörning lyckades](screenshots/flow-run-success.png)
  ![Blobbar i arenden-containern](screenshots/arenden-container-blobs.png)

Det bekräftar Delmoment 2: ett riktigt inskickat ärende landar som en ny blob i `arenden`, vilket triggar Power Automate-flödet automatiskt utan att jag behöver göra något manuellt.

## Delmoment 3 – Integrera mot Microsoft 365

Uppgift: låt flödet skapa en post i en SharePoint-lista som fungerar som Novatrix ärenderegister, och skicka en notis i Teams eller ett mejl i Outlook till kundtjänst.

Pågående. Kvar att göra: skapa SharePoint-listan `Novatrix ärenderegister`, lägga till **Get blob content** och **Parse JSON** i flödet för att läsa ut ärendets innehåll (namn, mail, meddelande), och byta ut test-mejlsteget mot ett riktigt **Create item** i listan plus en notis till kundtjänst.

## Delmoment 4 – Koppla ihop med Azure

Uppgift: knyt flödet till Azure-lösningen så att kedjan går hela vägen, från ett inskickat ärende i formuläret till en post i M365 och en notis till kundtjänst.

Klart på Azure-sidan: `vm-novatrix` kör en Flask-backend (`app.py`) som tar emot formuläret och sparar varje ärende som en JSON-fil i containern `arenden`, autentiserat med VM:ens system-assigned managed identity (rollen Storage Blob Data Contributor, scopead till containern) — ingen nyckel i koden. Det är den här uppladdningen som triggar flödet i Delmoment 2.

Kvar: koppla ihop resten av kedjan när Delmoment 3 är klart, så att ett inskickat ärende även syns i SharePoint och når kundtjänst.

## Delmoment 5 – Verifiera och dokumentera

Uppgift: visa hela kedjan från inskickat ärende till utförd åtgärd i Microsoft 365, och dokumentera flödets steg.

Görs när Delmoment 3–4 är helt klara.
