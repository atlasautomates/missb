"""Miss B listener. A send copies the blank tab the first time a shift is seen, then writes one side of that copy."""

from __future__ import annotations

import hmac
import os

import modal
from fastapi import HTTPException, Request

from layout import TAB_SHEET_ID, TEMPLATE_TAB, choose_sheet, header_requests, shift_tab_name, template_requests, upsert_requests
from sheets_io import (
    SheetWriteError,
    batch_update,
    duplicate_sheet,
    google_access_token,
    list_merges,
    list_sheets,
    read_values,
    unmerge_requests,
)

app = modal.App("missb-listener")

image = (
    modal.Image.debian_slim()
    .pip_install("fastapi[standard]", "google-auth")
    .add_local_python_source("layout", "sheets_io")
)


def _token_ok(presented: str) -> bool:
    expected = os.environ.get("LISTENER_TOKEN", "")
    if not expected or not presented:
        return False
    return hmac.compare_digest(presented, expected)


def _bearer(header: str) -> str:
    prefix = "Bearer "
    if not header.startswith(prefix):
        return ""
    return header[len(prefix):].strip()


@app.function(image=image)
@modal.fastapi_endpoint(method="GET")
def hello() -> dict:
    return {"ok": True}


@app.function(
    image=image,
    secrets=[
        modal.Secret.from_name("missb-google-sa"),
        modal.Secret.from_name("missb-listener-auth"),
    ],
    timeout=120,
)
@modal.fastapi_endpoint(method="POST")
async def submit(request: Request) -> dict:
    if not _token_ok(_bearer(request.headers.get("authorization", ""))):
        raise HTTPException(status_code=401, detail="unauthorized")
    try:
        payload = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=400, detail="invalid json") from exc
    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="invalid json")
    try:
        tab = shift_tab_name(payload)
        # Reject a bad payload before copying a tab.
        upsert_requests(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    try:
        token = google_access_token()
        choice = choose_sheet(list_sheets(token), tab)
        if choice["action"] == "use":
            target = choice["sheetId"]
        else:
            target = duplicate_sheet(token, tab, choice["insertIndex"])
        requests = upsert_requests(payload, target)
        batch_update(token, unmerge_requests(list_merges(token, target)) + requests)
    except SheetWriteError as exc:
        raise HTTPException(status_code=502, detail="sheet update failed") from exc
    except ValueError as exc:
        raise HTTPException(status_code=502, detail="sheet update failed") from exc
    return {"ok": True, "side": payload.get("side"), "sheet": tab}


@app.function(
    image=image,
    secrets=[modal.Secret.from_name("missb-google-sa")],
    timeout=120,
)
def apply_template() -> dict:
    token = google_access_token()
    batch_update(token, unmerge_requests(list_merges(token)) + template_requests())
    return {"ok": True, "headers": read_values(token, "A3:V4")}


def _charting_tab(title: object) -> bool:
    """A duplicated audit tab or a date+shift tab. Not Sheet1 and its siblings."""
    if not isinstance(title, str) or title == TEMPLATE_TAB:
        return False
    if title.startswith("Copy of "):
        return True
    day, _, _rest = title.partition(" ")
    return len(day) == 10 and day[4] == "-" and day[7] == "-"


@app.function(
    image=image,
    secrets=[modal.Secret.from_name("missb-google-sa")],
    timeout=120,
)
def refresh_headers() -> dict:
    """Show the option menus on tabs that already hold charting."""
    token = google_access_token()
    titles = []
    for sheet in list_sheets(token):
        sheet_id = sheet.get("sheetId")
        if not isinstance(sheet_id, int) or not _charting_tab(sheet.get("title")):
            continue
        batch_update(token, unmerge_requests(list_merges(token, sheet_id)) + header_requests(sheet_id))
        titles.append(sheet.get("title"))
    return {"ok": True, "tabs": titles}


@app.local_entrypoint()
def apply() -> None:
    print(apply_template.remote())
    print(refresh_headers.remote())
