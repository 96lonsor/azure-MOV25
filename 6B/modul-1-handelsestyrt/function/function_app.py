import json
import logging
import os
import urllib.request
from datetime import datetime, timezone

import azure.functions as func
from azure.core.exceptions import ResourceExistsError
from azure.data.tables import TableClient, UpdateMode
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobClient

app = func.FunctionApp()

credential = DefaultAzureCredential()
tabell = TableClient(
    endpoint=os.environ["TABLE_ENDPOINT"],
    table_name=os.environ["TABLE_NAME"],
    credential=credential,
)


def las_arende(blob_url):
    # Bloben läses med funktionens hanterade identitet, ingen nyckel behövs.
    blob = BlobClient.from_blob_url(blob_url, credential=credential)
    return json.loads(blob.download_blob().readall())


def skicka_till_logic_app(arende):
    # LOGICAPP_URL är en Key Vault-referens som plattformen redan har löst upp.
    req = urllib.request.Request(
        os.environ["LOGICAPP_URL"],
        data=json.dumps(arende, ensure_ascii=False).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as svar:
        return svar.status


@app.function_name(name="HanteraArende")
@app.event_grid_trigger(arg_name="event")
def hantera_arende(event: func.EventGridEvent):
    data = event.get_json()
    blob_url = data["url"]
    logging.info("Nytt ärende från Event Grid: %s (händelse %s)", blob_url, event.id)

    arende = las_arende(blob_url)
    arende_id = arende["arendeId"]

    # Raden i registret skapas först. Finns den redan har händelsen kommit förut,
    # och då ska kunden inte få ett mejl till (Event Grid levererar minst en gång).
    try:
        tabell.create_entity({
            "PartitionKey": "arende",
            "RowKey": arende_id,
            "Namn": arende.get("namn", ""),
            "Epost": arende.get("epost", ""),
            "Meddelande": arende.get("meddelande", ""),
            "Inskickat": arende.get("tidpunkt", ""),
            "Blob": blob_url,
            "Notifierad": False,
        })
    except ResourceExistsError:
        befintlig = tabell.get_entity("arende", arende_id)
        if befintlig.get("Notifierad"):
            logging.info("Ärende %s är redan hanterat, hoppar över.", arende_id)
            return

    # Misslyckas anropet kastas ett fel, så att Event Grid försöker igen.
    status = skicka_till_logic_app(arende)
    logging.info("Logic App svarade %s för ärende %s", status, arende_id)

    tabell.update_entity(
        {
            "PartitionKey": "arende",
            "RowKey": arende_id,
            "Notifierad": True,
            "NotifieradTid": datetime.now(timezone.utc).isoformat(),
        },
        mode=UpdateMode.MERGE,
    )
