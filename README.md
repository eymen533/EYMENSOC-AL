# Tesla Pulse — BLE Instrument Cluster (Plotly Dash)

Referans Tesla cluster tarzı HUD. Bağlantı **Bluetooth Low Energy (BLE)**.

## Sol / sağ paneller (dikey slayt)

Her iki yan panelde yukarı–aşağı kaydırarak (veya noktalara tıklayarak):

1. **Medya** — çalan şarkı
2. **Lastik basıncı** — FL / FR / RL / RR
3. **Harita** — konum + ODO

Sol varsayılan: Medya · Sağ varsayılan: Harita. İkisi de bağımsız seçilir.

## Çalıştırma

```bash
pip install -r requirements.txt
python run.py
```

http://127.0.0.1:8050 → **Bağlan** (BLE)

- Chrome/Edge + localhost/HTTPS → Web Bluetooth
- Yoksa demo BLE link otomatik açılır

## Kontroller

| Jest | Sonuç |
|------|--------|
| Yan panelde kaydır / tekerlek | Slayt değiştir |
| Noktalar | Medya / Lastik / Harita |
| Bağlan / Kes | BLE link |

## Yapı

```
tesla_dash/
  app.py
  assets/style.css
  assets/ble.js
  assets/carousel.js
  tesla/ble.py · client.py · simulator.py
```
