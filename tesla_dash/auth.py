"""Private access gate — PIN unlock with signed cookie session."""

from __future__ import annotations

import hashlib
import hmac
import os
import secrets
import time
from typing import Any

from flask import Flask, jsonify, redirect, request, session


def _pin() -> str:
    return (os.getenv("ACCESS_PIN") or "").strip()


def _secret() -> str:
    return os.getenv("SECRET_KEY") or os.getenv("ACCESS_SECRET") or "pulse-dev-secret"


def pin_configured() -> bool:
    return bool(_pin())


def verify_pin(candidate: str) -> bool:
    expected = _pin()
    if not expected:
        return False
    return hmac.compare_digest(str(candidate or "").strip(), expected)


def issue_session() -> None:
    session.clear()
    session["pulse_auth"] = True
    session["pulse_at"] = int(time.time())
    session["pulse_nonce"] = secrets.token_hex(8)


def clear_session() -> None:
    session.clear()


def is_unlocked() -> bool:
    if not pin_configured():
        # Fail closed when PIN missing in production-like use
        return os.getenv("ALLOW_OPEN", "").lower() in {"1", "true", "yes"}
    if not session.get("pulse_auth"):
        return False
    # 30-day phone session
    issued = int(session.get("pulse_at") or 0)
    return (time.time() - issued) < 30 * 24 * 3600


def register_auth(server: Flask) -> None:
    # Cloudflare / reverse-proxy: trust X-Forwarded-Proto so secure cookies work
    try:
        from werkzeug.middleware.proxy_fix import ProxyFix

        server.wsgi_app = ProxyFix(server.wsgi_app, x_for=1, x_proto=1, x_host=1)  # type: ignore[method-assign]
    except Exception:  # noqa: BLE001
        pass

    server.secret_key = _secret()
    server.config.update(
        SESSION_COOKIE_NAME="pulse_session",
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        PERMANENT_SESSION_LIFETIME=30 * 24 * 3600,
        # false works on HTTPS tunnels too; set COOKIE_SECURE=true only if required
        SESSION_COOKIE_SECURE=os.getenv("COOKIE_SECURE", "false").lower()
        in {"1", "true", "yes"},
    )

    public_exact = {
        "/login",
        "/api/auth/unlock",
        "/api/auth/status",
        "/api/auth/logout",
        "/manifest.webmanifest",
        "/sw.js",
    }

    @server.before_request
    def _gate():  # type: ignore[no-redef]
        path = request.path or "/"
        if path in public_exact:
            return None
        # Allow lock-screen assets; app still needs suites to boot shell
        if path.startswith("/assets/") or path.startswith("/_dash-component-suites/"):
            return None
        if path.startswith("/_favicon"):
            return None
        if is_unlocked():
            return None
        # Unauthenticated
        if path.startswith("/api/") or path.startswith("/_dash"):
            return jsonify({"ok": False, "error": "auth_required"}), 401
        if path == "/" or not path.startswith("/api"):
            return redirect("/login")
        return jsonify({"ok": False, "error": "auth_required"}), 401

    @server.get("/login")
    def login_page():  # type: ignore[no-redef]
        if is_unlocked():
            return redirect("/")
        owner = os.getenv("OWNER_LABEL") or "kişisel"
        return _login_html(owner)

    @server.get("/api/auth/status")
    def auth_status():  # type: ignore[no-redef]
        return jsonify(
            {
                "ok": True,
                "unlocked": is_unlocked(),
                "pin_required": pin_configured(),
            }
        )

    @server.post("/api/auth/unlock")
    def auth_unlock():  # type: ignore[no-redef]
        body = request.get_json(silent=True) or {}
        pin = body.get("pin") or request.form.get("pin") or ""
        if not pin_configured():
            return jsonify({"ok": False, "error": "ACCESS_PIN tanımlı değil"}), 503
        if not verify_pin(str(pin)):
            return jsonify({"ok": False, "error": "Yanlış PIN"}), 401
        session.permanent = True
        issue_session()
        return jsonify({"ok": True, "unlocked": True})

    @server.post("/api/auth/logout")
    def auth_logout():  # type: ignore[no-redef]
        clear_session()
        return jsonify({"ok": True, "unlocked": False})

    @server.get("/manifest.webmanifest")
    def manifest():  # type: ignore[no-redef]
        resp = jsonify(
            {
                "id": "/",
                "name": "Tesla Pulse",
                "short_name": "Pulse",
                "start_url": "/",
                "scope": "/",
                "display": "standalone",
                "orientation": "landscape",
                "background_color": "#07080a",
                "theme_color": "#07080a",
                "description": "Kişisel Tesla Pulse küme ekranı",
                "icons": [
                    {
                        "src": "/assets/icons/icon-192.png",
                        "sizes": "192x192",
                        "type": "image/png",
                        "purpose": "any maskable",
                    },
                    {
                        "src": "/assets/icons/icon-512.png",
                        "sizes": "512x512",
                        "type": "image/png",
                        "purpose": "any maskable",
                    },
                ],
            }
        )
        resp.headers["Content-Type"] = "application/manifest+json"
        return resp

    @server.get("/sw.js")
    def service_worker():  # type: ignore[no-redef]
        sw_path = os.path.join(os.path.dirname(__file__), "assets", "sw.js")
        with open(sw_path, "r", encoding="utf-8") as fh:
            body = fh.read()
        resp = server.make_response(body)
        resp.headers["Content-Type"] = "application/javascript; charset=utf-8"
        resp.headers["Service-Worker-Allowed"] = "/"
        resp.headers["Cache-Control"] = "no-cache"
        return resp


def _login_html(owner: str) -> str:
    # Minimal private gate — no app shell until PIN succeeds
    return f"""<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="apple-mobile-web-app-title" content="Pulse" />
  <meta name="theme-color" content="#07080a" />
  <link rel="manifest" href="/manifest.webmanifest" />
  <link rel="apple-touch-icon" href="/assets/icons/apple-touch-icon.png" />
  <link rel="icon" type="image/png" sizes="192x192" href="/assets/icons/icon-192.png" />
  <title>Tesla Pulse · Kilit</title>
  <style>
    :root {{
      color-scheme: dark;
      --bg:#07080a; --text:#f5f5f7; --muted:rgba(245,245,247,.5); --line:rgba(255,255,255,.12);
      --accent:#32d74b; --danger:#ff453a;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
    }}
    * {{ box-sizing: border-box; }}
    html, body {{
      margin:0; min-height:100%; height:100%;
      background:
        radial-gradient(ellipse 60% 50% at 50% 0%, #161a22 0%, transparent 55%),
        var(--bg);
      color: var(--text);
    }}
    body {{
      display:grid; place-items:center; padding:1.25rem;
    }}
    .card {{
      width:min(100%, 380px);
      text-align:center;
    }}
    .app-ico {{
      width:72px; height:72px; border-radius:18px; margin:0 auto 1rem;
      box-shadow:0 10px 30px rgba(0,0,0,.45);
    }}
    .brand {{
      font-size: .78rem; letter-spacing: .18em; text-transform: uppercase;
      color: var(--muted); margin-bottom: .85rem;
    }}
    h1 {{
      margin:0 0 .35rem; font-size:1.7rem; font-weight:600; letter-spacing:-.03em;
    }}
    .sub {{
      margin:0 0 1.25rem; color:var(--muted); font-size:.95rem; line-height:1.4;
    }}
    form {{ display:flex; flex-direction:column; gap:.75rem; }}
    input[type=password], input[type=tel] {{
      width:100%; border-radius:14px; border:1px solid var(--line);
      background:rgba(255,255,255,.04); color:var(--text);
      font-size:1.45rem; letter-spacing:.35em; text-align:center;
      padding:.9rem 1rem; outline:none;
    }}
    input:focus {{ border-color: rgba(50,215,75,.55); }}
    button {{
      border:none; border-radius:14px; padding:.95rem 1rem;
      background:var(--accent); color:#041208; font-weight:700; font-size:1rem;
      cursor:pointer;
    }}
    button:disabled {{ opacity:.5; cursor:wait; }}
    .err {{
      min-height:1.2rem; color:var(--danger); font-size:.88rem; margin-top:.35rem;
    }}
    .install {{
      margin-top:1.35rem; text-align:left;
      padding:0.9rem 1rem; border-radius:14px;
      border:1px solid var(--line); background:rgba(255,255,255,.03);
      font-size:.82rem; color:var(--muted); line-height:1.45;
    }}
    .install strong {{ color:var(--text); font-weight:600; }}
    .install ol {{ margin:.4rem 0 0 1.1rem; padding:0; }}
    .install li {{ margin:.25rem 0; }}
  </style>
</head>
<body>
  <div class="card">
    <img class="app-ico" src="/assets/icons/icon-192.png" alt="Pulse" />
    <div class="brand">Tesla Pulse</div>
    <h1>Özel erişim</h1>
    <p class="sub">Sadece senin telefonun · PIN ile aç ({owner}).</p>
    <form id="f">
      <input id="pin" name="pin" type="tel" inputmode="numeric" pattern="[0-9]*"
             autocomplete="one-time-code" maxlength="8" placeholder="••••" autofocus />
      <button type="submit" id="go">Kilidi aç</button>
      <div class="err" id="err"></div>
    </form>
    <div class="install">
      <strong>Telefona uygulama gibi ekle</strong>
      <ol>
        <li><strong>iPhone:</strong> Safari ile aç → Paylaş (□↑) → <em>Ana Ekrana Ekle</em></li>
        <li><strong>Android:</strong> Chrome ile aç → menü ⋮ → <em>Uygulamayı yükle</em> / <em>Ana ekrana ekle</em></li>
        <li>Ana ekrandaki <em>Pulse</em> ikonundan aç (tam ekran)</li>
      </ol>
    </div>
  </div>
  <script>
    if ('serviceWorker' in navigator) {{
      navigator.serviceWorker.register('/sw.js', {{ scope: '/' }}).catch(() => {{}});
    }}
    const f = document.getElementById('f');
    const err = document.getElementById('err');
    const go = document.getElementById('go');
    f.addEventListener('submit', async (e) => {{
      e.preventDefault();
      err.textContent = '';
      go.disabled = true;
      try {{
        const pin = document.getElementById('pin').value;
        const r = await fetch('/api/auth/unlock', {{
          method: 'POST',
          headers: {{'Content-Type': 'application/json'}},
          credentials: 'same-origin',
          body: JSON.stringify({{ pin }})
        }});
        const j = await r.json();
        if (!r.ok || !j.ok) {{
          err.textContent = j.error || 'Yanlış PIN';
          go.disabled = false;
          return;
        }}
        location.replace('/');
      }} catch (ex) {{
        err.textContent = 'Bağlantı hatası';
        go.disabled = false;
      }}
    }});
  </script>
</body>
</html>
"""
