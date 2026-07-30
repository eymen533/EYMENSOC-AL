# iPhone’da kullanma

## Önemli
`cdn.jsdelivr.net` veya `raw.githubusercontent.com` linkleri uygulamayı **kod olarak** gösterir (HTML’i text/plain verir). Bunları kullanma.

## Şimdi aç (doğru link — sayfa olarak açılır)

https://direction-russell-pepper-ship.trycloudflare.com

Safari ile aç → vakitler gelsin → **Paylaş → Ana Ekrana Ekle**.

> Bu Cloudflare linki geçici olabilir. Düşerse PR’daki güncel linke bak veya aşağıdan Netlify’ı sahiplen.

## Kalıcı site (önerilen — 1 dk)

1. Telefonda veya bilgisayarda aç:  
   https://app.netlify.com/drop/lovely-tartufo-cc9c04#drop_token=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE3ODU0Mzg1MDYsImV4cCI6MTc4NTQ0MjEwNiwiaXNzIjoiTmV0bGlmeSIsInNlc3Npb25faWQiOiI4NDZjM2YzZi1lZDIxLTQ2OTctOWQyOS04ZmI1MTNhNDk2Y2YifQ.Cvy-ZOpm9RpDV2YwJiWOtrkBz2Wh78PyFKnMG0rrr4o
2. Netlify’a GitHub ile giriş yapıp siteyi **Claim** et (60 dk içinde)
3. Password korumasını kapat
4. Verilen `*.netlify.app` adresini Safari → Ana Ekrana Ekle

Geçici şifreli önizleme (claim öncesi):  
http://lovely-tartufo-cc9c04.netlify.app  
Şifre: `My-Drop-Site`

## GitHub Pages (kalıcı, ücretsiz)

Repo → **Settings → Pages** → Source: **GitHub Actions**  
Sonra workflow `Deploy Vakit to GitHub Pages` siteyi yayınlar:  
`https://eymen533.github.io/EYMENSOC-AL/`

## Widget

App Store → Scriptable → `docs/widget/scriptable-namaz.js`
