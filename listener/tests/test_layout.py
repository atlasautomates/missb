"""Column contract for the version-5 form, and how one payload lands."""

from __future__ import annotations

import unittest

from layout import (
    BLOCK_STRIDE,
    CHECKBOX_HEADERS,
    SPECS,
    TAB_SHEET_ID,
    choose_sheet,
    column_index,
    shift_tab_name,
    side_origin,
    side_requests,
    upsert_requests,
)


def answered(value):
    return {"state": "answered", "value": value}


def missing():
    return {"state": "missing"}


def skipped(cause="manual"):
    return {"state": "skipped", "cause": cause}


def checks(**overrides):
    base = {key: missing() for key in (
        "occ", "bed_status", "iso", "cdiff", "braden", "schmid",
        "bundle_door", "bundle_rails", "bundle_arm", "bundle_socks", "bundle_book",
        "clabsi_cl", "clabsi_date", "clabsi_abx", "clabsi_tpn",
        "cauti_fc", "cauti_date", "cauti_prc",
        "restraints", "fr", "sitter", "bariatric",
    )}
    base.update(overrides)
    return base


def payload(side="west", room="301", room_checks=None, **header):
    body = {
        "side": side,
        "shift": header.get("shift", "10pm-6am"),
        "nurse": header.get("nurse", "Atlas"),
        "anm_rhc": header.get("anm_rhc", "SB"),
        "date": header.get("date", "2026-10-05"),
        "starting_census": header.get("starting_census", 20),
        "rooms": {},
    }
    if room_checks is not None:
        body["rooms"][room] = room_checks
    return body


def cell_map(requests):
    found = {}
    for request in requests:
        update = request.get("updateCells")
        if not update or not update.get("rows"):
            continue
        grid = update["range"]
        row = grid["startRowIndex"]
        col = grid["startColumnIndex"]
        for value in update["rows"][0]["values"]:
            found[(row, col)] = value
            col += 1
    return found


def shown(entry):
    value = entry["userEnteredValue"]
    if "boolValue" in value:
        return value["boolValue"]
    if "numberValue" in value:
        return value["numberValue"]
    return value.get("stringValue", "")


def fill(entry):
    color = entry["userEnteredFormat"]["backgroundColor"]
    return (round(color["red"], 3), round(color["green"], 3), round(color["blue"], 3))


RED = (0.918, 0.6, 0.6)
GRAY = (0.851, 0.851, 0.851)


class ColumnContract(unittest.TestCase):
    def test_checkbox_columns_are_only_the_form_checkboxes(self):
        kinds = {spec.header: spec.kind for spec in SPECS}
        for header in CHECKBOX_HEADERS:
            self.assertEqual(kinds[header], "checkbox", header)
        self.assertEqual(
            [spec.header for spec in SPECS if spec.kind == "checkbox"],
            ["OCC.", "F.C.", "FR", "SITT.", "BARI."],
        )

    def test_pick_one_groups_are_a_single_column(self):
        headers = [spec.header for spec in SPECS]
        self.assertEqual(headers.count("BED STATUS"), 1)
        self.assertEqual(headers.count("C. DIFF"), 1)
        self.assertEqual(headers.count("BUNDLE"), 1)
        self.assertNotIn("C", [spec.header for spec in SPECS if spec.group is None])
        for spec in SPECS:
            if spec.key in {"bed_status", "cdiff", "bundle"}:
                self.assertIsNone(spec.group)

    def test_clabsi_subcolumns_include_date_then_na_before_the_other_options(self):
        clabsi = [spec.header for spec in SPECS if spec.group == "CLABSI"]
        self.assertEqual(clabsi, ["CL", "DATE", "NA", "ABX", "TPN"])

    def test_cauti_subcolumns_include_date_then_each_option(self):
        cauti = [spec.header for spec in SPECS if spec.group == "CAUTI"]
        self.assertEqual(cauti, ["F.C.", "DATE", "P", "R", "C"])

    def test_group_headers_span_their_subcolumns_and_pick_one_headers_do_not(self):
        requests = side_requests("west")
        merges = [item["mergeCells"]["range"] for item in requests if "mergeCells" in item]
        clabsi = column_index("clabsi_cl")
        cauti = column_index("cauti_fc")
        self.assertIn(
            {"sheetId": 1966196459, "startRowIndex": 2, "endRowIndex": 3,
             "startColumnIndex": clabsi, "endColumnIndex": clabsi + 5},
            merges,
        )
        self.assertIn(
            {"sheetId": 1966196459, "startRowIndex": 2, "endRowIndex": 3,
             "startColumnIndex": cauti, "endColumnIndex": cauti + 5},
            merges,
        )
        bed = column_index("bed_status")
        self.assertNotIn(
            {"sheetId": 1966196459, "startRowIndex": 2, "endRowIndex": 4,
             "startColumnIndex": bed, "endColumnIndex": bed + 1},
            merges,
        )
        room = column_index("room")
        self.assertIn(
            {"sheetId": 1966196459, "startRowIndex": 2, "endRowIndex": 4,
             "startColumnIndex": room, "endColumnIndex": room + 1},
            merges,
        )

    def test_checkbox_validation_covers_form_checkboxes_only(self):
        requests = side_requests("west")
        rules = [
            item["setDataValidation"]
            for item in requests
            if item.get("setDataValidation", {}).get("rule")
        ]
        columns = sorted(rule["range"]["startColumnIndex"] for rule in rules)
        self.assertEqual(columns, [
            column_index("occ"),
            column_index("cauti_fc"),
            column_index("fr"),
            column_index("sitter"),
            column_index("bariatric"),
        ])
        for rule in rules:
            self.assertEqual(rule["rule"]["condition"]["type"], "BOOLEAN")
            self.assertTrue(rule["rule"]["showCustomUi"])
            self.assertFalse(rule["rule"]["strict"])


class PayloadLanding(unittest.TestCase):
    def test_empty_room_unchecks_occ_and_marks_the_rest_na(self):
        room = checks(occ=answered(False))
        for key in room:
            if key != "occ":
                room[key] = skipped("empty_room")
        cells = cell_map(upsert_requests(payload(room_checks=room)))
        row = side_origin("west") + 4
        occ = cells[(row, column_index("occ"))]
        self.assertIs(shown(occ), False)
        braden = cells[(row, column_index("braden"))]
        self.assertEqual(shown(braden), "N/A")
        self.assertEqual(fill(braden), GRAY)
        self.assertEqual(shown(cells[(row, column_index("clabsi_na"))]), "N/A")

    def test_missing_check_is_red_and_blank(self):
        cells = cell_map(upsert_requests(payload(room_checks=checks(occ=answered(True)))))
        row = side_origin("west") + 4
        braden = cells[(row, column_index("braden"))]
        self.assertEqual(shown(braden), "")
        self.assertEqual(fill(braden), RED)

    def test_pick_one_values_land_in_the_single_column(self):
        room = checks(
            occ=answered(True),
            bed_status=answered("C"),
            cdiff=answered("R-O"),
            bundle_door=answered(True),
            bundle_rails=answered(False),
            bundle_arm=answered(True),
            bundle_socks=answered(False),
            bundle_book=answered(True),
        )
        cells = cell_map(upsert_requests(payload(room_checks=room)))
        row = side_origin("west") + 4
        self.assertEqual(shown(cells[(row, column_index("bed_status"))]), "C")
        self.assertEqual(shown(cells[(row, column_index("cdiff"))]), "R/O")
        self.assertEqual(shown(cells[(row, column_index("bundle"))]), "🚪 💪 📕")
        sub = side_origin("west") + 3
        self.assertEqual(shown(cells[(sub, column_index("bed_status"))]), "C   D   NB")
        self.assertEqual(shown(cells[(sub, column_index("cdiff"))]), "+   R/O   IND")
        self.assertEqual(shown(cells[(sub, column_index("bundle"))]), "🚪  2️⃣  💪  🧦  📕  👗")
        self.assertIn("contact", shown(cells[(sub, column_index("iso"))]))
        self.assertIn("green blanket", shown(cells[(sub, column_index("restraints"))]))
        self.assertIn("PICC", shown(cells[(sub, column_index("clabsi_cl"))]))
        self.assertTrue(shown(cells[(sub, column_index("clabsi_cl"))]).startswith("CL"))

    def test_clabsi_na_sits_between_date_and_the_line_options(self):
        self.assertLess(column_index("clabsi_date"), column_index("clabsi_na"))
        self.assertLess(column_index("clabsi_na"), column_index("clabsi_abx"))
        room = checks(
            occ=answered(True),
            clabsi_abx=skipped("manual"),
            clabsi_tpn=skipped("manual"),
        )
        cells = cell_map(upsert_requests(payload(room_checks=room)))
        row = side_origin("west") + 4
        self.assertEqual(shown(cells[(row, column_index("clabsi_na"))]), "✓")
        self.assertEqual(shown(cells[(row, column_index("clabsi_abx"))]), "N/A")
        self.assertEqual(shown(cells[(row, column_index("clabsi_tpn"))]), "N/A")

    def test_abx_and_tpn_mark_independently(self):
        room = checks(
            occ=answered(True),
            clabsi_abx=answered(True),
            clabsi_tpn=answered(False),
            clabsi_date=answered("2026-10-04T19:00:00Z"),
        )
        cells = cell_map(upsert_requests(payload(room_checks=room)))
        row = side_origin("west") + 4
        self.assertEqual(shown(cells[(row, column_index("clabsi_date"))]), "10/4")
        self.assertEqual(shown(cells[(row, column_index("clabsi_na"))]), "")
        self.assertEqual(shown(cells[(row, column_index("clabsi_abx"))]), "✓")
        self.assertEqual(shown(cells[(row, column_index("clabsi_tpn"))]), "")

    def test_no_foley_unchecks_fc_and_marks_the_tail_na(self):
        room = checks(
            occ=answered(True),
            cauti_fc=answered(False),
            cauti_date=skipped("no_foley"),
            cauti_prc=skipped("no_foley"),
        )
        cells = cell_map(upsert_requests(payload(room_checks=room)))
        row = side_origin("west") + 4
        self.assertIs(shown(cells[(row, column_index("cauti_fc"))]), False)
        self.assertEqual(shown(cells[(row, column_index("cauti_date"))]), "N/A")
        self.assertEqual(shown(cells[(row, column_index("cauti_p"))]), "N/A")
        self.assertEqual(shown(cells[(row, column_index("cauti_r"))]), "N/A")
        self.assertEqual(shown(cells[(row, column_index("cauti_c"))]), "N/A")

    def test_prc_marks_only_the_picked_subcolumn(self):
        room = checks(occ=answered(True), cauti_fc=answered(True), cauti_prc=answered("R"))
        cells = cell_map(upsert_requests(payload(room_checks=room)))
        row = side_origin("west") + 4
        self.assertEqual(shown(cells[(row, column_index("cauti_p"))]), "")
        self.assertEqual(shown(cells[(row, column_index("cauti_r"))]), "✓")
        self.assertEqual(shown(cells[(row, column_index("cauti_c"))]), "")

    def test_form_checkboxes_store_booleans(self):
        room = checks(
            occ=answered(True),
            fr=answered(True),
            sitter=answered(False),
            bariatric=answered(True),
        )
        cells = cell_map(upsert_requests(payload(room_checks=room)))
        row = side_origin("west") + 4
        self.assertIs(shown(cells[(row, column_index("occ"))]), True)
        self.assertIs(shown(cells[(row, column_index("fr"))]), True)
        self.assertIs(shown(cells[(row, column_index("sitter"))]), False)
        self.assertIs(shown(cells[(row, column_index("bariatric"))]), True)

    def test_east_and_a_resubmit_hit_the_same_rows(self):
        room = checks(occ=answered(True), braden=answered(18))
        first = cell_map(upsert_requests(payload("east", "325A", room)))
        second = cell_map(upsert_requests(payload("east", "325A", room, nurse="Cecil")))
        row = side_origin("east") + 4
        self.assertEqual(row, BLOCK_STRIDE + 4)
        self.assertEqual(shown(first[(row, 0)]), "325A")
        self.assertEqual(shown(first[(row, column_index("braden"))]), 18)
        self.assertEqual(
            first[(row, column_index("braden"))]["userEnteredValue"],
            second[(row, column_index("braden"))]["userEnteredValue"],
        )
        meta = side_origin("east") + 1
        self.assertEqual(shown(second[(meta, 10)]), "Cecil")
        self.assertLess(side_origin("west") + 4 + 26, side_origin("east"))

    def test_a_side_write_clears_only_that_side(self):
        requests = upsert_requests(payload())
        clears = [
            item["repeatCell"]["range"]
            for item in requests
            if "repeatCell" in item
        ]
        self.assertEqual(len(clears), 1)
        west_end = side_origin("west") + 4 + 26
        self.assertEqual(clears[0]["startRowIndex"], side_origin("west"))
        self.assertEqual(clears[0]["endRowIndex"], west_end)
        self.assertLess(clears[0]["endRowIndex"], side_origin("east"))

    def test_a_gap_in_a_checkbox_column_is_not_given_a_checkbox(self):
        requests = upsert_requests(payload(room_checks=checks(
            occ=answered(True),
            fr=answered(False),
        )))
        row = side_origin("west") + 4
        rules = [
            item["setDataValidation"]["range"]
            for item in requests
            if item.get("setDataValidation", {}).get("rule")
        ]
        self.assertIn(
            {"sheetId": 1966196459, "startRowIndex": row, "endRowIndex": row + 1,
             "startColumnIndex": column_index("occ"), "endColumnIndex": column_index("occ") + 1},
            rules,
        )
        self.assertIn(
            {"sheetId": 1966196459, "startRowIndex": row, "endRowIndex": row + 1,
             "startColumnIndex": column_index("fr"), "endColumnIndex": column_index("fr") + 1},
            rules,
        )
        self.assertNotIn(
            {"sheetId": 1966196459, "startRowIndex": row, "endRowIndex": row + 1,
             "startColumnIndex": column_index("sitter"), "endColumnIndex": column_index("sitter") + 1},
            rules,
        )

    def test_rejects_a_bad_side(self):
        with self.assertRaises(ValueError):
            upsert_requests({"side": "north", "rooms": {}})

    def test_shift_tab_name_uses_the_date_and_window(self):
        self.assertEqual(shift_tab_name(payload()), "2026-10-05 10pm-6am")
        morning = payload()
        morning["date"] = "2026-10-06"
        morning["shift"] = "6am-2pm"
        self.assertEqual(shift_tab_name(morning), "2026-10-06 6am-2pm")

    def test_shift_tab_name_rejects_a_blank_date(self):
        body = payload()
        body["date"] = "  "
        with self.assertRaises(ValueError):
            shift_tab_name(body)

    def test_a_new_shift_copies_the_template_and_an_existing_one_is_reused(self):
        sheets = [
            {"sheetId": TAB_SHEET_ID, "title": "missb app automated input", "index": 0},
            {"sheetId": 5, "title": "2026-10-05 6am-2pm", "index": 1},
        ]
        self.assertEqual(
            choose_sheet(sheets, "2026-10-05 10pm-6am"),
            {"action": "duplicate", "insertIndex": 1},
        )
        self.assertEqual(
            choose_sheet(sheets, "2026-10-05 6am-2pm"),
            {"action": "use", "sheetId": 5},
        )

    def test_choose_sheet_never_returns_the_blank_template(self):
        sheets = [{"sheetId": TAB_SHEET_ID, "title": "missb app automated input", "index": 0}]
        with self.assertRaises(ValueError):
            choose_sheet(sheets, "missb app automated input")
        with self.assertRaises(ValueError):
            choose_sheet([], "2026-10-05 10pm-6am")

    def test_a_shift_write_targets_the_copied_tab(self):
        requests = upsert_requests(payload(), sheet_id=42)
        ids = set()
        for item in requests:
            for key in ("repeatCell", "updateCells", "mergeCells", "setDataValidation", "updateDimensionProperties"):
                if key in item:
                    ids.add(item[key]["range"]["sheetId"])
        self.assertEqual(ids, {42})


if __name__ == "__main__":
    unittest.main()
