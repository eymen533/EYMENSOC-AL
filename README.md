# EYMEN BeamNG Digital Cluster

Telefona **PC IP** yazıyorsun. Kablosuz kadran + harita + dijital ikonlar.

## Kurulum (kolay yol)

### 1) PC — bir kez Node.js
https://nodejs.org → LTS kur

### 2) PC — çift tık
Repodaki `EYMEN-Cluster-Baslat.bat` dosyasına **çift tıkla**.  
Siyah pencerede PC IP’leri yazar (ör. `http://192.168.1.20:8080`).

### 3) BeamNG (localhost!)
Options → Other → Protocols (Advanced açık):

| Protocol   | Address     | Port |
|------------|-------------|------|
| OutGauge   | `127.0.0.1` | 4444 |
| MotionSim  | `127.0.0.1` | 4445 |

Menüyü kapat → arabaya bin → **Ctrl+R**

### 4) Telefon
1. `dist/EYMEN-BeamNG-Cluster.apk` kur  
2. Uygulamada **Bilgisayar IP** = bat’ın yazdığı IP (sadece sayı, ör. `192.168.1.20`)  
3. **PC’ye Bağlan**

## Ne var?
- Dijital kadran (hız, RPM, vites)
- Sinyal / far / ABS / TC / shift ikonları
- NAV harita: konum, sürüş izi, gidiş rotası (MotionSim)
- Demo modu (oyunsuz)

> BeamNG stok protokolünde “GPS hedef waypoint listesi” yok. Harita MotionSim konum + yön ile rota şeridi çizer. Oyundaki navigasyon hedefini birebir almak için özel mod gerekir (ileride eklenebilir).

## Sorun olursa
- Bat penceresi açık kalsın  
- Aynı Wi‑Fi (misafir ağ değil)  
- Windows ilk seferde güvenlik duvarı sorarsa **İzin ver**  
- Telefonda Demo çalışıyorsa uygulama tamam; sorun BeamNG/ağ tarafındadır  

## Geliştirici
```bash
node server/index.js
node server/index.js --demo
cd android && ./gradlew assembleRelease
```

## Lisans
MIT
