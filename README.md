# Tesla Pulse — BLE Vehicle HUD (Plotly Dash)

Tesla araç HUD'u. Bağlantı **Bluetooth Low Energy (BLE)** üzerinden kurulur.

## Özellikler

- **BLE BAĞLAN** — Web Bluetooth ile yakındaki Tesla'ya bağlanır (Chrome/Edge)
- Adaptör yoksa veya tarayıcı desteklemiyorsa **BLE demo link** açılır
- İsteğe bağlı sunucu tarama: `bleak` + `/api/ble/scan`
- Tam ekran harita, hız, vites P/R/N/D, batarya %, şarj süresi, güç (kW)
- RSSI sinyal çubukları ve BLE cihaz kimliği

## Çalıştırma

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python run.py
```

Tarayıcı: [http://127.0.0.1:8050](http://127.0.0.1:8050)

1. **BLE BAĞLAN** düğmesine basın
2. Chrome cihaz seçicisinden Tesla'yı seçin (veya demo moda geçilsin)
3. HUD canlı telemetriye geçer

> Web Bluetooth için **localhost** veya **HTTPS** gerekir.

## BLE API

| Endpoint | Açıklama |
|----------|----------|
| `POST /api/ble/demo` | Demo BLE link |
| `POST /api/ble/disconnect` | Bağlantıyı kes |
| `GET /api/ble/status` | Anlık BLE durumu |
| `POST /api/ble/scan` | bleak ile yerel tarama |

## Gerçek araç telemetrisi (opsiyonel)

BLE araç yakınlık / kimlik linkidir. Tam hız-batarya verisi için Owner API:

```env
TESLA_ACCESS_TOKEN=...
TESLA_VEHICLE_ID=...
TESLA_LIVE=true
```

Token yoksa BLE bağlantısından sonra gerçekçi **simülasyon** HUD'u besler.

## Yapı

```
tesla_dash/
  app.py
  assets/style.css
  assets/ble.js          # Web Bluetooth istemcisi
  components/gauges.py
  tesla/
    ble.py               # BLE oturum + bleak tarama
    client.py
    simulator.py
```
