# Tesla Pulse — kişisel BLE küme ekranı

PIN korumalı; yalnızca senin telefonundan kullanılmak üzere.

## Hızlı çalıştırma

```bash
cp .env.example .env
# .env içinde ACCESS_PIN ve SECRET_KEY ayarla
pip install -r requirements.txt
python run.py
```

Telefon: tünel veya yerel URL → **PIN** → küme ekranı.

### Telefona uygulama gibi yükleme (PWA)

App Store / Play Store gerekmez — tarayıcıdan ana ekrana eklenir.

**iPhone (Safari)**
1. Linki **Safari** ile aç (Chrome’da “Ana Ekrana Ekle” olmayabilir)
2. PIN ile gir
3. Alttaki **Paylaş** (□↑) → **Ana Ekrana Ekle** → Ekle
4. Ana ekrandaki **Pulse** ikonundan aç

**Android (Chrome)**
1. Linki **Chrome** ile aç
2. PIN ile gir
3. Menü **⋮** → **Uygulamayı yükle** veya **Ana ekrana ekle**
4. Ana ekrandaki **Pulse** ikonundan aç

Yatay (landscape) tutman önerilir.

## Güvenlik

- `ACCESS_PIN` olmadan uygulama açılmaz
- Oturum çerezi ~30 gün telefonda kalır
- PIN’i kimseyle paylaşma; `.env` commit edilmez

## BLE / Pairing (önemli)

Pulse’un **Bağlan / HUD** akışı **gerçek araç Pair UI’sini açmaz**.

| Ne | Sonuç |
|---|---|
| Uygulamadaki VIN + “kart onay” + HUD | Telefon HUD oturumu (simülasyon) |
| Web Bluetooth (Chrome) | İsteğe bağlı GATT denemesi — VCSEC `add-key` yok |
| Cloudflare tüneli | Sunucu bulutta; telefona yakın BLE yok |
| Web NFC | Arabadaki kart okuyucuyu tetiklemez |

**Arabada Pair penceresi** için (Key Card → Confirm):

1. **Resmi yol (şimdi):** Tesla app → Phone Key → Start → Key Card’ı konsola tut  
2. **Geliştirici yolu:** araç yanında laptop/Raspberry Pi → [`tesla-control -ble add-key-request`](https://github.com/teslamotors/vehicle-command) → Key Card  
3. **Python:** [`tesla_fleet_api.TeslaBluetooth`](https://github.com/Teslemetry/python-tesla-fleet-api) `vehicle.pair()` (aynı BLE + kart)  
4. **Bu Dash’e gömmek:** mümkün değil (native BLE + P-256 anahtar + protobuf gerekir) — ayrı companion gerekir

Ayrıntı: [docs/PAIRING.md](docs/PAIRING.md)

## Yan paneller

Kaydır: Seyahat · Lastik · Harita · Medya  
Dokun: tam ekran · sağ üst hız chip’i ile geri dön

## Repo

https://github.com/eymen533/EYMENSOC-AL
