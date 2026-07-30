# iPhone’da kullanma (kalıcı)

Geçici `trycloudflare.com` linkleri kapanınca Ana Ekran kısayolu bozulur.
**Kalıcı adres (bunu ekle):**

https://cdn.jsdelivr.net/gh/eymen533/EYMENSOC-AL@cursor/namaz-vakitleri-1d93/docs/index.html

## 1) Ana ekran uygulaması

1. iPhone’da **eski “Vakit / Namaz” ikonunu sil** (basılı tut → Kaldır)
2. Yukarıdaki kalıcı linki **Safari** ile aç (Chrome değil)
3. Bir kez vakitlerin yüklendiğini gör (önbellek için şart)
4. **Paylaş → Ana Ekrana Ekle**
5. Artık kapatıp açınca da çalışır (uygulama kabuğu telefonda saklanır; vakitler için internet gerekir)

## 2) Widget (Scriptable)

1. App Store → **Scriptable**
2. Yeni script → `widget/scriptable-namaz.js` içeriğini yapıştır  
   veya: aynı jsDelivr yolunda `/widget/scriptable-namaz.js` (repodan)
3. Ana ekran → **+ → Scriptable** (Medium) → scripti seç
4. Parameter: şehir (`Istanbul`, `Bursa`…)

## 3) İsteğe bağlı: kendi GitHub Pages’in

Repo → **Settings → Pages → Deploy from a branch** → branch + `/docs`.
Sonra `https://eymen533.github.io/EYMENSOC-AL/` kalıcı olur.
