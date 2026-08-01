# Tesla Pulse — Cinematic vehicle HUD (Plotly Dash)

Canlı hız, vites, batarya, şarj süresi ve harita üzerinde araç konumu gösteren
Tesla dashboard uygulaması. **B / L** düğmesi ile Black (karanlık) ve Light
(aydınlık) temalar arasında geçiş yapılır.

## Hızlı başlangıç

```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python run.py
```

Tarayıcıda: [http://127.0.0.1:8050](http://127.0.0.1:8050)

Token yoksa uygulama otomatik **DEMO** modunda gerçekçi sürüş/şarj simülasyonu
çalıştırır (İstanbul güzergâhı + canlı telemetri).

## Gerçek Tesla bağlantısı

1. `.env.example` dosyasını `.env` olarak kopyalayın.
2. Tesla Owner API / Fleet API access token ve araç ID'sini girin:

```env
TESLA_ACCESS_TOKEN=your_token
TESLA_VEHICLE_ID=your_vehicle_id
TESLA_LIVE=true
```

3. Uygulamayı yeniden başlatın. Bağlantı başarısız olursa demo moda düşer.

> Resmi Tesla Fleet API kayıt ve OAuth süreci Tesla developer portal üzerinden
> yapılır. Token'ınızı repoya commit etmeyin.

## Özellikler

- Tam ekran harita arka planı (Carto dark/light tiles)
- Hız göstergesi, güç (kW), vites P/R/N/D
- Batarya %, menzil, şarj gücü ve tahmini dolum süresi
- Sentry / Autopilot / kilit durum bayrakları
- B/L (Black ↔ Light) tema geçişi
- 1 sn telemetri yenileme

## Yapı

```
tesla_dash/
  app.py              # Dash HUD
  assets/style.css    # B/L tema + animasyonlar
  components/gauges.py
  tesla/
    client.py         # Owner API istemcisi
    simulator.py      # Demo telemetri
run.py
requirements.txt
.env.example
```
