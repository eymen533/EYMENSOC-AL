/**
 * Fullscreen side panels + restore via translucent speed HUD.
 * Tap left/right panel → fullscreen that side.
 * Tap top-right fs-hud → back to triad (center speed + both sides).
 */
(function () {
  "use strict";

  var TAP_MAX_MOVE = 14;
  var TAP_MAX_MS = 420;

  function cluster() {
    return document.getElementById("cluster");
  }

  function invalidateMaps() {
    try {
      window.dispatchEvent(new Event("resize"));
    } catch (_) {}
    document.querySelectorAll(".leaflet-container").forEach(function (el) {
      if (el._leaflet_map && el._leaflet_map.invalidateSize) {
        el._leaflet_map.invalidateSize();
      }
    });
  }

  function setFullscreen(side) {
    var root = cluster();
    if (!root) return;
    root.classList.remove("fs-left", "fs-right");
    if (side === "left" || side === "right") {
      root.classList.add("fs-" + side);
    }
    setTimeout(invalidateMaps, 80);
    setTimeout(invalidateMaps, 320);
  }

  function clearFullscreen() {
    var root = cluster();
    if (!root) return;
    root.classList.remove("fs-left", "fs-right");
    setTimeout(invalidateMaps, 80);
    setTimeout(invalidateMaps, 320);
  }

  function isInteractive(el) {
    if (!el || !el.closest) return false;
    return !!el.closest(
      "button, a, input, textarea, .rail-item, .select-rail, .slide-dot, .reconnect-btn, .fs-hud"
    );
  }

  function bindPanel(side) {
    var root = document.getElementById(side + "-panel");
    if (!root || root.dataset.fsBound === "1") return;
    root.dataset.fsBound = "1";

    var startX = 0;
    var startY = 0;
    var startT = 0;
    var tracking = false;

    root.addEventListener(
      "pointerdown",
      function (e) {
        if (e.pointerType === "mouse" && e.button !== 0) return;
        if (isInteractive(e.target)) return;
        tracking = true;
        startX = e.clientX;
        startY = e.clientY;
        startT = Date.now();
      },
      true
    );

    root.addEventListener(
      "pointerup",
      function (e) {
        if (!tracking) return;
        tracking = false;
        if (isInteractive(e.target)) return;
        var dx = e.clientX - startX;
        var dy = e.clientY - startY;
        var dt = Date.now() - startT;
        if (dt > TAP_MAX_MS) return;
        if (Math.abs(dx) > TAP_MAX_MOVE || Math.abs(dy) > TAP_MAX_MOVE) return;
        // Already fullscreen on this side → ignore (exit via HUD)
        var c = cluster();
        if (c && c.classList.contains("fs-" + side)) return;
        setFullscreen(side);
      },
      true
    );

    root.addEventListener("pointercancel", function () {
      tracking = false;
    });
  }

  function bindHud() {
    var hud = document.getElementById("fs-hud");
    if (!hud || hud.dataset.bound === "1") return;
    hud.dataset.bound = "1";
    hud.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      clearFullscreen();
    });
  }

  function restoreDialStyle() {
    var root = cluster();
    if (!root) return;
    var next = "ring";
    try {
      next = localStorage.getItem("pulse_dial") || "ring";
    } catch (_) {}
    if (next === "blade") next = "porsche";
    if (next === "obsidian") next = "mercedes";
    if (next === "volt") next = "audi";
    var allowed = [
      "ring",
      "bmw",
      "porsche",
      "mercedes",
      "audi",
      "round",
      "square",
      "hex",
      "pill",
    ];
    if (allowed.indexOf(next) === -1) next = "ring";
    allowed.concat(["blade", "obsidian", "volt"]).forEach(function (s) {
      root.classList.remove("dial-" + s);
    });
    root.classList.add("dial-" + next);
    try {
      localStorage.setItem("pulse_dial", next);
    } catch (_) {}
    document.querySelectorAll(".dial-opt").forEach(function (el) {
      el.classList.toggle("on", el.getAttribute("data-style") === next);
    });
  }

  function boot() {
    bindPanel("left");
    bindPanel("right");
    bindHud();
    restoreDialStyle();
  }

  setInterval(boot, 700);
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.TeslaViewMode = {
    fullscreen: setFullscreen,
    exit: clearFullscreen,
  };
})();
