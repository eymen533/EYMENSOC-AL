# iPhone’da kullanma

## 1) Ana ekrana uygulama olarak ekle (PWA)

1. Safari ile aç: deploy ettiğin site adresini
2. Alttaki **Paylaş** butonuna dokun
3. **Ana Ekrana Ekle** seç
4. İsim: **Namaz** → Ekle

Uygulama tam ekran açılır, renkleri şehir yanında seçebilirsin.

## 2) Ana ekran widget’ı (Scriptable)

Apple’ın Safari PWA’sı gerçek Home Screen widget desteklemez.
Bu yüzden ücretsiz **Scriptable** uygulaması ile widget ekliyoruz:

1. App Store → **Scriptable** indir
2. Scriptable’da **+** → yeni script
3. Repodaki `widget/scriptable-namaz.js` içeriğini yapıştır
4. İstersen `CITY = "Istanbul"` satırını değiştir (Ankara, Izmir, Bursa…)
5. Ana ekranda boş yer → basılı tut → **+** → **Scriptable**
6. Boyut: **Medium** önerilir
7. Widget’a uzun bas → **Edit Widget** → Script’i seç
8. İsteğe bağlı: Parameter alanına şehir yaz (`Bursa`)

Widget her dakika yenilenir; sonraki vakit + geri sayım + tüm vakitler görünür.
