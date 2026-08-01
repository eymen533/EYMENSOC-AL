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

## BLE

1. **Bağlan**
2. VIN veya Demo VIN
3. Tesla Key Card
4. BLE Bağlan

## Yan paneller

Kaydır: Seyahat · Lastik · Harita · Medya  
Dokun: tam ekran · sağ üst hız chip’i ile geri dön

## Repo

https://github.com/eymen533/EYMENSOC-AL
