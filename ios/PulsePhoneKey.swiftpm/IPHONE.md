# build-28-livemap

## Arabaya baglayinca ne calisir?

| Ozellik | BLE Pair (araba) | Aciklama |
|---|---|---|
| Phone Key (kilit/surus anahtari) | Evet | Tesla Key Card onayi sonrasi |
| Canli hiz / batarya BLE uzerinden | Hayir | VCSEC anahtar protokolu telemetri degil |
| Canli harita | Evet | Telefon GPS (OSM) |
| Arac GPS + hiz HUD’da | Dash URL + PIN | Settings’te Dash adresi; sunucu Tesla API live ise gercek arac |

## Kurulum
1. Eski PulsePhoneKey sil  
2. Zip ac → Run ▶ → **`build-28-livemap`**  
3. Konum izni ver  
4. Settings → Dash URL + PIN `428462` (telemetri icin)  
5. Cluster → yatay  

Zip: https://authorization-card-wonder-chuck.trycloudflare.com/downloads/PulsePhoneKey-playground-build28.zip

GitHub: https://github.com/eymen533/EYMENSOC-AL/raw/cursor/ble-pair-fix-02d8/releases/PulsePhoneKey-playground-build28.zip
