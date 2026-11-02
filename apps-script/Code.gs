/**
 * Miss B sheet writer. Bound to the audit spreadsheet and deployed as a web
 * app (execute as the owner, anyone may POST). The watch talks to Google
 * only. This script never calls Modal or any other host.
 *
 * The tab named TEMPLATE_TAB stays blank. A send copies that tab the first
 * time a date+shift is seen, then fills only the side that arrived. A resend
 * resets that side from the blank tab and fills it again, so the other side
 * stays put and the blank tab is never written.
 *
 * Deploy: Extensions → Apps Script, paste this file, set Script property
 * LISTENER_TOKEN, Deploy → New deployment → Web app. Put the /exec URL in
 * the watch's LISTENER_URL.
 */

var TEMPLATE_TAB = 'missb app automated input';
var COLS = 22;
var ROOM_COUNT = 26;

var WEST_ROOMS = [
  '301', '302', '303', '304', '305', '306A', '306Z', '307', '308',
  '309', '310', '311', '312', '313', '314', '315', '316', '317',
  '318', '319', '320', '321', '322', '323', '324A', '324Z'
];
var EAST_ROOMS = [
  '325A', '325Z', '326', '327', '328', '329', '330', '331', '332',
  '333', '334', '335', '336', '337', '338', '339', '340', '341',
  '342', '343A', '343Z', '344', '345', '346', '347', '348'
];

var COL = {
  room: 1, occ: 2, bed: 3, iso: 4, cdiff: 5, braden: 6, schmid: 7, bundle: 8,
  cl: 9, clDate: 10, na: 11, abx: 12, tpn: 13,
  fc: 14, cautiDate: 15, p: 16, r: 17, c: 18,
  restraints: 19, fr: 20, sitter: 21, bari: 22
};

var RED = '#ea9999';
var GRAY = '#d9d9d9';
var WHITE = '#ffffff';

function doGet() {
  return json_({ok: true});
}

function doPost(e) {
  try {
    var payload = JSON.parse((e.postData && e.postData.contents) || '{}');
    if (!tokenOk_(payload.token)) return json_({ok: false, error: 'unauthorized'});
    if (payload.side !== 'west' && payload.side !== 'east') {
      return json_({ok: false, error: 'side must be west or east'});
    }
    if (!payload.rooms || typeof payload.rooms !== 'object') {
      return json_({ok: false, error: 'rooms must be an object'});
    }
    var sheet = sheetFor_(payload);
    fillSide_(sheet, payload);
    return json_({ok: true, sheet: sheet.getName()});
  } catch (err) {
    return json_({ok: false, error: String(err.message || err)});
  }
}

function tokenOk_(presented) {
  var expected = PropertiesService.getScriptProperties().getProperty('LISTENER_TOKEN') || '';
  if (!expected || !presented || expected.length !== String(presented).length) return false;
  var mismatch = 0;
  presented = String(presented);
  for (var i = 0; i < expected.length; i++) {
    mismatch |= expected.charCodeAt(i) ^ presented.charCodeAt(i);
  }
  return mismatch === 0;
}

function sheetFor_(payload) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var template = ss.getSheetByName(TEMPLATE_TAB);
  if (!template) throw new Error('blank template tab is missing');
  var name = String(payload.date || '') + ' ' + String(payload.shift || '');
  name = name.replace(/[\\/?*[\]]/g, ' ').trim();
  if (!name) throw new Error('date and shift are required');
  var existing = ss.getSheetByName(name);
  if (existing) {
    if (existing.getSheetId() === template.getSheetId()) {
      throw new Error('refusing to write the blank template');
    }
    return existing;
  }
  var copy = template.copyTo(ss);
  copy.setName(name);
  ss.setActiveSheet(copy);
  ss.moveActiveSheet(template.getIndex() + 1);
  return copy;
}

function fillSide_(sheet, payload) {
  var ss = sheet.getParent();
  var template = ss.getSheetByName(TEMPLATE_TAB);
  if (sheet.getSheetId() === template.getSheetId()) {
    throw new Error('refusing to write the blank template');
  }
  var origin = payload.side === 'west' ? 1 : 32; // 1-based title row of the block
  // Reset this side's meta and room rows from the blank tab, then paint
  // answers. Headers and the other side stay as they are.
  var metaRow = origin + 1;
  var roomRow = origin + 4;
  template.getRange(metaRow, 1, 1, COLS).copyTo(sheet.getRange(metaRow, 1, 1, COLS));
  template.getRange(roomRow, 1, ROOM_COUNT, COLS).copyTo(sheet.getRange(roomRow, 1, ROOM_COUNT, COLS));

  writeMeta_(sheet, metaRow, payload);
  var rooms = payload.side === 'west' ? WEST_ROOMS : EAST_ROOMS;
  for (var i = 0; i < rooms.length; i++) {
    writeRoom_(sheet, roomRow + i, rooms[i], payload.rooms[rooms[i]] || null);
  }
}

function writeMeta_(sheet, row, payload) {
  var census = payload.starting_census;
  sheet.getRange(row, 1, 1, 11).setValues([[
    String(payload.side || '').toUpperCase(),
    'DATE',
    text_(payload.date),
    'SHIFT',
    text_(payload.shift),
    'ANM/RHC',
    text_(payload.anm_rhc),
    'CENSUS',
    (typeof census === 'number') ? census : '',
    'NURSE',
    text_(payload.nurse)
  ]]);
}

function writeRoom_(sheet, row, room, checks) {
  var values = blankRow_();
  var fills = blankFills_();
  var clearValidation = [];
  values[0] = room;
  if (checks) {
    putCheckbox_(values, fills, clearValidation, COL.occ, raw_(checks, 'occ'));
    putText_(values, fills, COL.bed, raw_(checks, 'bed_status'));
    putText_(values, fills, COL.iso, raw_(checks, 'iso'));
    putText_(values, fills, COL.cdiff, raw_(checks, 'cdiff'), cdiff_);
    putNumber_(values, fills, COL.braden, raw_(checks, 'braden'));
    putNumber_(values, fills, COL.schmid, raw_(checks, 'schmid'));
    putBundle_(values, fills, checks);
    putText_(values, fills, COL.cl, raw_(checks, 'clabsi_cl'));
    putText_(values, fills, COL.clDate, raw_(checks, 'clabsi_date'), shortDate_);
    putClabsiOptions_(values, fills, raw_(checks, 'clabsi_abx'), raw_(checks, 'clabsi_tpn'));
    putCheckbox_(values, fills, clearValidation, COL.fc, raw_(checks, 'cauti_fc'));
    putText_(values, fills, COL.cautiDate, raw_(checks, 'cauti_date'), shortDate_);
    putPrc_(values, fills, raw_(checks, 'cauti_prc'));
    putText_(values, fills, COL.restraints, raw_(checks, 'restraints'), joinChoices_);
    putCheckbox_(values, fills, clearValidation, COL.fr, raw_(checks, 'fr'));
    putCheckbox_(values, fills, clearValidation, COL.sitter, raw_(checks, 'sitter'));
    putCheckbox_(values, fills, clearValidation, COL.bari, raw_(checks, 'bariatric'));
  }
  var range = sheet.getRange(row, 1, 1, COLS);
  range.setValues([values]);
  range.setBackgrounds([fills]);
  for (var i = 0; i < clearValidation.length; i++) {
    sheet.getRange(row, clearValidation[i]).clearDataValidations();
  }
}

function putCheckbox_(values, fills, clearValidation, col, state) {
  var cell = checkboxCell_(state);
  values[col - 1] = cell.value;
  fills[col - 1] = cell.fill;
  if (cell.fill !== WHITE) clearValidation.push(col);
}

function putText_(values, fills, col, state, format) {
  var cell = textCell_(state, format);
  values[col - 1] = cell.value;
  fills[col - 1] = cell.fill;
}

function putNumber_(values, fills, col, state) {
  var cell = numberCell_(state);
  values[col - 1] = cell.value;
  fills[col - 1] = cell.fill;
}

function putBundle_(values, fills, checks) {
  var keys = ['bundle_door', 'bundle_rails', 'bundle_arm', 'bundle_socks', 'bundle_book'];
  var icons = ['🚪', '2️⃣', '💪', '🧦', '📕'];
  var states = keys.map(function (key) { return raw_(checks, key); });
  if (states.some(function (item) { return item.state === 'missing'; })) {
    values[COL.bundle - 1] = '';
    fills[COL.bundle - 1] = RED;
    return;
  }
  if (states.every(function (item) { return item.state === 'skipped'; })) {
    values[COL.bundle - 1] = 'N/A';
    fills[COL.bundle - 1] = GRAY;
    return;
  }
  var picked = [];
  for (var i = 0; i < states.length; i++) {
    if (states[i].state === 'answered' && states[i].value === true) picked.push(icons[i]);
  }
  values[COL.bundle - 1] = picked.join(' ');
  fills[COL.bundle - 1] = WHITE;
}

function putClabsiOptions_(values, fills, abx, tpn) {
  if (abx.cause === 'empty_room' || tpn.cause === 'empty_room') {
    [COL.na, COL.abx, COL.tpn].forEach(function (col) {
      values[col - 1] = 'N/A';
      fills[col - 1] = GRAY;
    });
    return;
  }
  if (abx.state === 'missing' || tpn.state === 'missing') {
    values[COL.na - 1] = '';
    fills[COL.na - 1] = RED;
  } else if (abx.state === 'skipped' && tpn.state === 'skipped') {
    values[COL.na - 1] = '✓';
    fills[COL.na - 1] = WHITE;
  } else {
    values[COL.na - 1] = '';
    fills[COL.na - 1] = WHITE;
  }
  putMark_(values, fills, COL.abx, abx);
  putMark_(values, fills, COL.tpn, tpn);
}

function putPrc_(values, fills, state) {
  var cols = [COL.p, COL.r, COL.c];
  var labels = ['P', 'R', 'C'];
  if (state.state === 'missing') {
    cols.forEach(function (col) { values[col - 1] = ''; fills[col - 1] = RED; });
    return;
  }
  if (state.state === 'skipped') {
    cols.forEach(function (col) { values[col - 1] = 'N/A'; fills[col - 1] = GRAY; });
    return;
  }
  for (var i = 0; i < cols.length; i++) {
    values[cols[i] - 1] = state.value === labels[i] ? '✓' : '';
    fills[cols[i] - 1] = WHITE;
  }
}

function putMark_(values, fills, col, state) {
  var cell = markCell_(state);
  values[col - 1] = cell.value;
  fills[col - 1] = cell.fill;
}

function checkboxCell_(state) {
  if (state.state === 'skipped') return {value: 'N/A', fill: GRAY};
  if (state.state === 'answered' && typeof state.value === 'boolean') return {value: state.value, fill: WHITE};
  return {value: '', fill: RED};
}

function markCell_(state) {
  if (state.state === 'missing') return {value: '', fill: RED};
  if (state.state === 'skipped') return {value: 'N/A', fill: GRAY};
  if (state.value === true) return {value: '✓', fill: WHITE};
  return {value: '', fill: WHITE};
}

function textCell_(state, format) {
  if (state.state === 'missing') return {value: '', fill: RED};
  if (state.state === 'skipped') return {value: 'N/A', fill: GRAY};
  var value = state.value;
  if (format) {
    try { value = format(value); } catch (err) { return {value: '', fill: RED}; }
  }
  if (typeof value === 'boolean' || value === null || value === undefined) return {value: '', fill: RED};
  return {value: value, fill: WHITE};
}

function numberCell_(state) {
  if (state.state === 'missing') return {value: '', fill: RED};
  if (state.state === 'skipped') return {value: 'N/A', fill: GRAY};
  if (typeof state.value !== 'number') return {value: '', fill: RED};
  return {value: state.value, fill: WHITE};
}

function raw_(checks, key) {
  var value = checks[key];
  if (value && (value.state === 'missing' || value.state === 'answered' || value.state === 'skipped')) return value;
  return {state: 'missing'};
}

function cdiff_(value) {
  return String(value) === 'R-O' ? 'R/O' : String(value);
}

function shortDate_(value) {
  var parsed = new Date(value);
  if (isNaN(parsed.getTime())) throw new Error('date');
  return Utilities.formatDate(parsed, 'America/Los_Angeles', 'M/d');
}

function joinChoices_(value) {
  if (Array.isArray(value)) return value.join(', ');
  if (typeof value === 'string') return value;
  throw new Error('choices');
}

function text_(value) {
  return value === null || value === undefined ? '' : String(value);
}

function blankRow_() {
  var row = [];
  for (var i = 0; i < COLS; i++) row.push('');
  return row;
}

function blankFills_() {
  var row = [];
  for (var i = 0; i < COLS; i++) row.push(WHITE);
  return row;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
