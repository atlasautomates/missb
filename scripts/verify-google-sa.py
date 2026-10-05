#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "google-auth",
# ]
# ///
"""Read the Miss B audit spreadsheet as the Google service account.

The key comes from a JSON file path, or from the GOOGLE_SA_JSON environment
variable (the name Modal secret missb-google-sa injects into the listener).
A path argument wins when both are set.

Exit 0 only when the tab "missb app automated input" is visible and its
sheet id is 1966196459. The call is a single Sheets metadata GET. It does
not write to the spreadsheet.

    uv run --with google-auth scripts/verify-google-sa.py ~/Downloads/key.json
    uv run --with google-auth scripts/verify-google-sa.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

SPREADSHEET_ID = "1deoDnkmTk72Hl43irxqc5fX-pW_qOPWCF-AxLHRk96M"
TAB_TITLE = "missb app automated input"
TAB_SHEET_ID = 1966196459
READONLY_SCOPE = "https://www.googleapis.com/auth/spreadsheets.readonly"
SHEETS_URL = (
    "https://sheets.googleapis.com/v4/spreadsheets/"
    f"{SPREADSHEET_ID}?fields=sheets.properties(title,sheetId)"
)


def load_service_account_info(path: str | None) -> dict:
    """Load a service-account key dict from a file or from GOOGLE_SA_JSON."""
    if path:
        with open(path, encoding="utf-8") as handle:
            raw = handle.read()
        source = path
    else:
        raw = os.environ.get("GOOGLE_SA_JSON", "")
        source = "GOOGLE_SA_JSON"
        if not raw.strip():
            raise SystemExit(
                "FAIL: pass the JSON key path, or set GOOGLE_SA_JSON "
                "(Modal secret missb-google-sa provides that variable)."
            )
    try:
        info = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"FAIL: {source} is not valid JSON ({exc})") from exc
    if not isinstance(info, dict) or info.get("type") != "service_account":
        raise SystemExit(f"FAIL: {source} is not a Google service-account key.")
    email = info.get("client_email")
    private_key = info.get("private_key")
    if not isinstance(email, str) or not email:
        raise SystemExit(f"FAIL: {source} is missing client_email.")
    if not isinstance(private_key, str) or not private_key:
        raise SystemExit(f"FAIL: {source} is missing private_key.")
    return info


def mint_access_token(info: dict) -> str:
    """Exchange the service-account key for a Sheets read token."""
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account
    except ImportError as exc:
        raise SystemExit(
            "FAIL: google-auth is not installed. Run: "
            "uv run --with google-auth scripts/verify-google-sa.py"
        ) from exc
    try:
        creds = service_account.Credentials.from_service_account_info(
            info, scopes=[READONLY_SCOPE]
        )
    except Exception as exc:
        raise SystemExit(
            f"FAIL: could not load the service account key "
            f"({info.get('client_email')}): {exc}"
        ) from exc
    try:
        creds.refresh(Request())
    except Exception as exc:
        raise SystemExit(
            f"FAIL: could not mint an access token for {info.get('client_email')}: {exc}"
        ) from exc
    token = creds.token
    if not isinstance(token, str) or not token:
        raise SystemExit("FAIL: token endpoint returned no access token.")
    return token


def fetch_tabs(token: str) -> list[dict]:
    """Return sheet properties (title, sheetId) for the audit spreadsheet."""
    request = urllib.request.Request(
        SHEETS_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        if len(body) > 2000:
            body = body[:2000] + "..."
        raise SystemExit(f"FAIL: Sheets API HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"FAIL: could not reach the Sheets API: {exc.reason}") from exc
    sheets = payload.get("sheets") if isinstance(payload, dict) else None
    if not isinstance(sheets, list):
        raise SystemExit("FAIL: Sheets API response had no sheets list.")
    tabs: list[dict] = []
    for sheet in sheets:
        props = sheet.get("properties") if isinstance(sheet, dict) else None
        if isinstance(props, dict):
            tabs.append(props)
    return tabs


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Read the Miss B audit spreadsheet as the Google service account "
            "and confirm the automated-input tab."
        ),
        epilog=(
            "Examples:\n"
            "  uv run --with google-auth scripts/verify-google-sa.py "
            "~/Downloads/key.json\n"
            "  uv run --with google-auth scripts/verify-google-sa.py\n"
            "    reads GOOGLE_SA_JSON, as injected by Modal secret missb-google-sa"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "key_path",
        nargs="?",
        help="Path to the service-account JSON key. Overrides GOOGLE_SA_JSON.",
    )
    args = parser.parse_args(argv)
    info = load_service_account_info(args.key_path)
    email = info["client_email"]
    token = mint_access_token(info)
    tabs = fetch_tabs(token)
    match = next((tab for tab in tabs if tab.get("title") == TAB_TITLE), None)
    if match is None:
        titles = [tab.get("title") for tab in tabs]
        print(
            f"FAIL: tab {TAB_TITLE!r} not found for {email}. Tabs seen: {titles}",
            file=sys.stderr,
        )
        return 1
    try:
        sheet_id = int(match["sheetId"])
    except (KeyError, TypeError, ValueError):
        print(
            f"FAIL: tab {TAB_TITLE!r} did not include a sheetId.",
            file=sys.stderr,
        )
        return 1
    if sheet_id != TAB_SHEET_ID:
        print(
            f"FAIL: tab {TAB_TITLE!r} has sheetId {sheet_id}, expected {TAB_SHEET_ID}.",
            file=sys.stderr,
        )
        return 1
    print(f"OK: {email} read tab {TAB_TITLE!r} (sheetId {TAB_SHEET_ID})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
