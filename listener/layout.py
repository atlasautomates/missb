"""Map a Miss B payload onto the version-5 audit grid.

The paper form (version 5) is the column contract:

- Google checkbox columns are the cells the form draws as checkboxes:
  OCC., F.C., FR, SITT., BARI.
- Bed status, C. diff, and the fall bundle are pick-one (or, for the bundle,
  several icons circled in one cell). Each is one column under its title.
  The option list sits in the subheader so the menu is visible; the room
  cell still holds only what the watch sent.
- CLABSI and CAUTI stay split. CLABSI runs CL, DATE, then NA sitting between
  the date and ABX/TPN. CAUTI runs F.C., DATE, then P, R, and C as their own
  subcolumns. Those option marks are not checkboxes on the form, so the sheet
  uses a check mark in the chosen column instead of a checkbox widget.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any
from zoneinfo import ZoneInfo

SPREADSHEET_ID = "1deoDnkmTk72Hl43irxqc5fX-pW_qOPWCF-AxLHRk96M"
TAB_SHEET_ID = 1966196459
TEMPLATE_TAB = "missb app automated input"

# Google sheet titles reject these. A shift label does not use them; the
# filter is so a stray character cannot make the copy fail.
_TAB_FORBIDDEN = set("\\/?*[]:")

WEST_ROOMS = [
    "301", "302", "303", "304", "305", "306A", "306Z", "307", "308",
    "309", "310", "311", "312", "313", "314", "315", "316", "317",
    "318", "319", "320", "321", "322", "323", "324A", "324Z",
]
EAST_ROOMS = [
    "325A", "325Z", "326", "327", "328", "329", "330", "331", "332",
    "333", "334", "335", "336", "337", "338", "339", "340", "341",
    "342", "343A", "343Z", "344", "345", "346", "347", "348",
]
ROOMS = {"west": WEST_ROOMS, "east": EAST_ROOMS}

# Payload keys. NA / P / R / C are sheet columns derived from these, not
# separate checks on the watch.
CHECK_KEYS = [
    "occ", "bed_status", "iso", "cdiff", "braden", "schmid",
    "bundle_door", "bundle_rails", "bundle_arm", "bundle_socks", "bundle_book",
    "clabsi_cl", "clabsi_date", "clabsi_abx", "clabsi_tpn",
    "cauti_fc", "cauti_date", "cauti_prc",
    "restraints", "fr", "sitter", "bariatric",
]

BUNDLE = (
    ("bundle_door", "🚪"),
    ("bundle_rails", "2️⃣"),
    ("bundle_arm", "💪"),
    ("bundle_socks", "🧦"),
    ("bundle_book", "📕"),
)

TITLE_ROW = 0
META_ROW = 1
HEADER_ROW = 2
SUB_ROW = 3
ROOM_START = 4
BLOCK_STRIDE = 31  # title, meta, two header rows, 26 rooms, one blank
PACIFIC = ZoneInfo("America/Los_Angeles")

# HTML checkbox columns only. Option subcolumns under CLABSI/CAUTI are marks.
CHECKBOX_HEADERS = ("OCC.", "F.C.", "FR", "SITT.", "BARI.")


@dataclass(frozen=True)
class Spec:
    key: str
    header: str
    group: str | None
    kind: str  # room | checkbox | text | mark
    # Menu shown under the title. Not written into room cells.
    legend: str | None = None
    width: int | None = None


SPECS: tuple[Spec, ...] = (
    Spec("room", "ROOM", None, "room"),
    Spec("occ", "OCC.", None, "checkbox"),
    Spec("bed_status", "BED STATUS", None, "text", "C   D   NB", 78),
    Spec("iso", "ISO", None, "text", "contact · droplet · airborne · enteric", 150),
    Spec("cdiff", "C. DIFF", None, "text", "+   R/O   IND", 96),
    Spec("braden", "BRADEN", None, "text"),
    Spec("schmid", "SCHMID", None, "text"),
    Spec("bundle", "BUNDLE", None, "text", "🚪  2️⃣  💪  🧦  📕  👗", 148),
    Spec("clabsi_cl", "CL", "CLABSI", "text", "PICC · internal jugular · subclavian · femoral", 130),
    Spec("clabsi_date", "DATE", "CLABSI", "text"),
    Spec("clabsi_na", "NA", "CLABSI", "mark"),
    Spec("clabsi_abx", "ABX", "CLABSI", "mark"),
    Spec("clabsi_tpn", "TPN", "CLABSI", "mark"),
    Spec("cauti_fc", "F.C.", "CAUTI", "checkbox"),
    Spec("cauti_date", "DATE", "CAUTI", "text"),
    Spec("cauti_p", "P", "CAUTI", "mark"),
    Spec("cauti_r", "R", "CAUTI", "mark"),
    Spec("cauti_c", "C", "CAUTI", "mark"),
    Spec("restraints", "RESTRAINTS", None, "text", "wrist straps · ankle straps · green blanket", 150),
    Spec("fr", "FR", None, "checkbox"),
    Spec("sitter", "SITT.", None, "checkbox"),
    Spec("bariatric", "BARI.", None, "checkbox"),
)


def column_index(key: str) -> int:
    for index, spec in enumerate(SPECS):
        if spec.key == key:
            return index
    raise KeyError(key)


@dataclass(frozen=True)
class Cell:
    value: Any = ""
    fill: str = "plain"  # plain | missing | na | header | title
    bold: bool = False


@dataclass
class Grid:
    cells: dict[tuple[int, int], Cell]
    merges: list[tuple[int, int, int, int]]
    checkbox_ranges: list[tuple[int, int, int, int]]
    checkbox_cells: list[tuple[int, int]]
    clears: list[tuple[int, int, int, int]]


def shift_tab_name(payload: dict) -> str:
    """Tab title for one shift: ``2026-10-05 10pm-6am``.

    The blank template keeps its own name and is never a write target.
    """
    date = payload.get("date")
    shift = payload.get("shift")
    if not isinstance(date, str) or not date.strip():
        raise ValueError("date and shift are required")
    if not isinstance(shift, str) or not shift.strip():
        raise ValueError("date and shift are required")
    name = "".join(" " if char in _TAB_FORBIDDEN else char for char in f"{date.strip()} {shift.strip()}")
    name = " ".join(name.split())
    if not name or name == TEMPLATE_TAB or len(name) > 100:
        raise ValueError("date and shift are required")
    return name


def choose_sheet(sheets: list[dict], tab: str, template_id: int = TAB_SHEET_ID) -> dict:
    """Use the date+shift tab, or copy the blank template just after itself.

    ``sheets`` entries need ``sheetId``, ``title``, and ``index``. The template
    id is never returned.
    """
    template = next((sheet for sheet in sheets if sheet.get("sheetId") == template_id), None)
    if template is None or not isinstance(template.get("index"), int):
        raise ValueError("blank template tab is missing")
    for sheet in sheets:
        if sheet.get("title") != tab:
            continue
        if sheet.get("sheetId") == template_id:
            raise ValueError("refusing to write the blank template")
        return {"action": "use", "sheetId": sheet["sheetId"]}
    return {"action": "duplicate", "insertIndex": template["index"] + 1}


def side_origin(side: str) -> int:
    if side == "west":
        return 0
    if side == "east":
        return BLOCK_STRIDE
    raise ValueError("side must be west or east")


def side_requests(side: str, payload: dict | None = None, sheet_id: int = TAB_SHEET_ID) -> list[dict]:
    """BatchUpdate requests for one side.

    `payload` None writes the empty form (headers, room numbers, checkbox
    columns). A payload fills that side in place and leaves the other side
    untouched.
    """
    if payload is not None and payload.get("side") != side:
        raise ValueError("side must be west or east")
    grid = _side_grid(side, payload)
    return _requests(grid, sheet_id)


def template_requests() -> list[dict]:
    return side_requests("west") + side_requests("east") + _legend_layout_requests()


def upsert_requests(payload: dict, sheet_id: int = TAB_SHEET_ID) -> list[dict]:
    side = payload.get("side")
    if side not in ROOMS:
        raise ValueError("side must be west or east")
    if not isinstance(payload.get("rooms"), dict):
        raise ValueError("rooms must be an object")
    other = "east" if side == "west" else "west"
    # A submit unmerges the whole tab first. Put the other side's header
    # merges back so that write does not flatten the side it did not touch.
    return side_requests(side, payload, sheet_id) + _merge_requests(other, sheet_id) + _legend_layout_requests(sheet_id)


def _side_grid(side: str, payload: dict | None) -> Grid:
    origin = side_origin(side)
    rooms = ROOMS[side]
    cells: dict[tuple[int, int], Cell] = {}
    merges: list[tuple[int, int, int, int]] = []

    cells[(origin + TITLE_ROW, 0)] = Cell("RHC Zero Harm Audit", "title", bold=True)
    _write_meta(cells, origin, side, payload)

    header = origin + HEADER_ROW
    sub = origin + SUB_ROW
    index = 0
    while index < len(SPECS):
        spec = SPECS[index]
        if spec.group is None:
            cells[(header, index)] = Cell(spec.header, "header", bold=True)
            if spec.legend:
                # Leave the subheader unmerged so the menu stays visible.
                cells[(sub, index)] = Cell(spec.legend, "header", bold=False)
            else:
                merges.append((header, index, header + 2, index + 1))
            index += 1
            continue
        group = spec.group
        end = index
        while end < len(SPECS) and SPECS[end].group == group:
            label = SPECS[end].header
            if SPECS[end].legend:
                label = f"{label}\n{SPECS[end].legend}"
            cells[(sub, end)] = Cell(label, "header", bold=True)
            end += 1
        merges.append((header, index, header + 1, end))
        cells[(header, index)] = Cell(group, "header", bold=True)
        index = end

    payload_rooms = (payload or {}).get("rooms") or {}
    for offset, room in enumerate(rooms):
        row = origin + ROOM_START + offset
        checks = payload_rooms.get(room)
        if payload is None or not isinstance(checks, dict):
            checks = None
        _write_room(cells, row, room, checks)

    # A blank form shows a checkbox in every room of those columns. Once a
    # side is filled, only answered yes/no cells keep the widget. A missing
    # cell stays a red blank: a column-wide checkbox turns that red into an
    # ordinary unchecked box, which reads as No.
    checkbox_ranges = []
    checkbox_cells: list[tuple[int, int]] = []
    if payload is None:
        for spec_index, spec in enumerate(SPECS):
            if spec.kind == "checkbox":
                checkbox_ranges.append((
                    origin + ROOM_START,
                    spec_index,
                    origin + ROOM_START + len(rooms),
                    spec_index + 1,
                ))
    else:
        for (row, col), cell in cells.items():
            if SPECS[col].kind == "checkbox" and isinstance(cell.value, bool):
                checkbox_cells.append((row, col))

    # Drop whatever this side held so a resubmit cannot leave a stale mark
    # in a column this write no longer fills. The other side is outside this range.
    # Existing merges are removed by the caller with their exact ranges.
    # A partial unmerge is rejected when a merge on the tab sticks out past it.
    clears = [(origin, 0, origin + ROOM_START + len(rooms), len(SPECS))]
    return Grid(cells, merges, checkbox_ranges, checkbox_cells, clears)


def _write_meta(cells: dict, origin: int, side: str, payload: dict | None) -> None:
    row = origin + META_ROW
    data = payload or {}
    census = data.get("starting_census")
    census_cell = Cell(census, "plain") if isinstance(census, int) else Cell("", "plain")
    pairs = (
        (0, Cell(side.upper(), "title", bold=True)),
        (1, Cell("DATE", "title", bold=True)),
        (2, Cell(_text(data.get("date")), "plain")),
        (3, Cell("SHIFT", "title", bold=True)),
        (4, Cell(_text(data.get("shift")), "plain")),
        (5, Cell("ANM/RHC", "title", bold=True)),
        (6, Cell(_text(data.get("anm_rhc")), "plain")),
        (7, Cell("CENSUS", "title", bold=True)),
        (8, census_cell),
        (9, Cell("NURSE", "title", bold=True)),
        (10, Cell(_text(data.get("nurse")), "plain")),
    )
    for col, cell in pairs:
        cells[(row, col)] = cell


def _write_room(cells: dict, row: int, room: str, checks: dict | None) -> None:
    cells[(row, column_index("room"))] = Cell(room, "plain", bold=True)
    if checks is None:
        return

    def raw(key: str) -> dict:
        value = checks.get(key)
        if isinstance(value, dict) and value.get("state") in {"missing", "answered", "skipped"}:
            return value
        return {"state": "missing"}

    cells[(row, column_index("occ"))] = _checkbox(raw("occ"))
    cells[(row, column_index("bed_status"))] = _text_answer(raw("bed_status"))
    cells[(row, column_index("iso"))] = _text_answer(raw("iso"))
    cells[(row, column_index("cdiff"))] = _text_answer(raw("cdiff"), _cdiff)
    cells[(row, column_index("braden"))] = _number_answer(raw("braden"))
    cells[(row, column_index("schmid"))] = _number_answer(raw("schmid"))
    cells[(row, column_index("bundle"))] = _bundle(checks)
    cells[(row, column_index("clabsi_cl"))] = _text_answer(raw("clabsi_cl"))
    cells[(row, column_index("clabsi_date"))] = _text_answer(raw("clabsi_date"), _short_date)
    _write_clabsi_options(cells, row, raw("clabsi_abx"), raw("clabsi_tpn"))
    cells[(row, column_index("cauti_fc"))] = _checkbox(raw("cauti_fc"))
    cells[(row, column_index("cauti_date"))] = _text_answer(raw("cauti_date"), _short_date)
    _write_prc(cells, row, raw("cauti_prc"))
    cells[(row, column_index("restraints"))] = _text_answer(raw("restraints"), _join_choices)
    cells[(row, column_index("fr"))] = _checkbox(raw("fr"))
    cells[(row, column_index("sitter"))] = _checkbox(raw("sitter"))
    cells[(row, column_index("bariatric"))] = _checkbox(raw("bariatric"))


def _write_clabsi_options(cells: dict, row: int, abx: dict, tpn: dict) -> None:
    """NA is the column between DATE and ABX/TPN. A check there means both
    line options were skipped on purpose. An empty room is N/A, not a chosen NA.
    """
    if abx.get("cause") == "empty_room" or tpn.get("cause") == "empty_room":
        for key in ("clabsi_na", "clabsi_abx", "clabsi_tpn"):
            cells[(row, column_index(key))] = Cell("N/A", "na")
        return
    if abx["state"] == "missing" or tpn["state"] == "missing":
        cells[(row, column_index("clabsi_na"))] = Cell("", "missing")
    elif abx["state"] == "skipped" and tpn["state"] == "skipped":
        cells[(row, column_index("clabsi_na"))] = Cell("✓", "plain")
    else:
        cells[(row, column_index("clabsi_na"))] = Cell("", "plain")
    cells[(row, column_index("clabsi_abx"))] = _mark(abx)
    cells[(row, column_index("clabsi_tpn"))] = _mark(tpn)


def _write_prc(cells: dict, row: int, state: dict) -> None:
    if state["state"] == "missing":
        for key in ("cauti_p", "cauti_r", "cauti_c"):
            cells[(row, column_index(key))] = Cell("", "missing")
        return
    if state["state"] == "skipped":
        for key in ("cauti_p", "cauti_r", "cauti_c"):
            cells[(row, column_index(key))] = Cell("N/A", "na")
        return
    picked = state.get("value")
    for key, label in (("cauti_p", "P"), ("cauti_r", "R"), ("cauti_c", "C")):
        cells[(row, column_index(key))] = Cell("✓" if picked == label else "", "plain")


def _bundle(checks: dict) -> Cell:
    states = []
    for key, _icon in BUNDLE:
        value = checks.get(key)
        if not isinstance(value, dict) or value.get("state") not in {"missing", "answered", "skipped"}:
            value = {"state": "missing"}
        states.append(value)
    if any(item["state"] == "missing" for item in states):
        return Cell("", "missing")
    if all(item["state"] == "skipped" for item in states):
        return Cell("N/A", "na")
    icons = [
        icon
        for (key, icon), item in zip(BUNDLE, states)
        if item["state"] == "answered" and item.get("value") is True
    ]
    return Cell(" ".join(icons), "plain")


def _checkbox(state: dict) -> Cell:
    if state["state"] == "missing":
        return Cell("", "missing")
    if state["state"] == "skipped":
        return Cell("N/A", "na")
    if state["state"] == "answered" and isinstance(state.get("value"), bool):
        return Cell(state["value"], "plain")
    return Cell("", "missing")


def _mark(state: dict) -> Cell:
    if state["state"] == "missing":
        return Cell("", "missing")
    if state["state"] == "skipped":
        return Cell("N/A", "na")
    if state.get("value") is True:
        return Cell("✓", "plain")
    return Cell("", "plain")


def _text_answer(state: dict, format_value=None) -> Cell:
    if state["state"] == "missing":
        return Cell("", "missing")
    if state["state"] == "skipped":
        return Cell("N/A", "na")
    value = state.get("value")
    if format_value is not None:
        try:
            value = format_value(value)
        except (TypeError, ValueError):
            return Cell("", "missing")
    if isinstance(value, bool) or value is None:
        return Cell("", "missing")
    return Cell(value, "plain")


def _number_answer(state: dict) -> Cell:
    if state["state"] == "missing":
        return Cell("", "missing")
    if state["state"] == "skipped":
        return Cell("N/A", "na")
    value = state.get("value")
    if isinstance(value, bool) or not isinstance(value, int):
        return Cell("", "missing")
    return Cell(value, "plain")


def _cdiff(value: Any) -> str:
    text = str(value)
    if text == "R-O":
        return "R/O"
    return text


def _short_date(value: Any) -> str:
    if not isinstance(value, str) or not value:
        raise ValueError("date")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    local = parsed.astimezone(PACIFIC)
    return f"{local.month}/{local.day}"


def _join_choices(value: Any) -> str:
    if isinstance(value, list):
        return ", ".join(str(item) for item in value)
    if isinstance(value, str):
        return value
    raise ValueError("choices")


def _text(value: Any) -> str:
    if value is None:
        return ""
    return str(value)


_FILLS = {
    "plain": {"red": 1, "green": 1, "blue": 1},
    "missing": {"red": 0.918, "green": 0.6, "blue": 0.6},
    "na": {"red": 0.851, "green": 0.851, "blue": 0.851},
    "header": {"red": 0.949, "green": 0.949, "blue": 0.949},
    "title": {"red": 1, "green": 1, "blue": 1},
}


def header_requests(sheet_id: int = TAB_SHEET_ID) -> list[dict]:
    """Titles, option menus, and header merges for both sides.

    Room rows are left alone, so a tab that already has charting keeps it.
    """
    requests: list[dict] = []
    for side in ("west", "east"):
        grid = _side_grid(side, None)
        origin = side_origin(side)
        rows: dict[int, dict[int, Cell]] = {}
        for (row, col), cell in grid.cells.items():
            if row in (origin + HEADER_ROW, origin + SUB_ROW):
                rows.setdefault(row, {})[col] = cell
        for row in sorted(rows):
            by_col = rows[row]
            start = min(by_col)
            end = max(by_col) + 1
            values = [_cell_data(by_col.get(col, Cell())) for col in range(start, end)]
            requests.append({
                "updateCells": {
                    "range": _range(row, start, row + 1, end, sheet_id),
                    "rows": [{"values": values}],
                    "fields": "userEnteredValue,userEnteredFormat",
                }
            })
        for start_row, start_col, end_row, end_col in grid.merges:
            requests.append({
                "mergeCells": {
                    "range": _range(start_row, start_col, end_row, end_col, sheet_id),
                    "mergeType": "MERGE_ALL",
                }
            })
    return requests + _legend_layout_requests(sheet_id)


def _legend_layout_requests(sheet_id: int = TAB_SHEET_ID) -> list[dict]:
    """Give the menu row room to wrap, and widen only the columns that have one."""
    requests: list[dict] = []
    for spec_index, spec in enumerate(SPECS):
        if spec.width is None:
            continue
        requests.append({
            "updateDimensionProperties": {
                "range": {
                    "sheetId": sheet_id,
                    "dimension": "COLUMNS",
                    "startIndex": spec_index,
                    "endIndex": spec_index + 1,
                },
                "properties": {"pixelSize": spec.width},
                "fields": "pixelSize",
            }
        })
    for origin in (0, BLOCK_STRIDE):
        sub = origin + SUB_ROW
        requests.append({
            "updateDimensionProperties": {
                "range": {
                    "sheetId": sheet_id,
                    "dimension": "ROWS",
                    "startIndex": sub,
                    "endIndex": sub + 1,
                },
                "properties": {"pixelSize": 52},
                "fields": "pixelSize",
            }
        })
    return requests


def _merge_requests(side: str, sheet_id: int = TAB_SHEET_ID) -> list[dict]:
    grid = _side_grid(side, None)
    requests = []
    for start_row, start_col, end_row, end_col in grid.merges:
        requests.append({
            "mergeCells": {
                "range": _range(start_row, start_col, end_row, end_col, sheet_id),
                "mergeType": "MERGE_ALL",
            }
        })
    return requests


def _requests(grid: Grid, sheet_id: int = TAB_SHEET_ID) -> list[dict]:
    requests: list[dict] = []
    for start_row, start_col, end_row, end_col in grid.clears:
        requests.append({
            "repeatCell": {
                "range": _range(start_row, start_col, end_row, end_col, sheet_id),
                "cell": {"dataValidation": None},
                "fields": "userEnteredValue,userEnteredFormat,dataValidation",
            }
        })

    if grid.clears:
        clear_start, _, clear_end, _ = grid.clears[0]
        # Room rows sit four below the side origin. repeatCell does not
        # remove checkbox rules; an empty CellData write does.
        room_start = clear_start + ROOM_START
        room_count = clear_end - room_start
        for index, spec in enumerate(SPECS):
            if spec.kind != "checkbox":
                continue
            requests.append({
                "updateCells": {
                    "range": _range(room_start, index, room_start + room_count, index + 1, sheet_id),
                    "rows": [{"values": [{}]} for _ in range(room_count)],
                    "fields": "dataValidation",
                }
            })

    rows: dict[int, dict[int, Cell]] = {}
    for (row, col), cell in grid.cells.items():
        rows.setdefault(row, {})[col] = cell
    for row in sorted(rows):
        by_col = rows[row]
        start = min(by_col)
        end = max(by_col) + 1
        values = [_cell_data(by_col.get(col, Cell())) for col in range(start, end)]
        requests.append({
            "updateCells": {
                "range": _range(row, start, row + 1, end, sheet_id),
                "rows": [{"values": values}],
                "fields": "userEnteredValue,userEnteredFormat",
            }
        })

    for start_row, start_col, end_row, end_col in grid.merges:
        requests.append({
            "mergeCells": {
                "range": _range(start_row, start_col, end_row, end_col, sheet_id),
                "mergeType": "MERGE_ALL",
            }
        })

    rule = {
        "condition": {"type": "BOOLEAN"},
        "strict": False,
        "showCustomUi": True,
    }
    for start_row, start_col, end_row, end_col in grid.checkbox_ranges:
        requests.append({
            "setDataValidation": {
                "range": _range(start_row, start_col, end_row, end_col, sheet_id),
                "rule": rule,
            }
        })
    for row, col in grid.checkbox_cells:
        requests.append({
            "setDataValidation": {
                "range": _range(row, col, row + 1, col + 1, sheet_id),
                "rule": rule,
            }
        })
    return requests


def _range(start_row: int, start_col: int, end_row: int, end_col: int, sheet_id: int = TAB_SHEET_ID) -> dict:
    return {
        "sheetId": sheet_id,
        "startRowIndex": start_row,
        "endRowIndex": end_row,
        "startColumnIndex": start_col,
        "endColumnIndex": end_col,
    }


def _cell_data(cell: Cell) -> dict:
    color = _FILLS[cell.fill]
    text_format: dict[str, Any] = {"bold": cell.bold}
    if cell.fill == "na":
        text_format["italic"] = True
        text_format["foregroundColor"] = {"red": 0.4, "green": 0.4, "blue": 0.4}
    return {
        "userEnteredValue": _entered(cell.value),
        "userEnteredFormat": {
            "backgroundColor": color,
            "horizontalAlignment": "CENTER",
            "verticalAlignment": "MIDDLE",
            "textFormat": text_format,
            "wrapStrategy": "WRAP" if cell.fill == "header" else "OVERFLOW_CELL",
        },
    }


def _entered(value: Any) -> dict:
    if isinstance(value, bool):
        return {"boolValue": value}
    if isinstance(value, int) and not isinstance(value, bool):
        return {"numberValue": value}
    if value is None:
        return {"stringValue": ""}
    return {"stringValue": str(value)}
