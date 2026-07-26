# Balon Patlat!

Çocuklar için sade, dokunmatik ve renkli bir Android balon patlatma oyunu.

## Özellikler

- Büyük dokunma alanları, kolay kontrol
- Türkçe arayüz
- Altın balonlar, kombo sistemi ve 60 saniyelik tur
- Yerel en iyi skor kaydı
- Titreşim (destekleyen cihazlarda) ve patlama sesleri

## Web'de deneme

```bash
npm install
npm run build
npm run serve
```

Tarayıcıda `http://localhost:4173` adresini aç.

## Android APK derleme

Gereksinimler: Node.js 20+, JDK 17/21, Android SDK (platform 35, build-tools).

```bash
npm install
npm run build
npx cap add android   # ilk seferde
npm run cap:sync
npm run apk:debug
```

APK çıktısı:

`android/app/build/outputs/apk/debug/app-debug.apk`

Hazır APK varsa `artifacts/BalonPatlat.apk` konumuna da kopyalanır.

## Telefona kurulum

1. APK dosyasını telefona aktar
2. Bilinmeyen kaynaklardan uygulamaya izin ver
3. APK'ya dokunarak kur
4. **Balon Patlat** uygulamasını aç ve oyna

## Oynanış

1. Ana ekranda **Oyna**ya dokun
2. Yukarı çıkan balonlara dokunarak patlat
3. Altın balonlar daha çok puan verir
4. Üst üste patlatarak kombo yap
5. 60 saniye bitince skorunu gör
