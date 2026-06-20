# MPRAmpController HTTP API

Reference for clients (e.g. an iOS app) consuming the `MPRAmpController` server, which
controls a Monoprice 6-zone amplifier over RS-232.

- **Base URL:** `http://<host>:8001` (the server binds `0.0.0.0:8001`). On the reference
  setup that's `http://Spencers-Mac-mini.local:8001` or the mini's LAN IP.
- **Content type:** all responses are JSON (`application/json`) except `GET /` (the HTML web UI).
- **No authentication.** Intended for a trusted LAN.

## Conventions

- **Zone IDs are `11`–`16`** — amplifier unit 1, zones 1–6. (The 1's digit is the zone; the
  10's digit is the amp unit. Only one amp is supported today.)
- **Source/input numbers are `1`–`6`**.
- **Every numeric field in a `Zone` response is a zero-padded two-character _string_** (e.g.
  `"05"`, `"38"`), not a number. A value of **`"-1"` means "unknown / not yet read"** — it
  appears for fields the server hasn't observed yet (e.g. other fields right after a single
  attribute write). Do a `GET` to populate a full zone.
- **`Preset` values are JSON integers** (not the zero-padded strings used by `Zone`). Watch this
  asymmetry when decoding.
- Request `value` path segments are plain integers (e.g. `/zones/11/vo/15`); the server validates
  the range and zero-pads before sending to the amp.

## Data models

### Zone

```json
{
  "zone": "11",
  "pa":   "00",
  "pr":   "01",
  "mu":   "00",
  "dt":   "00",
  "vo":   "12",
  "tr":   "07",
  "bs":   "07",
  "bl":   "10",
  "ch":   "03",
  "name": "Kitchen"
}
```

| Key | Meaning | Range | Notes |
| --- | --- | --- | --- |
| `zone` | Zone ID | `11`–`16` | string |
| `pa` | PA mode | `0`–`1` | |
| `pr` | Power | `0`–`1` | |
| `mu` | Mute | `0`–`1` | |
| `dt` | Do not disturb | `0`–`1` | |
| `vo` | Volume | `0`–`38` | |
| `tr` | Treble | `0`–`14` | `7` = flat |
| `bs` | Bass | `0`–`14` | `7` = flat |
| `bl` | Balance | `0`–`20` | `10` = center |
| `ch` | Source/input | `1`–`6` | |
| `name` | Friendly zone name | — | defaults to the zone ID string (e.g. `"11"`) until set |

All numeric values are zero-padded 2-char strings; `"-1"` = unknown.

### Preset

```json
{
  "id": "60E602E0-AA36-4507-948B-BCB271969644",
  "name": "Movie Night",
  "zones": [
    { "zone": 11, "power": 1, "source": 3, "volume": 20 },
    { "zone": 12, "power": 0, "source": 1, "volume": 5 }
  ]
}
```

| Key | Type | Notes |
| --- | --- | --- |
| `id` | string (UUID) | |
| `name` | string | |
| `zones` | array | one entry per zone captured |
| `zones[].zone` | int | `11`–`16` |
| `zones[].power` | int | `0`–`1` |
| `zones[].source` | int | `1`–`6` |
| `zones[].volume` | int | `0`–`38` |

A preset snapshots only **power, source, and volume** per zone. Applying it pushes those three
to each listed zone.

### Source

```json
{ "id": 3, "name": "Apple TV" }
```

| Key | Type | Notes |
| --- | --- | --- |
| `id` | int | `1`–`6` |
| `name` | string | defaults to `"Source N"` until renamed |

## Endpoints

### Zones

#### `GET /zones`
All six zones. Reads live state from the amp.
- **200** → `[Zone]` (6 elements)

#### `GET /zones/:zoneid`
One zone (`:zoneid` is `11`–`16`).
- **200** → `Zone`
- **412** if `:zoneid` isn't an integer · **404** if the zone isn't found

#### `POST /zones/:zoneid/:attribute/:value`
Set one attribute on one zone.
- `:attribute` is an amp code: `pr`, `mu`, `dt`, `pa`, `vo`, `tr`, `bs`, `bl`, `ch`, or `name`.
- `:value` is an integer in the attribute's range (see the Zone table), **or** any string when
  `:attribute` is `name`.
- **200** → `Zone` (the updated zone; for non-`name` writes, unobserved fields may be `"-1"`)
- **400** if the value is out of range · **412** if the attribute/params are invalid
- **502** if the amp doesn't echo a usable result · **500** on serial timeout / no device

Examples: `POST /zones/11/vo/15` · `POST /zones/11/pr/1` · `POST /zones/11/ch/3` ·
`POST /zones/11/name/Kitchen`

#### `POST /zones/all/:attribute/:value`
Set one attribute on **every** zone (sequential writes).
- Same `:attribute`/`:value` rules, except `name` is not allowed.
- **200** → `[Zone]` · **400** out of range · **412** invalid attribute (incl. `name`)

### Presets

#### `GET /presets`
- **200** → `[Preset]`

#### `POST /presets?name=NAME`
Snapshot the current state of all zones as a new preset. `NAME` is a required query parameter.
- **200** → `Preset` (the created preset)
- **400** if `name` is missing/empty

#### `POST /presets/:presetid/apply`
Apply a preset — pushes power, source, and volume to each of its zones.
- **200** → `[Zone]` (all zones after applying)
- **412** if `:presetid` isn't a UUID · **404** if not found

#### `DELETE /presets/:presetid`
- **204** No Content · **412** invalid UUID · **404** if not found

### Sources

#### `GET /sources`
- **200** → `[Source]` (6 elements, ids `1`–`6`, defaults filled in)

#### `POST /sources/:sourceid/:name`
Rename an input (`:sourceid` is `1`–`6`). URL-encode names with spaces (`Apple%20TV`).
- **200** → `Source` · **412** if the id is out of range or the name is missing

### Web UI

#### `GET /`
- **200** → `text/html` — a built-in control panel (zone power/source/volume, presets, source
  names). Not needed by an API client.

## Errors

Errors are returned with the noted HTTP status and Vapor's standard JSON error body:

```json
{ "error": true, "reason": "15 is out of range for vo" }
```

| Status | When |
| --- | --- |
| 400 | attribute value out of range |
| 404 | zone/preset not found |
| 412 | malformed path parameter (non-integer id, unknown attribute, missing value) |
| 502 | amplifier returned no usable echo for a write |
| 500 | serial timeout (~5s) or no serial device connected |

## Notes for client implementers

- **Latency:** every request round-trips the serial port. Single zone reads/writes are typically
  tens of milliseconds; `GET /zones`, `POST /zones/all/...`, and `POST /presets/:id/apply` issue
  several serial commands and take longer (hundreds of ms to a couple of seconds). Use generous
  request timeouts (≥ 10s).
- **Decode `Zone` numbers from strings**, and treat `"-1"` as "unknown". `Preset` numbers are
  already integers.
- After a single-attribute `POST`, re-`GET` the zone if you need a fully-populated object.
- The server processes serial requests one at a time; concurrent client requests are serialized.
