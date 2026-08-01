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

Safari / Chrome: **Paylaş → Ana Ekrana Ekle** ile tam ekran uygulama gibi açılır.

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
