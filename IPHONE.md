# iPhone — Vakit (kalıcı site)

## Senin adresin
https://adorable-sprite-995f0b.netlify.app

1. Netlify’da **Make public** yap (Private olmasın)
2. Safari → bu adresi aç → **Paylaş → Ana Ekrana Ekle**
3. Bundan sonra ikona basınca hep bu site açılır

## Her değişiklik otomatik gelsin (bir kez ayarla)

### Yöntem A — Netlify’ı GitHub’a bağla (en kolay)
1. Netlify → `adorable-sprite-995f0b` → **Project configuration**
2. **Build & deploy** → **Link repository** → GitHub → `eymen533/EYMENSOC-AL`
3. Branch: `cursor/namaz-vakitleri-1d93` (veya `main`)
4. Build command: `npm run build`
5. Publish directory: `docs`
6. Save

Bundan sonra her commit Netlify’a yayınlanır; Ana Ekran ikonu açılınca / öne gelince yeni sürüm yüklenir.

### Yöntem B — GitHub Actions secret
Repo → Settings → Secrets → Actions:
- `NETLIFY_AUTH_TOKEN` (Netlify → User settings → Personal access tokens)
- `NETLIFY_SITE_ID` = `a5bf1d86-ea2f-4ae8-92a4-3b593f45fe1c`

Workflow: `.github/workflows/deploy-netlify.yml`

## Not
Cloudflare / eski Drop linkleri geçici; Ana Ekran için sadece `adorable-sprite-995f0b.netlify.app` kullan.
