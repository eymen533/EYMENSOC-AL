# EYMEN BeamNG Digital Cluster

Android telefonunu / tableti **direksiyon önü dijital kadran** olarak kullan.
BeamNG.drive OutGauge telemetrisini alır, BMW tarzı geniş dijital cluster gösterir.

## Ne lazım?

- BeamNG.drive (PC)
- Node.js 18+ (PC’de, küçük köprü sunucu için)
- Android cihaz (aynı Wi‑Fi ağında)
- Telefon tutucu (direksiyon arkası / göğüs paneli)

## Kurulum (3 adım)

### 1) PC’de sunucuyu çalıştır

```bash
cd EYMENSOC-AL
npm start
```

Konsolda Android için bir adres çıkar, örneğin:

`http://192.168.1.42:8080`

BeamNG yokken denemek için:

```bash
npm run demo
```

### 2) BeamNG OutGauge ayarı

1. BeamNG.drive → **Options → Other → Protocols**
2. **OutGauge** aç
3. **IP** = PC’nin yerel IP’si (sunucunun yazdığı adres)
4. **Port** = `4444`

> Not: Android tarayıcı doğrudan UDP dinleyemez. Bu yüzden OutGauge **PC’deki bu sunucuya** gider; Android sadece web kadranı açar.

### 3) Android’de kadranı aç

1. Telefonda Chrome ile `http://PC_IP:8080` aç
2. **Kadranı Aç** → tam ekran
3. Telefonu **yatay** tut, direksiyon önüne sabitle
4. Ana ekrana “Uygulama olarak ekle” dersen PWA gibi tam ekran kalır

## Ekranda ne var?

- Sol: hız (km/h / mph)
- Orta: vites, sinyal, uyarılar, gaz/fren
- Sağ: devir (RPM)
- Alt: yakıt, su sıcaklığı, turbo (varsa)

## Donanım ipuçları

- Parlaklığı yüksek tut, gece sürüşte azalt
- Mümkünse eski bir telefon kullan (pil + kırılma riski)
- Tutucuyu görüşü engellemeyecek şekilde sabitle
- PC ile telefon aynı Wi‑Fi’de olsun (misafir ağı ayırıyorsa bağlanmaz)

## Klasör yapısı

```
server/          OutGauge UDP → WebSocket köprüsü
public/          Android’de açılan kadran arayüzü
```

## Sorun giderme

| Sorun | Çözüm |
|---|---|
| SİNYAL YOK | BeamNG OutGauge IP/port doğru mu? `npm start` çalışıyor mu? |
| Sayfa açılmıyor | Windows Güvenlik Duvarı 8080/4444’e izin ver |
| Demo çalışıyor, oyun yok | OutGauge kapalı veya yanlış IP |
| Sadece localhost | Android’den PC IP’sini kullan, `localhost` değil |

## Lisans

MIT
