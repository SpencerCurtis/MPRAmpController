# MPRAmpController

`MPRAmpController` is a [Vapor](https://vapor.codes) web server that controls the [Monoprice "6 Zone Home Audio Multizone Controller and Amplifier Kit"](https://www.monoprice.com/product?p_id=10761). In theory it should also work for the [Dayton Audio DAX66](https://www.daytonaudio.com/product/1252/dax66-6-source-6-zone-distributed-audio-system) __but that has not been tested__.

Control is done over the amplifier's RS-232 port using a Mac and a serial-to-USB cable. I'm using [this one](https://www.amazon.com/dp/B00QUZY4UG/ref=cm_sw_em_r_mt_dp_U_xJQaFbN6SVJ4M).

Serial I/O uses [ORSSerialPort](https://github.com/armadsen/ORSSerialPort), which is unavailable on Linux, so this is a **Mac-only** Vapor application. My earlier, Linux-compatible implementation using [SwiftSerial](https://github.com/yeokm1/SwiftSerial) lives in [this repository](https://github.com/SpencerCurtis/MPRAmpController-SwiftSerial) if you want something that might run on a Raspberry Pi.

## Requirements

- A Mac with the serial-to-USB cable connected to the amplifier's RS-232 port.
- The first serial port whose name contains `usbserial` is used automatically.
- The server listens on `0.0.0.0:8001`.

## Building and running

```bash
swift run Run        # build and start the server
swift test           # run the unit tests
```

## HTTP API

**Building a client? See [API.md](API.md)** for the complete reference — every endpoint, the
JSON shapes of `Zone`/`Preset`/`Source`, value ranges, and status codes.

Zones are addressed `11`–`16` (amplifier unit 1, zones 1–6).

| Method | Path | Description |
| --- | --- | --- |
| `GET` | `/zones` | Status of all six zones |
| `GET` | `/zones/:id` | Status of one zone |
| `POST` | `/zones/:id/:attribute/:value` | Set an attribute on a zone |
| `POST` | `/zones/all/:attribute/:value` | Set an attribute on every zone |
| `GET` | `/presets` | List saved presets |
| `POST` | `/presets?name=NAME` | Save the current zone state as a preset |
| `POST` | `/presets/:id/apply` | Apply a preset (restores each zone's power, source, volume) |
| `DELETE` | `/presets/:id` | Delete a preset |
| `GET` | `/sources` | List the six input/source names |
| `POST` | `/sources/:id/:name` | Rename an input/source |

A small web control panel is served at `/` (zone power/source/volume, presets, and source names).

`:attribute` is one of the amplifier's codes:

| Code | Meaning |
| --- | --- |
| `pr` | Power (`00`/`01`) |
| `mu` | Mute |
| `dt` | Do not disturb |
| `vo` | Volume (`00`–`38`) |
| `tr` | Treble |
| `bs` | Bass |
| `bl` | Balance |
| `ch` | Source (`01`–`06`) |
| `pa` | PA |
| `name` | Friendly name (persisted to SQLite) |

For example, `POST /zones/11/vo/15` sets zone 11's volume to 15, and `POST /zones/11/name/Kitchen` names it.

## Running on an older Mac (e.g. a Catalina mini)

The amplifier is often hooked up to an old, always-on Mac. macOS 10.15 Catalina can only run Swift 5.3, which has no `async`/`await`, so you can't build this there. Instead, build on a modern Mac and cross-compile:

```bash
scripts/deploy-to-mini.sh [debug|release]
```

The script builds an `x86_64-apple-macosx10.15` binary, bundles the Swift concurrency back-deployment dylib that Catalina lacks, and copies it to the target Mac (set `MINI` / `REMOTE_DIR` to override the destination). See `CLAUDE.md` for details.
