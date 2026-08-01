/**
 * Pulse Phone Key — Web Bluetooth VCSEC add-key-request
 * Android Chrome / Edge only. iOS Safari has no Web Bluetooth.
 */
(function () {
  "use strict";

  var SERVICE = "00000211-b2d1-43f0-9b88-960cebf8b91e";
  var WRITE = "00000212-b2d1-43f0-9b88-960cebf8b91e";
  var READ = "00000213-b2d1-43f0-9b88-960cebf8b91e";
  var KEY_STORE = "pulse_phone_key_v1";

  var els = {};
  var state = {
    vin: "",
    publicHex: "",
    privateJwk: null,
    device: null,
    server: null,
    writeChar: null,
    status: "idle",
  };

  function $(id) {
    return document.getElementById(id);
  }

  function log(msg, cls) {
    var box = els.log;
    if (!box) return;
    var line = document.createElement("div");
    line.className = "log-line" + (cls ? " " + cls : "");
    line.textContent = msg;
    box.prepend(line);
  }

  function setStatus(text, kind) {
    if (!els.status) return;
    els.status.textContent = text;
    els.status.dataset.kind = kind || "info";
  }

  function b64urlFromBuf(buf) {
    var bytes = new Uint8Array(buf);
    var s = "";
    for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }

  function bufFromB64url(s) {
    s = s.replace(/-/g, "+").replace(/_/g, "/");
    while (s.length % 4) s += "=";
    var bin = atob(s);
    var out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  function hexFromBuf(buf) {
    return Array.from(new Uint8Array(buf))
      .map(function (b) {
        return b.toString(16).padStart(2, "0");
      })
      .join("");
  }

  function bufFromHex(hex) {
    hex = (hex || "").replace(/\s+/g, "");
    var out = new Uint8Array(hex.length / 2);
    for (var i = 0; i < out.length; i++) out[i] = parseInt(hex.substr(i * 2, 2), 16);
    return out;
  }

  async function ensureKey() {
    try {
      var saved = JSON.parse(localStorage.getItem(KEY_STORE) || "null");
      if (saved && saved.privateJwk && saved.publicHex) {
        state.privateJwk = saved.privateJwk;
        state.publicHex = saved.publicHex;
        log("Kayıtlı anahtar yüklendi · " + saved.publicHex.slice(0, 18) + "…");
        return;
      }
    } catch (e) {}

    var pair = await crypto.subtle.generateKey(
      { name: "ECDSA", namedCurve: "P-256" },
      true,
      ["sign", "verify"]
    );
    var privJwk = await crypto.subtle.exportKey("jwk", pair.privateKey);
    var pubJwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
    var x = bufFromB64url(pubJwk.x);
    var y = bufFromB64url(pubJwk.y);
    var uncompressed = new Uint8Array(65);
    uncompressed[0] = 0x04;
    uncompressed.set(x, 1);
    uncompressed.set(y, 33);
    state.privateJwk = privJwk;
    state.publicHex = hexFromBuf(uncompressed);
    localStorage.setItem(
      KEY_STORE,
      JSON.stringify({ privateJwk: privJwk, publicHex: state.publicHex, created: Date.now() })
    );
    log("Yeni P-256 anahtar üretildi (telefonda saklandı)");
  }

  async function apiPayload(vin) {
    var r = await fetch("/api/phone-key/payload", {
      method: "POST",
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        vin: vin,
        public_key_hex: state.publicHex,
        role: "owner",
        form_factor: /iPhone|iPad|iOS/i.test(navigator.userAgent) ? "ios" : "android",
      }),
    });
    var j = await r.json();
    if (!r.ok || !j.ok) throw new Error(j.error || "Payload alınamadı");
    return j;
  }

  function supported() {
    return !!(navigator.bluetooth && navigator.bluetooth.requestDevice);
  }

  async function connectAndPair() {
    if (!supported()) {
      setStatus("Bu tarayıcıda Web Bluetooth yok. Android Chrome kullan.", "err");
      return;
    }
    var vin = (els.vin.value || "").replace(/\s+/g, "").toUpperCase();
    if (vin.length !== 17) {
      setStatus("Geçerli 17 karakter VIN gir.", "err");
      return;
    }
    state.vin = vin;
    els.go.disabled = true;
    setStatus("Anahtar hazırlanıyor…", "info");
    try {
      await ensureKey();
      var meta = await apiPayload(vin);
      var payload = bufFromHex(meta.payload_hex);
      log("add-key payload " + payload.length + " byte · BLE adları: " + (meta.ble_names || []).join(", "));

      setStatus("Bluetooth cihaz seç — Tesla’yı bul", "info");
      var filters = (meta.ble_names || []).map(function (n) {
        return { name: n };
      });
      filters.push({ namePrefix: "Tesla" });
      filters.push({ namePrefix: "S" });

      var device;
      try {
        device = await navigator.bluetooth.requestDevice({
          filters: filters,
          optionalServices: [SERVICE, "battery_service"],
        });
      } catch (e1) {
        log("Filtreli tarama başarısız, tüm cihazlar…", "warn");
        device = await navigator.bluetooth.requestDevice({
          acceptAllDevices: true,
          optionalServices: [SERVICE, "battery_service"],
        });
      }

      state.device = device;
      device.addEventListener("gattserverdisconnected", function () {
        setStatus("BLE koptu", "warn");
        log("GATT disconnected", "warn");
      });

      setStatus("Bağlanıyor: " + (device.name || "Tesla") + "…", "info");
      var server = await device.gatt.connect();
      state.server = server;
      var service = await server.getPrimaryService(SERVICE);
      var writeChar = await service.getCharacteristic(WRITE);
      state.writeChar = writeChar;

      try {
        var readChar = await service.getCharacteristic(READ);
        await readChar.startNotifications();
        readChar.addEventListener("characteristicvaluechanged", onNotify);
        log("Bildirimler açık (kart onayı dinleniyor)");
      } catch (e) {
        log("Notify açılamadı (yine de istek gönderilecek): " + e.message, "warn");
      }

      setStatus("add-key-request gönderiliyor…", "info");
      // Chunk if needed (MTU ~20–512)
      var chunk = 180;
      for (var i = 0; i < payload.length; i += chunk) {
        var part = payload.slice(i, i + chunk);
        if (writeChar.writeValueWithResponse) {
          await writeChar.writeValueWithResponse(part);
        } else {
          await writeChar.writeValue(part);
        }
      }
      log("İstek gönderildi ✓ — şimdi Key Card’ı KONSOLA koy", "ok");
      setStatus("Kartı orta konsola koy → ekranda Pair / Confirm", "ok");
      els.stepCard.classList.add("on");
    } catch (err) {
      var msg = (err && err.message) || String(err);
      if (/cancel|chooser|user/i.test(msg)) {
        setStatus("Cihaz seçimi iptal edildi", "warn");
      } else {
        setStatus("Hata: " + msg, "err");
      }
      log(msg, "err");
    } finally {
      els.go.disabled = false;
    }
  }

  function onNotify(ev) {
    try {
      var hex = hexFromBuf(ev.target.value.buffer);
      log("Araç yanıtı: " + hex.slice(0, 48) + (hex.length > 48 ? "…" : ""));
      fetch("/api/phone-key/decode", {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ payload_hex: hex }),
      })
        .then(function (r) {
          return r.json();
        })
        .then(function (j) {
          if (!j.ok && j.wait_for_card) {
            setStatus("Araç kart bekliyor — Key Card’ı konsola koy", "ok");
            log("OPERATIONSTATUS_WAIT → Pair ekranı gelmeli", "ok");
          } else if (j.ok) {
            setStatus("Anahtar onaylandı! Phone Key eklendi.", "ok");
            log("Whitelist OK", "ok");
            els.stepDone.classList.add("on");
          } else if (j.error) {
            log("Decode: " + j.error, "warn");
          }
        })
        .catch(function () {});
    } catch (e) {}
  }

  function resetKey() {
    localStorage.removeItem(KEY_STORE);
    state.privateJwk = null;
    state.publicHex = "";
    log("Anahtar silindi — bir sonraki eşleşmede yeni üretilecek", "warn");
    setStatus("Anahtar sıfırlandı", "warn");
  }

  function isIOS() {
    return /iPhone|iPad|iPod/i.test(navigator.userAgent)
      || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
  }

  function setupIOS() {
    var iosPanel = $("ios-panel");
    var androidPanel = $("android-panel");
    var steps = $("pk-steps");
    var logCard = $("pk-log-card");
    var lead = $("pk-lead");
    if (iosPanel) iosPanel.hidden = false;
    if (androidPanel) androidPanel.hidden = true;
    if (steps) steps.hidden = true;
    if (logCard) logCard.hidden = true;
    if (lead) {
      lead.innerHTML =
        "<strong>iPhone:</strong> Safari Web Bluetooth desteklemez. " +
        "Aşağıdaki Tesla uygulaması yolunu kullan — Pair ekranı böyle çıkar.";
    }

    var openTesla = $("ios-open-tesla");
    if (openTesla) {
      openTesla.addEventListener("click", function (ev) {
        ev.preventDefault();
        // Try a few known schemes; fall back to App Store after a beat
        var schemes = [
          "tesla://",
          "tesla://security",
          "tesla://vehicle/phoneKey",
          "tesla://phonekey",
        ];
        var i = 0;
        function tryNext() {
          if (i >= schemes.length) {
            window.location.href = "https://apps.apple.com/app/tesla/id582007658";
            return;
          }
          var s = schemes[i++];
          var t = Date.now();
          window.location.href = s;
          setTimeout(function () {
            // If still visible quickly, try next scheme
            if (Date.now() - t < 1600 && !document.hidden) tryNext();
          }, 700);
        }
        tryNext();
      });
    }
  }

  function init() {
    els.vin = $("pk-vin");
    els.go = $("pk-go");
    els.reset = $("pk-reset");
    els.status = $("pk-status");
    els.log = $("pk-log");
    els.stepCard = $("pk-step-card");
    els.stepDone = $("pk-step-done");
    els.support = $("pk-support");

    if (isIOS()) {
      setupIOS();
      return;
    }

    if (!supported()) {
      els.support.textContent =
        "⚠️ Web Bluetooth yok. Android’de Chrome kullan. iPhone’da /phone-key Tesla uygulamasına yönlendirir.";
      els.support.className = "support bad";
      if (els.go) els.go.disabled = true;
    } else {
      els.support.textContent = "Web Bluetooth hazır (Chrome/Edge). Araç yakında olsun.";
      els.support.className = "support ok";
    }

    if (els.go) els.go.addEventListener("click", connectAndPair);
    if (els.reset) els.reset.addEventListener("click", resetKey);
    ensureKey().catch(function (e) {
      log("Anahtar üretilemedi: " + e.message, "err");
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
