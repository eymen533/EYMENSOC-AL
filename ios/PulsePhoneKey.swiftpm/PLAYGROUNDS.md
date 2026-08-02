# iPhone / iPad — Swift Playgrounds (gerçek uygulama)

Safari değil: Run ▶ sonrası Ana Ekran’da **yerel Pulse uygulaması** açılır; BLE CoreBluetooth kullanır.

Adım adım (iPhone): [`IPHONE.md`](IPHONE.md) · Çökerse: [`CRASH_FIX.md`](CRASH_FIX.md)

## Kur

1. Zip’i indir → `PulsePhoneKey.swiftpm` aç  
2. App Settings → Signing (Apple ID)  
3. Capabilities → **Bluetooth Always**  
4. Run ▶  
5. Ana ekranda sürüm: **`build-14-iphone`**

## Pair

1. Arabayı uyandır, Tesla app kapat  
2. **Pair Vehicle** → VIN → listeden `🔑 Tesla …`  
3. Log: `TX tamam` / `Istek gitti`  
4. Key Card → **konsol** → Pair / Confirm  
5. **Open Cluster HUD** (Dash sunucu URL’si ayakta olmalı)
