"""Nordvik hyresgästportal - felanmälan.

Inloggningen sköts av Container Apps inbyggda autentisering (Entra ID). Appen
får användaren i headern X-MS-CLIENT-PRINCIPAL och läser ut vilka grupper hen
är med i. Grupperna styr vad man får göra:

    grp-nordvik-hyresgaster  -> skapa och se sina egna felanmälningar
    grp-nordvik-forvaltare   -> se alla, se bilder, ändra status, ladda upp dokument
    grp-nordvik-ekonomi      -> läsa sammanställningar och dokument, inga personuppgifter

Lagringen nås med den hanterade identiteten id-nordvik-portal, inga nycklar.
"""

import base64
import json
import os
import time
import urllib.error
import urllib.request
import uuid
from collections import Counter
from datetime import datetime, timezone
from functools import wraps
from zoneinfo import ZoneInfo

from azure.core.exceptions import ResourceNotFoundError
from azure.data.tables import TableClient, UpdateMode
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings
from flask import Flask, Response, abort, g, redirect, render_template, request, url_for

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 12 * 1024 * 1024  # bild max 10 MB + formulärfälten

STORAGE_ACCOUNT = os.environ.get("STORAGE_ACCOUNT", "")
BILD_CONTAINER = os.environ.get("BILD_CONTAINER", "felanmalningar")
DOKUMENT_CONTAINER = os.environ.get("DOKUMENT_CONTAINER", "dokument")
TABELL = os.environ.get("TABELL", "felanmalningar")
FLOW_URL = os.environ.get("FLOW_URL", "")
PORTAL_URL = os.environ.get("PORTAL_URL", "").rstrip("/")
MILJO = os.environ.get("MILJO", "prod")

GRUPPER = {
    "hyresgast": os.environ.get("GRUPP_HYRESGAST", ""),
    "forvaltare": os.environ.get("GRUPP_FORVALTARE", ""),
    "ekonomi": os.environ.get("GRUPP_EKONOMI", ""),
}

FASTIGHETER = [f.strip() for f in os.environ.get(
    "FASTIGHETER", "Björkhagen 1,Ekbacken 3,Granliden 7,Strandvägen 12").split(",") if f.strip()]
KATEGORIER = ["Värme", "Vatten och avlopp", "Lås och dörr", "El", "Vitvaror", "Ventilation", "Övrigt"]
AKUTA = {"Värme", "Vatten och avlopp", "Lås och dörr"}
STATUSAR = ["Ny", "Pågår", "Åtgärdad"]

MAX_BILD = 10 * 1024 * 1024
# Kollar filens första bytes i stället för att lita på filändelsen
BILDTYPER = {
    "jpg": ("image/jpeg", lambda b: b[:3] == b"\xff\xd8\xff"),
    "png": ("image/png", lambda b: b[:8] == b"\x89PNG\r\n\x1a\n"),
    "webp": ("image/webp", lambda b: b[:4] == b"RIFF" and b[8:12] == b"WEBP"),
    "heic": ("image/heic", lambda b: b[4:12] in (b"ftypheic", b"ftypheix", b"ftypmif1")),
}

_credential = None
_blob = None
_tabell = None


def blob_service():
    global _credential, _blob
    if _blob is None:
        _credential = _credential or DefaultAzureCredential()
        _blob = BlobServiceClient(f"https://{STORAGE_ACCOUNT}.blob.core.windows.net", credential=_credential)
    return _blob


def tabell():
    global _credential, _tabell
    if _tabell is None:
        _credential = _credential or DefaultAzureCredential()
        _tabell = TableClient(f"https://{STORAGE_ACCOUNT}.table.core.windows.net",
                              table_name=TABELL, credential=_credential)
    return _tabell


# --- Inloggad användare -------------------------------------------------------

def las_principal():
    """Läser användaren som Easy Auth skickar med. Saknas headern är man inte inloggad."""
    rad = request.headers.get("X-MS-CLIENT-PRINCIPAL")
    if not rad:
        return None
    data = json.loads(base64.b64decode(rad))
    claims = {}
    grupper = set()
    for c in data.get("claims", []):
        if c["typ"] == "groups":
            grupper.add(c["val"])
        else:
            claims.setdefault(c["typ"], c["val"])
    oid = claims.get("http://schemas.microsoft.com/identity/claims/objectidentifier") or claims.get("oid")
    roller = {roll for roll, grupp_id in GRUPPER.items() if grupp_id and grupp_id in grupper}
    return {
        "oid": oid,
        "namn": claims.get("name", ""),
        "epost": claims.get("preferred_username", ""),
        "roller": roller,
    }


@app.before_request
def kontrollera():
    if request.endpoint in ("health", "static"):
        return
    # Enkel CSRF-spärr: POST måste komma från portalen själv
    if request.method == "POST":
        origin = request.headers.get("Origin")
        if origin and origin.split("://", 1)[-1] != request.host:
            abort(403)
    g.anv = las_principal()
    if g.anv is None or not g.anv["oid"]:
        abort(401)


@app.after_request
def sakerhetsheaders(resp):
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["Referrer-Policy"] = "same-origin"
    resp.headers["Content-Security-Policy"] = (
        "default-src 'self'; img-src 'self'; style-src 'self'; frame-ancestors 'none'; form-action 'self'")
    return resp


def kraver(*roller):
    def dekorator(f):
        @wraps(f)
        def inner(*args, **kwargs):
            if not g.anv["roller"] & set(roller):
                abort(403)
            return f(*args, **kwargs)
        return inner
    return dekorator


@app.template_filter("lokaltid")
def lokaltid(iso):
    # Tiden sparas i UTC men visas i svensk tid
    try:
        return datetime.fromisoformat(iso).astimezone(ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d %H:%M")
    except (TypeError, ValueError):
        return iso


@app.context_processor
def mallvariabler():
    anv = getattr(g, "anv", None)
    personal = bool(anv and anv["roller"] & {"forvaltare", "ekonomi"})
    return {"anv": anv, "personal": personal, "miljo": MILJO}


# --- Felanmälan ---------------------------------------------------------------

@app.get("/")
def start():
    roller = g.anv["roller"]
    if "forvaltare" in roller:
        return redirect(url_for("forvaltare"))
    if "ekonomi" in roller:
        return redirect(url_for("ekonomi"))
    if "hyresgast" in roller:
        return redirect(url_for("mina"))
    abort(403)


@app.get("/mina")
@kraver("hyresgast")
def mina():
    # PartitionKey är hyresgästens objekt-id, så frågan kan bara ge egna anmälningar
    rader = tabell().query_entities("PartitionKey eq @oid", parameters={"oid": g.anv["oid"]})
    anmalningar = sorted(rader, key=lambda r: r["Skapad"], reverse=True)
    return render_template("mina.html", anmalningar=anmalningar, ny=request.args.get("ny"),
                           notis=request.args.get("notis") == "1")


@app.get("/ny")
@kraver("hyresgast")
def ny():
    return render_template("ny.html", fastigheter=FASTIGHETER, kategorier=KATEGORIER, fel=None, varden={})


@app.post("/ny")
@kraver("hyresgast")
def skapa():
    f = request.form
    varden = {k: f.get(k, "").strip() for k in ("fastighet", "lagenhet", "kategori", "rubrik", "beskrivning")}
    fel = None
    if varden["fastighet"] not in FASTIGHETER or varden["kategori"] not in KATEGORIER:
        fel = "Välj fastighet och kategori."
    elif not varden["rubrik"] or not varden["beskrivning"]:
        fel = "Rubrik och beskrivning måste fyllas i."
    elif len(varden["rubrik"]) > 120 or len(varden["beskrivning"]) > 4000:
        fel = "Rubriken får vara max 120 tecken och beskrivningen max 4000."

    bild_data, bild_typ, bild_ext = None, None, None
    fil = request.files.get("bild")
    if not fel and fil and fil.filename:
        bild_data = fil.read(MAX_BILD + 1)
        if len(bild_data) > MAX_BILD:
            fel = "Bilden är för stor, max 10 MB."
        else:
            for ext, (typ, kontroll) in BILDTYPER.items():
                if kontroll(bild_data):
                    bild_typ, bild_ext = typ, ext
                    break
            else:
                fel = "Bilden måste vara JPG, PNG, WebP eller HEIC."
    if fel:
        return render_template("ny.html", fastigheter=FASTIGHETER, kategorier=KATEGORIER,
                               fel=fel, varden=varden), 400

    anmalan_id = datetime.now(timezone.utc).strftime("%y%m%d") + "-" + uuid.uuid4().hex[:6]
    bild_namn = ""
    if bild_data:
        # Bilden läggs i en egen mapp per anmälan. Containern är privat.
        bild_namn = f"{anmalan_id}/bild.{bild_ext}"
        blob_service().get_blob_client(BILD_CONTAINER, bild_namn).upload_blob(
            bild_data, overwrite=False,
            content_settings=ContentSettings(content_type=bild_typ),
            metadata={"anmalanid": anmalan_id})

    post = {
        "PartitionKey": g.anv["oid"],
        "RowKey": anmalan_id,
        "Fastighet": varden["fastighet"],
        "Lagenhet": varden["lagenhet"],
        "Kategori": varden["kategori"],
        "Akut": varden["kategori"] in AKUTA,
        "Rubrik": varden["rubrik"],
        "Beskrivning": varden["beskrivning"],
        "Bild": bild_namn,
        "Hyresgast": g.anv["namn"],
        "HyresgastEpost": g.anv["epost"],
        "TilltradeMedHuvudnyckel": f.get("tilltrade") == "ja",
        "Status": "Ny",
        "Skapad": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "Notifierad": False,
    }
    tabell().create_entity(post)
    skickad = notifiera(post)
    return redirect(url_for("mina", ny=anmalan_id, notis=int(skickad)))


def notifiera(post):
    """Skickar anmälan till Power Automate. Anmälan är redan sparad, så om flödet
    inte svarar ligger den kvar som 'ej notifierad' och kan skickas om av förvaltaren."""
    if not FLOW_URL:
        return False
    payload = {
        "anmalanId": post["RowKey"],
        "fastighet": post["Fastighet"],
        "lagenhet": post["Lagenhet"],
        "kategori": post["Kategori"],
        "akut": post["Akut"],
        "rubrik": post["Rubrik"],
        "beskrivning": post["Beskrivning"],
        "harBild": bool(post["Bild"]),
        "hyresgast": post["Hyresgast"],
        "tilltrade": post["TilltradeMedHuvudnyckel"],
        "skapad": post["Skapad"],
        "lank": f"{PORTAL_URL}/anmalan/{post['RowKey']}",
    }
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    for forsok in range(3):
        try:
            req = urllib.request.Request(FLOW_URL, data=data, method="POST",
                                         headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=8)
            tabell().update_entity({"PartitionKey": post["PartitionKey"], "RowKey": post["RowKey"],
                                    "Notifierad": True}, mode=UpdateMode.MERGE)
            return True
        except urllib.error.HTTPError as e:
            # 4xx (utom 429) blir inte bättre av att försöka igen
            if e.code < 500 and e.code != 429:
                app.logger.warning("Flödet svarade %s för %s", e.code, post["RowKey"])
                return False
        except Exception as e:
            app.logger.warning("Kunde inte nå flödet (%s): %s", forsok + 1, e)
        time.sleep(2 ** forsok)
    return False


def hamta_anmalan(anmalan_id):
    """Hyresgäster slår upp i sin egen partition, förvaltare söker i hela tabellen."""
    if "forvaltare" in g.anv["roller"]:
        rader = list(tabell().query_entities("RowKey eq @id", parameters={"id": anmalan_id}))
        if rader:
            return rader[0]
    elif "hyresgast" in g.anv["roller"]:
        try:
            return tabell().get_entity(g.anv["oid"], anmalan_id)
        except ResourceNotFoundError:
            pass
    abort(404)


@app.get("/anmalan/<anmalan_id>")
@kraver("hyresgast", "forvaltare")
def visa(anmalan_id):
    return render_template("anmalan.html", a=hamta_anmalan(anmalan_id), statusar=STATUSAR)


@app.get("/anmalan/<anmalan_id>/bild")
@kraver("hyresgast", "forvaltare")
def bild(anmalan_id):
    a = hamta_anmalan(anmalan_id)
    if not a.get("Bild"):
        abort(404)
    nedladdning = blob_service().get_blob_client(BILD_CONTAINER, a["Bild"]).download_blob()
    return Response(nedladdning.readall(), mimetype=nedladdning.properties.content_settings.content_type,
                    headers={"Cache-Control": "private, max-age=300"})


@app.post("/anmalan/<anmalan_id>/status")
@kraver("forvaltare")
def andra_status(anmalan_id):
    a = hamta_anmalan(anmalan_id)
    status = request.form.get("status")
    if status not in STATUSAR:
        abort(400)
    tabell().update_entity({"PartitionKey": a["PartitionKey"], "RowKey": a["RowKey"], "Status": status,
                            "Hanterad": g.anv["namn"],
                            "Uppdaterad": datetime.now(timezone.utc).isoformat(timespec="seconds")},
                           mode=UpdateMode.MERGE)
    return redirect(url_for("visa", anmalan_id=anmalan_id))


@app.post("/anmalan/<anmalan_id>/notifiera")
@kraver("forvaltare")
def notifiera_igen(anmalan_id):
    notifiera(hamta_anmalan(anmalan_id))
    return redirect(url_for("visa", anmalan_id=anmalan_id))


@app.get("/forvaltare")
@kraver("forvaltare")
def forvaltare():
    status = request.args.get("status", "")
    fastighet = request.args.get("fastighet", "")
    rader = list(tabell().list_entities())
    if status:
        rader = [r for r in rader if r["Status"] == status]
    if fastighet:
        rader = [r for r in rader if r["Fastighet"] == fastighet]
    rader.sort(key=lambda r: (r["Status"] == "Åtgärdad", not r["Akut"], r["Skapad"]), reverse=False)
    return render_template("forvaltare.html", anmalningar=rader, statusar=STATUSAR,
                           fastigheter=FASTIGHETER, status=status, fastighet=fastighet)


@app.get("/ekonomi")
@kraver("ekonomi", "forvaltare")
def ekonomi():
    # Ekonomi behöver volymer, inte vem som anmält vad. Bara de här kolumnerna hämtas.
    rader = list(tabell().list_entities(select=["Fastighet", "Kategori", "Status", "Akut", "Skapad"]))
    per_fastighet = Counter(r["Fastighet"] for r in rader)
    per_kategori = Counter(r["Kategori"] for r in rader)
    per_status = Counter(r["Status"] for r in rader)
    per_manad = Counter(r["Skapad"][:7] for r in rader)
    return render_template("ekonomi.html", totalt=len(rader), akuta=sum(1 for r in rader if r["Akut"]),
                           per_fastighet=sorted(per_fastighet.items()), per_kategori=per_kategori.most_common(),
                           per_status=per_status, per_manad=sorted(per_manad.items()))


# --- Dokument (kontrakt och besiktningsprotokoll) ----------------------------

@app.get("/dokument")
@kraver("forvaltare", "ekonomi")
def dokument():
    container = blob_service().get_container_client(DOKUMENT_CONTAINER)
    filer = [{"namn": b.name, "storlek": b.size, "andrad": b.last_modified, "niva": b.blob_tier}
             for b in container.list_blobs()]
    return render_template("dokument.html", filer=filer, fastigheter=FASTIGHETER, fel=request.args.get("fel"))


@app.post("/dokument")
@kraver("forvaltare")
def ladda_upp_dokument():
    fil = request.files.get("fil")
    fastighet = request.form.get("fastighet", "")
    if not fil or not fil.filename or fastighet not in FASTIGHETER:
        return redirect(url_for("dokument", fel="Välj fastighet och en fil."))
    data = fil.read()
    if data[:5] != b"%PDF-":
        return redirect(url_for("dokument", fel="Bara PDF-filer tas emot."))
    namn = os.path.basename(fil.filename).replace(" ", "_")
    blob_service().get_blob_client(DOKUMENT_CONTAINER, f"{fastighet}/{namn}").upload_blob(
        data, overwrite=True, content_settings=ContentSettings(content_type="application/pdf"),
        metadata={"uppladdadav": g.anv["epost"].encode("ascii", "ignore").decode()})
    return redirect(url_for("dokument"))


@app.get("/dokument/<path:namn>")
@kraver("forvaltare", "ekonomi")
def hamta_dokument(namn):
    try:
        nedladdning = blob_service().get_blob_client(DOKUMENT_CONTAINER, namn).download_blob()
    except ResourceNotFoundError:
        abort(404)
    return Response(nedladdning.readall(), mimetype="application/pdf",
                    headers={"Content-Disposition": f'inline; filename="{os.path.basename(namn)}"'})


# --- Övrigt -------------------------------------------------------------------

@app.get("/health")
def health():
    # Används av Container Apps probes. Undantagen från inloggningen.
    return {"status": "ok", "miljo": MILJO, "storage": STORAGE_ACCOUNT, "flow_configured": bool(FLOW_URL)}


@app.errorhandler(401)
def ej_inloggad(e):
    return redirect("/.auth/login/aad?post_login_redirect_uri=/")


@app.errorhandler(403)
def nekad(e):
    return render_template("fel.html", rubrik="Ingen behörighet",
                           text="Ditt konto har inte behörighet till den här sidan."), 403


@app.errorhandler(404)
def saknas(e):
    return render_template("fel.html", rubrik="Hittades inte", text="Sidan eller anmälan finns inte."), 404


@app.errorhandler(413)
def for_stor(e):
    return render_template("fel.html", rubrik="För stor fil", text="Bilden får vara max 10 MB."), 413


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8000, debug=True)
