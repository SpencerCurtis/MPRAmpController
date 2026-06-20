# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`MPRAmpController` is a **Vapor 4 web server** that exposes an HTTP API for controlling a Monoprice "6 Zone Home Audio Multizone Controller and Amplifier Kit" (product 10761; should also work with the Dayton Audio DAX66, untested). It talks to the amplifier over an **RS-232 serial port** via a USB-to-serial cable.

**macOS only.** Serial I/O uses [ORSSerialPort](https://github.com/armadsen/ORSSerialPort), which does not build on Linux. A Linux/Raspberry-Pi-capable variant using SwiftSerial lives in a [separate repo](https://github.com/SpencerCurtis/MPRAmpController-SwiftSerial) (referenced in the README), not here.

## The build/deploy split (read this first)

The production box (`spencercurtis@Spencers-Mac-mini.local`) runs **macOS 10.15.7 Catalina on Intel (x86_64)**, whose newest possible toolchain is **Swift 5.3.2 / Xcode 12.4 — which has no `async`/`await`**. The dev machine runs a modern Swift. These differ in **both arch and OS**, so a binary built natively on either one will not run on the other.

The code uses `async`/`await` (tools-version **5.5**). async/await *back-deploys* to 10.15, but the 5.5+ compiler that understands it only runs on macOS 11+. The resolution:

- **Build on the dev machine, cross-compile, and ship** with `scripts/deploy-to-mini.sh [debug|release]`. It runs `swift build --arch x86_64` (SwiftPM honors `.macOS(.v10_15)`), bundles the Swift concurrency back-deployment dylib (Catalina's `/usr/lib/swift` lacks it), adds an `@executable_path` rpath, and `scp`s `Run` + `libswift_Concurrency.dylib` to the mini.
- You **cannot** build this project on the mini itself (no async compiler). Don't try to "fix" that by removing async — the deploy pipeline is the supported path.

### Local development on the dev machine

```bash
swift build                 # native build (won't run on the mini)
swift test                  # 11 XCTest cases — run these for fast feedback
scripts/deploy-to-mini.sh   # cross-compile x86_64 + ship to the Catalina mini
```

The server listens on `0.0.0.0:8001` (hardcoded in `configure.swift`). On the mini:

```bash
ssh spencercurtis@Spencers-Mac-mini.local 'cd /tmp/mprampcontroller && ./Run'
# Stop it with:  pkill -9 -x Run     <-- exact name; the process argv is "./Run",
#                                        so pkill -f <fullpath> will NOT match it.
```

**Gotcha:** `main.swift` ends with `RunLoop.main.run()`, which never returns — even after SIGTERM or a failed port bind. So `kill $PID; wait $PID` over SSH hangs, and stray instances linger holding port 8001 + the serial port. Always clean up with `pkill -9 -x Run`.

Dependency versions are **pinned with `.exact(...)`** in `Package.swift`. Bumping the `swift-tools-version` (5.5) is independent of those pins, but don't bump Vapor/Fluent/ORSSerialPort casually — version drift was a real source of breakage.

### Hardware requirement

`ORSSerialTransport.init` looks for the first port whose name contains `usbserial`. The port is **optional** — if no adapter is present the app still boots; serial routes then fail (`noDevice`) rather than crashing.

## Architecture

A thin HTTP layer over a serial protocol. Four things matter:

### 1. `SerialController` holds the routes
`Sources/App/Controllers/SerialController.swift` is a plain `RouteCollection` with no hardware dependency or mutable state of its own: it talks to the amp through an injected `SerialTransport` and keeps live zone state in a `ZoneStore` actor.

Routes (registered in `boot(routes:)`, all `async`):
- `GET /zones` — query all zones (sends `?10\r`)
- `GET /zones/:zoneid` — query one zone (sends `?<id>\r`)
- `POST /zones/:zoneid/:attribute/:value` — set an attribute, or set a name if `:attribute == name`
- `POST /zones/all/:attribute/:value` — set one attribute on every zone (literal `all` wins over `:zoneid`)
- `GET /presets` · `POST /presets?name=…` (snapshot current state) · `POST /presets/:presetid/apply` · `DELETE /presets/:presetid`
- `GET /sources` · `POST /sources/:sourceid/:name` — friendly input names (defaults `Source N`)
- `GET /` serves a vanilla-JS control panel from `Public/index.html` (`FileMiddleware` `defaultFile`). `deploy-to-mini.sh` ships `Public/` alongside the binary; the server resolves it relative to its working directory.

**Routing gotcha:** RoutingKit forbids two routes sharing a prefix but using *different* parameter names at the same position (e.g. `presets/:name` + `presets/:presetid/apply` → boot-time `Precondition failed`). Keep one param name per position; capture takes its name from the query string instead. A *constant* vs a *param* (`zones/all` vs `zones/:zoneid`) is fine. This isn't caught by the controller tests since they don't exercise routing.

### 2. The serial transport
`SerialTransport` (`Sources/App/SerialTransport.swift`) abstracts the link: `send(_ command: Data, matching: SerialResponseMatcher) async throws -> Data`. `ORSSerialTransport` is the production implementation — it owns the `ORSSerialPort`, turns the matcher into an `ORSSerialPacketDescriptor`, and bridges the delegate callback back to the caller with `withCheckedThrowingContinuation` (a `ContinuationBox` guards against a reply/timeout double-resume). Tests inject a `FakeSerialTransport` that returns canned bytes.

The controller's core methods — `refreshAllZones`, `refreshZone`, `setAttribute` — build a command via `SerialProtocol`, `await transport.send`, parse the reply, and update the store. They take no `Request` and touch no DB, so they're unit-testable with the fake (see `SerialControllerTests`). The route handlers are thin wrappers that add parameter decoding and name persistence on top.

Adding a serial operation means: a `SerialProtocol` command builder + matcher, a controller core method that parses the reply, and a thin route wrapper.

### 3. `SerialProtocol` — the pure, testable core
`Sources/App/SerialProtocol.swift` is a hardware-free `enum` holding all command building and reply parsing (`parseZoneStatus`, `parseAllZoneStatus`, `parseAttributeStatus`, `queryAllZonesCommand`, etc.). It has **no ORSSerialPort dependency**, which keeps the wire format unit-testable. Put protocol logic here, not on the controller.

The Monoprice wire format:
- **Zone IDs are amp-prefixed**: `11`–`16` (amp unit 1, zones 1–6). `?10` returns all six zones. The `getAllZones` regex `(#>.+\r\r\n{0,}){6}#` is hardcoded to 6 zones / 1 amp — see the TODO about multiple chained amps.
- **Status replies** look like `#>1100010000190707100200` — two-digit fields, positionally decoded into id, pa, power, mute, doNotDisturb, volume, treble, bass, balance, source. A non-numeric field makes `parseZoneStatus` return `nil` (surfaces a bad reply instead of decoding zeros).
- **Attribute-set commands** are `<<zone><attr><value>\r`, e.g. `<11vo15\r`. Attribute codes are the raw values of `ZoneAttributeIdentifier` (`pa`, `pr`, `mu`, `dt`, `vo`, `tr`, `bs`, `bl`, `ch`). Reply matched with regex `<.{6}`.

### 4. State & persistence
- **Live zone state is in-memory** in the `ZoneStore` actor (`Sources/App/ZoneStore.swift`), rebuilt from amp replies; not persisted. Every mutation/read goes through the actor, so the serial transport and the route handlers can't race on it. The controller's core methods `await transport.send`, parse the reply, then `await store.merge`/`apply`.
- **Only zone names persist**, in SQLite (`zones.sqlite`, gitignored) via Fluent. `ZoneName` is the sole model; `CreateZone` its migration. `loadZoneNames(on:)` is `await`ed during GETs so names are merged deterministically (no fire-and-forget race).
- DB configured in `configure.swift`; `autoMigrate().wait()` runs at boot.

## Models (`Sources/App/Models/`)
- `Zone` — core value type. `Codable` uses **amp protocol keys** as JSON keys (`zone`, `pr`, `mu`, `vo`, …) and zero-pads single digits. `-1` means "unknown / not yet read." `apply(_:)` writes a single attribute update's *value* to the right field.
- `ZoneAttributeIdentifier` — friendly names to 2-char protocol codes; drives command building and response routing.
- `ZoneName` (Fluent) / `CreateZone` (migration) — name persistence.
- `Preset` (Fluent) / `CreatePreset` (migration) — a named scene; per-zone power/source/volume stored as JSON in the `zones` column, exposed to the API via `PresetDTO`/`PresetZone`.
- `SourceName` (Fluent) / `CreateSourceName` (migration) — friendly input names; `SourceCatalog.merged` fills `Source N` defaults.
- `ZoneAttributeUpdate` — a parsed attribute change (zone, attribute, value).

## Open issues (not yet fixed)
- **Single-amp assumptions** are hardcoded (the `{6}` in the all-zones regex, zone IDs `11`–`16`). Centralize before adding multi-amp support.
- **The port in `ORSSerialTransport` isn't synchronized** — read in `send` and set to `nil` in `serialPortWasRemovedFromSystem` (the delegate thread). Benign (set-once, nil-rarely); the zone *state* race is fixed via `ZoneStore`.

## Code Conventions
- Swift / Vapor 4, `swift-tools-version:5.5`, two targets: `App` (library) and `Run` (executable, `Sources/Run/main.swift`).
- Logging via `application.logger` (Vapor's `Logger`), not `NSLog`.
