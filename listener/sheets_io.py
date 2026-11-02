"""Google Sheets batchUpdate. The layout module decides the cells; this only posts them."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from urllib.parse import quote

from layout import SPREADSHEET_ID, TAB_SHEET_ID, TEMPLATE_TAB

SHEETS_SCOPE = "https://www.googleapis.com/auth/spreadsheets"


class SheetWriteError(Exception):
    def __init__(self, status: int, detail: str = ""):
        self.status = status
        self.detail = detail
        message = f"sheet update failed ({status})"
        if detail:
            message = f"{message}: {detail}"
        super().__init__(message)


def google_access_token() -> str:
    raw = os.environ.get("GOOGLE_SA_JSON", "")
    if not raw.strip():
        raise SheetWriteError(500)
    info = json.loads(raw)
    from google.auth.transport.requests import Request
    from google.oauth2 import service_account

    creds = service_account.Credentials.from_service_account_info(info, scopes=[SHEETS_SCOPE])
    creds.refresh(Request())
    if not creds.token:
        raise SheetWriteError(500)
    return creds.token


def list_merges(token: str, sheet_id: int = TAB_SHEET_ID) -> list[dict]:
    """Every merge on one tab, so a rewrite can unmerge each one whole."""
    url = (
        "https://sheets.googleapis.com/v4/spreadsheets/"
        f"{SPREADSHEET_ID}?fields=sheets(properties(sheetId),merges)"
    )
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:1500]
        raise SheetWriteError(exc.code, detail) from exc
    for sheet in body.get("sheets", []):
        props = sheet.get("properties") or {}
        if props.get("sheetId") == sheet_id:
            return list(sheet.get("merges") or [])
    raise SheetWriteError(404, "audit tab missing")


def list_sheets(token: str) -> list[dict]:
    """Titles and ids in this spreadsheet. Used to find a shift's tab."""
    url = (
        "https://sheets.googleapis.com/v4/spreadsheets/"
        f"{SPREADSHEET_ID}?fields=sheets(properties(sheetId,title,index))"
    )
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:1500]
        raise SheetWriteError(exc.code, detail) from exc
    found = []
    for sheet in body.get("sheets", []):
        props = sheet.get("properties") or {}
        found.append({
            "sheetId": props.get("sheetId"),
            "title": props.get("title"),
            "index": props.get("index"),
        })
    return found


def duplicate_sheet(token: str, title: str, insert_index: int, source_id: int = TAB_SHEET_ID) -> int:
    """Copy the blank template. The caller writes the copy, never the source."""
    reply = batch_update(token, [{
        "duplicateSheet": {
            "sourceSheetId": source_id,
            "insertSheetIndex": insert_index,
            "newSheetName": title,
        }
    }])
    try:
        return int(reply["replies"][0]["duplicateSheet"]["properties"]["sheetId"])
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise SheetWriteError(502, "duplicate failed") from exc


def unmerge_requests(merges: list[dict]) -> list[dict]:
    return [{"unmergeCells": {"range": merge}} for merge in merges]


def batch_update(token: str, requests: list[dict]) -> dict:
    url = f"https://sheets.googleapis.com/v4/spreadsheets/{SPREADSHEET_ID}:batchUpdate"
    body = json.dumps({"requests": requests}).encode()
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:1500]
        raise SheetWriteError(exc.code, detail) from exc


def read_values(token: str, a1: str) -> list:
    """Read a range from the audit tab. Used to confirm a template write."""
    target = quote(f"'{TEMPLATE_TAB}'!{a1}", safe="")
    url = (
        "https://sheets.googleapis.com/v4/spreadsheets/"
        f"{SPREADSHEET_ID}/values/{target}"
    )
    request = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = json.load(response)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:1500]
        raise SheetWriteError(exc.code, detail) from exc
    return body.get("values", [])
