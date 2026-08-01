# Tesla Pulse — BLE Instrument Cluster

VIN + Tesla Key Card eşleşmesi ile BLE bağlantılı araç HUD.

## Hızlı çalıştırma

```bash
pip install -r requirements.txt
python run.py
```

Tarayıcı: **http://127.0.0.1:8050**

## BLE nasıl bağlanır? (VIN + kart)

Gerçek Tesla uygulamalarına benzer akış:

1. Sağ üstte **Bağlan**
2. **VIN** girin (17 karakter) veya **Demo VIN kullan**
3. **Tesla Key Card** adımında kartı okut / onayla
4. **BLE Bağlan** — Web Bluetooth varsa cihaz seçici açılır; yoksa demo BLE link kurulur

| Adım | Ne yapar |
|------|----------|
| VIN | Aracı tanımlar (`/api/ble/vin`) |
| Kart | Key Card onayı (`/api/ble/card`) |
| BLE | Yakınlık linki (`/api/ble/pair` veya Web Bluetooth) |

> Not: Tarayıcıda gerçek Tesla BLE anahtar protokolü (VCSEC) kısıtlıdır. Bu uygulama eşleşme UX’ini + HUD’u sunar; tam telemetri için opsiyonel Owner API token kullanılabilir.

## Yan paneller

Sol ve sağda ↕ kaydır: **Medya · Lastik · Harita**

## Repo

https://github.com/eymen533/EYMENSOC-AL/tree/cursor/tesla-dash-bl-mode-02d8
