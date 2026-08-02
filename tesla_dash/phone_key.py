"""Phone Key — build Tesla VCSEC add-key BLE payloads for Web Bluetooth clients."""

from __future__ import annotations

import hashlib
import os
from typing import Any

from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization

from tesla_dash.tesla.ble import normalize_vin, valid_vin

SERVICE_UUID = "00000211-b2d1-43f0-9b88-960cebf8b91e"
WRITE_UUID = "00000212-b2d1-43f0-9b88-960cebf8b91e"
READ_UUID = "00000213-b2d1-43f0-9b88-960cebf8b91e"


def ble_local_name(vin: str) -> str:
    """Official Tesla BLE local name: S + sha1(vin)[:8 hex] + C."""
    digest = hashlib.sha1(normalize_vin(vin).encode("utf-8")).hexdigest()
    return f"S{digest[:16]}C"


def ble_display_names(vin: str) -> list[str]:
    vin_n = normalize_vin(vin)
    names = [ble_local_name(vin_n), f"Tesla {vin_n[-6:]}", f"Tesla{vin_n[-6:]}"]
    # unique preserve order
    out: list[str] = []
    for n in names:
        if n not in out:
            out.append(n)
    return out


def _parse_public_key(public_key_hex: str) -> bytes:
    raw = bytes.fromhex((public_key_hex or "").strip().replace(" ", ""))
    if len(raw) != 65 or raw[0] != 0x04:
        raise ValueError("Public key X9.62 uncompressed (65 bytes, starts with 0x04) olmalı.")
    # Validate curve point
    ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), raw)
    return raw


def build_add_key_payload(
    public_key_hex: str,
    *,
    role: str = "owner",
    form_factor: str = "android",
) -> bytes:
    """Build length-prefixed ToVCSECMessage (SIGNATURE_TYPE_PRESENT_KEY).

    Same envelope as tesla-control `add-key-request` / Vehicle.SendAddKeyRequest.
    """
    from tesla_fleet_api.tesla.vehicle.proto.keys_pb2 import Role
    from tesla_fleet_api.tesla.vehicle.proto.vcsec_pb2 import (
        KeyFormFactor,
        KeyMetadata,
        PermissionChange,
        PublicKey,
        SignatureType,
        SignedMessage,
        ToVCSECMessage,
        UnsignedMessage,
        WhitelistOperation,
    )

    pub = _parse_public_key(public_key_hex)
    role_e = Role.ROLE_OWNER if role.lower() == "owner" else Role.ROLE_DRIVER
    form_map = {
        "android": KeyFormFactor.KEY_FORM_FACTOR_ANDROID_DEVICE,
        "ios": KeyFormFactor.KEY_FORM_FACTOR_IOS_DEVICE,
        "cloud": KeyFormFactor.KEY_FORM_FACTOR_CLOUD_KEY,
    }
    form_e = form_map.get(form_factor.lower(), KeyFormFactor.KEY_FORM_FACTOR_ANDROID_DEVICE)

    unsigned = UnsignedMessage(
        WhitelistOperation=WhitelistOperation(
            addKeyToWhitelistAndAddPermissions=PermissionChange(
                key=PublicKey(PublicKeyRaw=pub),
                keyRole=role_e,
            ),
            metadataForKey=KeyMetadata(keyFormFactor=form_e),
        )
    )
    envelope = ToVCSECMessage(
        signedMessage=SignedMessage(
            protobufMessageAsBytes=unsigned.SerializeToString(),
            signatureType=SignatureType.SIGNATURE_TYPE_PRESENT_KEY,
        )
    )
    body = envelope.SerializeToString()
    return len(body).to_bytes(2, "big") + body


def decode_vehicle_status(payload_hex: str) -> dict[str, Any]:
    """Best-effort decode of FromVCSECMessage (length prefix optional)."""
    from tesla_fleet_api.tesla.vehicle.proto.vcsec_pb2 import FromVCSECMessage, OperationStatus_E

    raw = bytes.fromhex((payload_hex or "").strip().replace(" ", ""))
    if len(raw) >= 2:
        declared = int.from_bytes(raw[:2], "big")
        if declared + 2 == len(raw):
            raw = raw[2:]
    msg = FromVCSECMessage()
    msg.ParseFromString(raw)
    status = msg.commandStatus
    op = status.operationStatus
    wait = op == OperationStatus_E.OPERATIONSTATUS_WAIT
    ok = False
    if status.HasField("whitelistOperationStatus"):
        wop = status.whitelistOperationStatus.operationStatus
        ok = wop == OperationStatus_E.OPERATIONSTATUS_OK
        wait = wait or wop == OperationStatus_E.OPERATIONSTATUS_WAIT
    return {
        "ok": ok,
        "wait_for_card": wait,
        "operation_status": int(op),
        "raw_fields": str(msg),
    }


def owner_vin() -> str:
    vin = normalize_vin(os.getenv("TESLA_VIN") or os.getenv("OWNER_VIN") or "")
    return vin if valid_vin(vin) else ""


def export_private_pem(private_jwk_d_b64url: str, public_x_b64url: str, public_y_b64url: str) -> str:
    """Optional helper — not used by Web path; kept for laptop export later."""
    raise NotImplementedError


def keygen_server_side() -> dict[str, str]:
    """Generate a P-256 keypair (server). Prefer client Web Crypto; this is fallback."""
    priv = ec.generate_private_key(ec.SECP256R1())
    pub = priv.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    pem = priv.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode("ascii")
    return {"public_key_hex": pub.hex(), "private_pem": pem}


def phone_key_html(vin: str = "") -> str:
    vin_n = normalize_vin(vin) if vin else owner_vin()
    vin_attr = vin_n if valid_vin(vin_n) else ""
    return f"""<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="theme-color" content="#07080a" />
  <title>Pulse · Phone Key</title>
  <link rel="manifest" href="/manifest.webmanifest" />
  <style>
    :root {{
      --bg: #07080a; --card: #14161c; --text: #f4f5f7; --muted: rgba(244,245,247,.55);
      --cyan: #64d2ff; --ok: #30d158; --err: #ff453a; --warn: #ffd60a;
      --sf: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0; min-height: 100dvh; font-family: var(--sf); color: var(--text);
      background:
        radial-gradient(ellipse 80% 50% at 50% -10%, rgba(100,210,255,.18), transparent 55%),
        linear-gradient(180deg, #0c1018 0%, var(--bg) 45%, #050608 100%);
      padding: max(1rem, env(safe-area-inset-top)) 1.1rem max(1.5rem, env(safe-area-inset-bottom));
    }}
    .wrap {{ max-width: 440px; margin: 0 auto; }}
    .brand {{ letter-spacing: .28em; font-size: .72rem; font-weight: 700; color: var(--cyan); }}
    h1 {{ margin: .35rem 0 .5rem; font-size: 1.55rem; letter-spacing: -.03em; }}
    .lead {{ color: var(--muted); font-size: .9rem; line-height: 1.45; margin: 0 0 1rem; }}
    .card {{
      background: rgba(20,22,28,.92); border: 1px solid rgba(255,255,255,.08);
      border-radius: 1.15rem; padding: 1.1rem 1rem; margin-bottom: 1rem;
      box-shadow: 0 20px 50px rgba(0,0,0,.35);
    }}
    label {{ display:block; font-size:.7rem; font-weight:650; letter-spacing:.06em; text-transform:uppercase; color: var(--muted); margin-bottom:.35rem; }}
    input {{
      width:100%; border:1px solid rgba(255,255,255,.12); background:rgba(0,0,0,.35);
      color:var(--text); border-radius:.75rem; padding:.8rem .85rem; font-size:1rem;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing:.06em;
    }}
    input:focus {{ outline:none; border-color: var(--cyan); }}
    .btn {{
      display:block; width:100%; margin-top:.85rem; border:none; border-radius:.85rem;
      padding:.95rem 1rem; font-size:1rem; font-weight:700; cursor:pointer;
      background: linear-gradient(135deg, #3aa0ff, #64d2ff); color:#041018;
    }}
    .btn:disabled {{ opacity:.45; cursor:not-allowed; }}
    .btn.ghost {{
      background: transparent; color: var(--muted); border:1px solid rgba(255,255,255,.12);
      font-weight:600; font-size:.88rem; margin-top:.55rem;
    }}
    .support {{ font-size:.8rem; line-height:1.4; margin:.75rem 0 0; padding:.65rem .75rem; border-radius:.7rem; }}
    .support.ok {{ background: rgba(48,209,88,.12); color:#8dffb0; }}
    .support.bad {{ background: rgba(255,69,58,.12); color:#ff8a80; }}
    #pk-status {{
      margin-top: .85rem; padding: .75rem .8rem; border-radius: .75rem;
      background: rgba(255,255,255,.05); font-size: .9rem; line-height: 1.4; min-height: 2.8rem;
    }}
    #pk-status[data-kind="ok"] {{ background: rgba(48,209,88,.14); color: #b6ffcb; }}
    #pk-status[data-kind="err"] {{ background: rgba(255,69,58,.14); color: #ffb4ae; }}
    #pk-status[data-kind="warn"] {{ background: rgba(255,214,10,.12); color: #ffe566; }}
    .steps {{ display:grid; gap:.45rem; margin: 1rem 0; }}
    .step {{
      display:flex; gap:.65rem; align-items:flex-start; padding:.65rem .7rem;
      border-radius:.7rem; background: rgba(255,255,255,.04); color: var(--muted); font-size:.84rem;
    }}
    .step.on {{ background: rgba(48,209,88,.12); color: #dfffea; }}
    .n {{
      width:1.45rem; height:1.45rem; border-radius:50%; display:grid; place-items:center;
      font-size:.72rem; font-weight:700; background: rgba(255,255,255,.08); flex-shrink:0;
    }}
    .step.on .n {{ background: var(--ok); color:#041208; }}
    #pk-log {{
      margin-top:.75rem; max-height: 180px; overflow:auto; font-family: ui-monospace, monospace;
      font-size:.68rem; line-height:1.4; color: var(--muted);
    }}
    .log-line {{ padding:.15rem 0; border-bottom:1px solid rgba(255,255,255,.04); }}
    .log-line.ok {{ color: #8dffb0; }}
    .log-line.err {{ color: #ff8a80; }}
    .log-line.warn {{ color: #ffe566; }}
    a.back {{ color: var(--muted); font-size:.85rem; text-decoration:none; }}
    a.back:hover {{ color: var(--cyan); }}
  </style>
</head>
<body>
  <div class="wrap">
    <a class="back" href="/">← Pulse HUD</a>
    <div class="brand" style="margin-top:.85rem">TESLA PULSE</div>
    <h1>Phone Key</h1>
    <p class="lead" id="pk-lead">
      Telefon Bluetooth ile araca <strong>add-key-request</strong> gönderir.
      Sonra Key Card’ı <strong>orta konsola</strong> koy — ekranda Pair / Confirm çıkar.
    </p>

    <!-- iPhone/iPad: Safari has no Web Bluetooth → Playgrounds native app -->
    <div class="card" id="ios-panel" hidden>
      <div class="howto-title" style="color:var(--cyan);font-size:.78rem;font-weight:700;letter-spacing:.06em;text-transform:uppercase;margin-bottom:.45rem">iPhone uygulaması</div>
      <p class="lead" style="margin:0 0 .75rem"><strong>Tek uygulama:</strong> BLE Pair + Cluster aynı yerelde. <strong>WebView yok</strong> — web’den veri beklenmez. Swift Playgrounds → Run ▶ ile Ana Ekran’a kurulur.</p>
      <ol style="margin:0 0 .9rem;padding-left:1.15rem;color:rgba(255,255,255,.88);font-size:.88rem;line-height:1.45">
        <li>App Store → <strong>Swift Playgrounds</strong> (iPhone)</li>
        <li>Zip indir → Dosyalar → <code>PulsePhoneKey.swiftpm</code> → basılı tut → Paylaş → Playgrounds</li>
        <li>Signing → <strong>Run ▶</strong> → sürüm <code>build-27-tight</code></li>
        <li>Pair Vehicle → Key Card konsola → <strong>Cluster’i ac</strong> (uygulama içi · yatay)</li>
      </ol>
      <a class="btn" href="/downloads/PulsePhoneKey-playground-build27.zip" style="text-decoration:none;text-align:center">iPhone · build-27 sıkı triad HUD</a>
      <a class="btn ghost" href="/downloads/PulsePhoneKey-playground.zip" style="display:block;text-align:center;text-decoration:none;box-sizing:border-box">Aynı zip</a>
      <a class="btn ghost" href="/downloads/PulsePhoneKey-swift-files.zip" style="display:block;text-align:center;text-decoration:none;box-sizing:border-box">Zip açılmazsa · sadece Swift dosyaları</a>
      <p class="support" style="background:rgba(255,214,10,.12);color:#ffe566;margin-top:.75rem">
        <strong>SÜRÜM: build-27-tight</strong> · sıkı triad · küçük harita · boşluk yok · çökmesiz
      </p>
      <a class="btn ghost" href="https://apps.apple.com/app/swift-playgrounds/id908519492" style="display:block;text-align:center;text-decoration:none;box-sizing:border-box">Swift Playgrounds · App Store</a>
      <hr style="border:none;border-top:1px solid rgba(255,255,255,.08);margin:1rem 0" />
      <div style="font-size:.72rem;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin-bottom:.45rem">Alternatif · Tesla uygulaması</div>
      <a class="btn ghost" id="ios-open-tesla" href="tesla://">Tesla uygulamasını aç</a>
      <a class="btn ghost" id="ios-open-security" href="tesla://security" style="display:block;text-align:center;text-decoration:none;box-sizing:border-box">Security → Phone Key</a>
      <p class="support ok" style="margin-top:.85rem">
        Playgrounds = gerçek iPhone uygulaması · Safari değil.
        Repo: <code>ios/PulsePhoneKey.swiftpm</code> · <code>IPHONE.md</code>
      </p>
    </div>

    <div class="card" id="android-panel">
      <a class="btn" id="apk-download" href="/downloads/TeslaPulse.apk" style="text-decoration:none;text-align:center;margin-top:0">
        Android APK indir · Tesla Pulse (tam uygulama)
      </a>
      <p class="support ok" style="margin-top:.75rem">
        Tam uygulama: PIN → BLE + Key Card Pair → cluster HUD.
        Kur → PIN <strong>428462</strong> → VIN → eşleştir → kartı <strong>konsola</strong> koy → HUD.
      </p>
      <hr style="border:none;border-top:1px solid rgba(255,255,255,.08);margin:1rem 0" />
      <div style="font-size:.72rem;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin-bottom:.45rem">Tarayıcıdan dene (Chrome)</div>
      <label for="pk-vin">VIN</label>
      <input id="pk-vin" maxlength="17" value="{vin_attr}" placeholder="17 karakter VIN" autocomplete="off" />
      <button class="btn" id="pk-go" type="button">Web Bluetooth ile eşleştir</button>
      <button class="btn ghost" id="pk-reset" type="button">Anahtarı sıfırla</button>
      <div id="pk-support" class="support">Kontrol ediliyor…</div>
      <div id="pk-status" data-kind="info">Hazır. Araç yakında ve uyanık olsun.</div>
    </div>

    <div class="steps" id="pk-steps">
      <div class="step on"><span class="n">1</span><span>Bluetooth ile Tesla’yı seç ve isteği gönder</span></div>
      <div class="step" id="pk-step-card"><span class="n">2</span><span>Key Card → <strong>konsol okuyucu</strong> (telefona değil)</span></div>
      <div class="step" id="pk-step-done"><span class="n">3</span><span>Araç ekranında Pair / Confirm</span></div>
    </div>

    <div class="card" id="pk-log-card">
      <div style="font-size:.72rem;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin-bottom:.35rem">Log</div>
      <div id="pk-log"></div>
    </div>
  </div>
  <script src="/assets/phone-key.js"></script>
</body>
</html>"""


def register_phone_key(server) -> None:
    """Register /phone-key UI and payload APIs on the Flask server."""
    from flask import jsonify, request, send_file, abort

    @server.get("/phone-key")
    def phone_key_page():  # type: ignore[no-redef]
        from tesla_dash.auth import is_unlocked
        from flask import redirect

        if not is_unlocked():
            return redirect("/login")
        vin = (request.args.get("vin") or owner_vin()).strip()
        return phone_key_html(vin)

    def _send_apk(filename: str):
        from tesla_dash.auth import is_unlocked
        from flask import redirect

        if not is_unlocked():
            return redirect("/login")
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(root, "releases", filename)
        if not os.path.isfile(path):
            # fall back to the other name
            alt = "TeslaPulse.apk" if filename == "PulsePhoneKey.apk" else "PulsePhoneKey.apk"
            path = os.path.join(root, "releases", alt)
            if not os.path.isfile(path):
                abort(404)
            filename = alt
        return send_file(
            path,
            mimetype="application/vnd.android.package-archive",
            as_attachment=True,
            download_name=filename,
        )

    @server.get("/downloads/PulsePhoneKey.apk")
    def download_android_apk():  # type: ignore[no-redef]
        return _send_apk("TeslaPulse.apk")

    @server.get("/downloads/TeslaPulse.apk")
    def download_tesla_pulse_apk():  # type: ignore[no-redef]
        return _send_apk("TeslaPulse.apk")

    def _send_release_zip(filename: str, *, public: bool = False):
        from tesla_dash.auth import is_unlocked
        from flask import redirect

        # Playgrounds iPhone zip: allow direct link without PIN
        if not public and not is_unlocked():
            return redirect("/login")
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(root, "releases", filename)
        if not os.path.isfile(path):
            abort(404)
        return send_file(
            path,
            mimetype="application/zip",
            as_attachment=True,
            download_name=filename,
        )

    @server.get("/downloads/PulsePhoneKey-playground.zip")
    def download_playgrounds_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build7.zip")
    def download_playgrounds_build7_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build8.zip")
    def download_playgrounds_build8_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build9.zip")
    def download_playgrounds_build9_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build10.zip")
    def download_playgrounds_build10_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build11.zip")
    def download_playgrounds_build11_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build12.zip")
    def download_playgrounds_build12_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build13.zip")
    def download_playgrounds_build13_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build14.zip")
    def download_playgrounds_build14_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build15.zip")
    def download_playgrounds_build15_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build16.zip")
    def download_playgrounds_build16_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build17.zip")
    def download_playgrounds_build17_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build18.zip")
    def download_playgrounds_build18_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build19.zip")
    def download_playgrounds_build19_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build20.zip")
    def download_playgrounds_build20_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build21.zip")
    def download_playgrounds_build21_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build22.zip")
    def download_playgrounds_build22_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build23.zip")
    def download_playgrounds_build23_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build24.zip")
    def download_playgrounds_build24_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build25.zip")
    def download_playgrounds_build25_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build26.zip")
    def download_playgrounds_build26_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-playground-build27.zip")
    def download_playgrounds_build27_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-playground-build27.zip", public=True)

    @server.get("/downloads/PulsePhoneKey-swift-files.zip")
    def download_swift_files_zip():  # type: ignore[no-redef]
        return _send_release_zip("PulsePhoneKey-swift-files.zip", public=True)

    @server.post("/api/phone-key/payload")
    def phone_key_payload():  # type: ignore[no-redef]
        body = request.get_json(silent=True) or {}
        vin = normalize_vin(body.get("vin") or owner_vin())
        if not valid_vin(vin):
            return jsonify({"ok": False, "error": "Geçerli VIN gerekli"}), 400
        try:
            payload = build_add_key_payload(
                body.get("public_key_hex") or "",
                role=str(body.get("role") or "owner"),
                form_factor=str(body.get("form_factor") or "android"),
            )
        except Exception as exc:  # noqa: BLE001
            return jsonify({"ok": False, "error": str(exc)}), 400
        return jsonify(
            {
                "ok": True,
                "vin": vin,
                "payload_hex": payload.hex(),
                "ble_names": ble_display_names(vin),
                "service_uuid": SERVICE_UUID,
                "write_uuid": WRITE_UUID,
                "read_uuid": READ_UUID,
            }
        )

    @server.post("/api/phone-key/decode")
    def phone_key_decode():  # type: ignore[no-redef]
        body = request.get_json(silent=True) or {}
        try:
            info = decode_vehicle_status(body.get("payload_hex") or "")
            info["ok_parse"] = True
            return jsonify(info)
        except Exception as exc:  # noqa: BLE001
            return jsonify({"ok": False, "wait_for_card": False, "error": str(exc)})
