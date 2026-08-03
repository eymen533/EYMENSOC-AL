# EYMEN BeamNG Digital Cluster

Android telefonunu BeamNG.drive **direksiyon önü dijital kadran** yapar.

**CMD yok. PC’de ekstra program yok.** Sadece APK kur + BeamNG’de IP yaz.

> BeamNG Bluetooth ile telemetri göndermez. Aynı Wi‑Fi üzerinden OutGauge = kablosuz bağlantı.

## Kurulum (CMD yok)

### 1) Telefona yükle
`dist/EYMEN-BeamNG-Cluster.apk` dosyasını telefona at ve kur  
(Bilinmeyen kaynaklara izin ver).

### 2) Uygulamayı aç
Ekranda **Telefon IP** görünür (ör. `192.168.1.35`).  
İstersen **IP’yi kopyala**.

### 3) BeamNG ayarı (bir kez)
1. PC ve telefon **aynı Wi‑Fi**
2. BeamNG → **Options → Other → Protocols**
3. **OutGauge** aç
4. IP = telefondaki adres  
5. Port = **4444**

### 4) Kadranı Başlat
Telefonda **Kadranı Başlat** → direksiyon önüne yatay sabitle.

Oyunsuz denemek için uygulamada **Demo**.

## Ne gösterir?
Hız · RPM · vites · sinyal/far · ABS/TC · yakıt · su sıcaklığı · turbo · gaz/fren

## APK’yı yeniden derlemek (geliştirici)
```bash
cd android
./gradlew assembleDebug
# çıktı: app/build/outputs/apk/debug/app-debug.apk
```

## (İsteğe bağlı) PC web köprüsü
Eski `npm start` yolu hâlâ `server/` altında duruyor; normal kullanım için gerekmez.

## Lisans
MIT
