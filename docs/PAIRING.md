# Real Tesla Pair (Key Card + BLE) vs Pulse HUD

## What Pulse does today

The Dash “pair” wizard is a **phone HUD session**:

1. Accepts a VIN string (format check only)
2. “Key Card” is a **button** — no NFC, no console reader
3. “Connect” sets `source=demo` (or optional Web Bluetooth GATT)

Nothing in this flow talks VCSEC whitelist / `add-key-request`. The car’s center screen will **not** show Pair / Confirm.

Web Bluetooth in `assets/ble.js` may open a Chrome device picker and `gatt.connect()` to Tesla service UUID `00000211-b2d1-4f76-bada-24be206df979`. That is **not** phone-key enrollment.

## What actually triggers Pair on the car

**Important:** the Key Card goes on the **car’s console reader**, not on the phone.
The phone (or laptop) only sends the BLE `add-key` request; the card on the console
authorizes it — then the car screen shows Pair / Confirm.

Official / third-party clients sitting **next to the car** over BLE:

1. Generate a P-256 keypair
2. GATT-connect to the vehicle advertising that VIN
3. Send unsigned VCSEC whitelist `add-key` / `add-key-request`
4. User taps an **existing** Key Card on the **center console** (cupholder / armrest reader)
5. Car UI asks to authorize the new key → Confirm

Cloudflare (or any remote host) cannot substitute for step 2–3: BLE range is local to the radio that sends the protobuf.

### In the car right now (Tesla app)

1. Open **Tesla** app → **Phone Key** / add key  
2. Tap **Start**  
3. Put Key Card on the **console** (not the phone)  
4. Confirm **Pair** on the vehicle screen

### Open-source tools

| Tool | Notes |
|---|---|
| [teslamotors/vehicle-command](https://github.com/teslamotors/vehicle-command) `tesla-control -ble add-key-request …` | Official reference; laptop Bluetooth on |
| [Teslemetry/python-tesla-fleet-api](https://github.com/Teslemetry/python-tesla-fleet-api) `VehicleBluetooth.pair()` | Python + bleak on a machine near the car |
| [swift-tesla-ble](https://github.com/shoujiaxin/swift-tesla-ble) | Native iOS pairing path |
| Unofficial BLE docs | [teslabtapi.com](https://www.teslabtapi.com/docs/start) |

There is **no public Android Intent** that starts Tesla Phone Key pairing for third-party apps. Use the Tesla app UI, or a native BLE companion that implements VCSEC.

## Can Web Bluetooth / Web NFC via Cloudflare tunnel trigger Pair?

| API | Verdict |
|---|---|
| Web Bluetooth | Theoretically could write GATT bytes from **the phone’s** radio (HTTPS required — tunnel helps). Still needs full VCSEC protobuf + keygen in JS, fragile UX, no Safari/iOS. Not shipped here. |
| Web NFC | Reads/writes NFC tags on the **phone**. Does **not** talk to the car’s console reader. Cannot fake Key Card authorization. |
| Server-side bleak on the cloud VM | Radio is in the datacenter, not the garage — useless for vehicle BLE. |

## Realistic paths for this cloud-hosted Dash

Ranked for someone **already in the car**:

1. **Tesla app Phone Key** — open Tesla → Phone Key → Start → tap Key Card → Confirm on the screen. Pulse stays a separate HUD PWA.
2. **Keep Pulse as honest HUD** — use in-app “HUD’u aç”; do not expect car Pair.
3. **Laptop beside you** — `tesla-control -ble add-key-request public.pem owner cloud_key` (or Python `pair()`), then Key Card.
4. **Future native companion** (Android/iOS or on-car Pi) that does real `add-key`, then hands Fleet/telemetry tokens to Pulse over HTTPS. The Dash alone cannot complete Pair.

Do not commit VINs or private keys into the repo; keep them in local `.env` only.
