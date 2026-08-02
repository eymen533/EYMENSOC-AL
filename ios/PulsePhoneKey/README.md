# Pulse Key — Xcode native (xcode-ble-2)

Gerçek BLE LIVE + Dashla tarzı HUD + **Google Maps** (hedef gelince rota çizilir).
iOS **16+**.

## Git
```bash
git clone -b cursor/ble-pair-fix-02d8 https://github.com/eymen533/EYMENSOC-AL.git
cd EYMENSOC-AL
git pull
open ios/PulsePhoneKey/PulsePhoneKey.xcodeproj
```

## Google Maps API key
1. [Google Cloud Console](https://console.cloud.google.com/) → proje
2. **Maps JavaScript API** + **Directions API** etkinleştir
3. API key oluştur
4. Uygulamada Settings → **Google Maps** → key yapıştır → Done

## Kullanım
1. Signing → Apple ID → iPhone Run ▶
2. Ekranda `xcode-ble-2`
3. Pair → Key Card → Cluster
4. Haritada Google Maps; araçta rota/hedef varken mavi çizgi görünür
