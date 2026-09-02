Del 1 - Identiteter - Skapa användare och grupper via Entra ID i Azure

Steg 1:  söker på Entra ID i Azure 

Steg 2: Skapa användare (drift och utveckling). 
drift-anna@96lonsorgmail.onmicrosoft.com 
Lösenord: Cassian2026

utveckling-erik@96lonsorgmail.onmicrosoft.com 
Lösenord: Cassian2026



Steg 3: Skapa grupper 



Steg 3 - Verifiera identiteterna (gissa aldrig att det blev rätt) 
Kontroll 1 - syns båda användarna under Användare? 
Kontroll 2- Finns båda grupperna under Grupper? 
Kontroll 3 - Har varje grupp rätt medlem? öppna en grupp och titta på medlemmar och bekräfta. 

Del 2: RBAC och Behörigheter (Roller, Scope och least privilege i praktiken) 
Role assignment = vem + vad + var En role assignment är själva kopplingen i RBAC och består av tre delar:
Vem — vilken identitet (t.ex. en grupp)
Vad — vilken roll den får (t.ex. Contributor)
Var — på vilken nivå/scope (t.ex. en specifik resursgrupp)
Exempel: gruppen drift får rollen Contributor på rg-novatrix. Allt i RBAC bygger i grunden på den här typen av tre-i-ett-koppling.
Arv i scope Behörigheter ärvs nedåt i hierarkin (prenumeration → resursgrupp → resurs):
En roll tilldelad på prenumerationen gäller i alla dess resursgrupper
En roll tilldelad på en resursgrupp gäller för allt som ligger inuti den
En ärvd behörighet går inte att "ta bort" på en lägre nivå — den måste hanteras där den tilldelades
Slutsats: tilldela alltid så lågt (smalt) i hierarkin som möjligt från början, eftersom ärvda behörigheter är den vanligaste orsaken till att någon får för mycket åtkomst.
Novatrix behörighetsmodell 
Drift: gruppen drift får rollen Contributor på rg-novatrix
Utveckling: gruppen utveckling får rollen Reader på rg-novatrix (i vissa versioner: "Utveckling tittar", dvs. bara läsbehörighet)
Ingen får Owner — den rollen behåller administratören
Scope: behörigheterna sätts på resursgruppen, inte på hela prenumerationen
Motivering: drift bygger och sköter servern, utveckling bara tittar/övervakar — därför skiljda roller och rättigheter

Steg 1: Översikt av vad vi ska tilldela
Mål: drift får Contributor, utveckling får Reader
Scope: resursgruppen rg-novatrix
Steg 1: öppna resursgruppen
Steg 2: gå till Åtkomstkontroll (IAM)
Steg 3: lägg till rolltilldelningar för respektive grupp
Steg 4: verifiera att en begränsad roll verkligen är begränsad

Steg 2: tilldela Reader till utveckling och Contributor till Drift
Steg 1: Lägg till rolltilldelning igen
Steg 2: välj rollen Reader
Steg 3: flik Medlemmar, välj gruppen utveckling
Steg 4: Granska + tilldela
Steg 5: nu har utveckling insyn men kan inte ändra
Två tilldelningar, och hela modellen är på plats.



