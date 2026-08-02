# SOC — iPad Swift Playgrounds (çalışan yol)

Önceki talimatta uzak Swift package indirme yüzünden Playgrounds **sürekli dönüyordu**.  
Artık tüm bağımlılıklar `SOC.swiftpm/Packages/` içinde **offline** — ağda takılmaz.

## 1) Zip’i indir (tek dosya)

iPad Safari:

**https://github.com/eymen533/EYMENSOC-AL/raw/cursor/tesla-ble-companion-4163/dist/SOC-iPad.swiftpm.zip**

İndirince Files → **İndirilenler** içinde `SOC-iPad.swiftpm.zip` görünür.

## 2) Zip’i aç

Files’ta zip’e dokun → **Uncompress / Aç**.  
Çıkan klasör: **`SOC.swiftpm`**

## 3) Swift Playgrounds ile aç

1. App Store’dan **Swift Playgrounds** kurulu olsun  
2. `SOC.swiftpm` klasörüne basılı tut → **Paylaş** → **Swift Playgrounds**  
   veya Playgrounds → **Locations** → bu klasörü seç  
3. Birkaç saniye indeksleme sürebilir (uzak paket indirmez)  
4. **Run ▶️**

## 4) İzinler

- Bluetooth → İzin Ver  
- Konum → Uygulamayı Kullanırken  
- iPad’i yatay çevir

## 5) Arabada

Park’ta VIN gir → key card’ı konsola dokundur → dashboard.

---

## Dashboard önizleme (tarayıcı)

`htmlpreview.github.io` bozuluyor / boş dönüyor — kullanma.

Çalışan CDN linki (push sonrası ~1 dk):

https://cdn.jsdelivr.net/gh/eymen533/EYMENSOC-AL@cursor/tesla-ble-companion-4163/docs/preview.html

Model 3 görseli:

https://cdn.jsdelivr.net/gh/eymen533/EYMENSOC-AL@cursor/tesla-ble-companion-4163/docs/tesla-model3-topdown.png

## Doğrulama (geliştirici)

Mac/CI tarafında:

```bash
./scripts/verify_soc.sh
```

Bu script zip’i üretir, uzak URL olmadığını ve vendor paketlerini kontrol eder.
