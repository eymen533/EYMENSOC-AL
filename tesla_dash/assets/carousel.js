/**
 * Vertical side-panel carousels + transient selection rail.
 */
(function () {
  "use strict";

  var COUNT = 3;
  var LABELS = ["Medya", "Lastik · PSI", "Harita"];
  var ICONS = ["♪", "▣", "➤"];
  var cool = { left: 0, right: 0 };
  var hideTimer = null;

  function clamp(i) {
    return ((i % COUNT) + COUNT) % COUNT;
  }

  function readIndex(side) {
    var track = document.getElementById(side + "-carousel");
    if (track && track.dataset.index != null) {
      return parseInt(track.dataset.index, 10) || 0;
    }
    return side === "right" ? 2 : 0;
  }

  function flashRail(side, index) {
    var rail = document.getElementById("select-rail");
    var label = document.getElementById("select-rail-label");
    if (!rail) return;
    rail.classList.add("visible");
    rail.dataset.side = side;
    rail.querySelectorAll(".rail-item").forEach(function (el, i) {
      el.classList.toggle("on", i === index);
    });
    if (label) {
      label.textContent = (side === "left" ? "Sol · " : "Sağ · ") + (LABELS[index] || "");
    }
    if (hideTimer) clearTimeout(hideTimer);
    hideTimer = setTimeout(function () {
      rail.classList.remove("visible");
    }, 1400);
  }

  function writeIndex(side, index) {
    index = clamp(index);
    var now = Date.now();
    if (now - (cool[side] || 0) < 320) return;
    cool[side] = now;
    if (window.dash_clientside && dash_clientside.set_props) {
      dash_clientside.set_props(side + "-slide-store", { data: index });
    }
    var track = document.getElementById(side + "-carousel");
    if (track) {
      track.style.transform = "translateY(-" + index * 100 + "%)";
      track.dataset.index = String(index);
    }
    var host = document.getElementById(side + "-dots");
    if (host) {
      host.querySelectorAll(".slide-dot").forEach(function (d, i) {
        d.classList.toggle("on", i === index);
      });
    }
    flashRail(side, index);
  }

  function bind(side) {
    var root = document.getElementById(side + "-panel");
    if (!root || root.dataset.bound === "1") return;
    root.dataset.bound = "1";

    var startY = 0;
    var active = false;

    root.addEventListener(
      "wheel",
      function (e) {
        if (Math.abs(e.deltaY) < 10) return;
        e.preventDefault();
        writeIndex(side, readIndex(side) + (e.deltaY > 0 ? 1 : -1));
      },
      { passive: false }
    );

    root.addEventListener(
      "touchstart",
      function (e) {
        if (!e.touches.length) return;
        startY = e.touches[0].clientY;
        active = true;
      },
      { passive: true }
    );

    root.addEventListener(
      "touchend",
      function (e) {
        if (!active) return;
        active = false;
        var y = (e.changedTouches[0] && e.changedTouches[0].clientY) || startY;
        var dy = startY - y;
        if (Math.abs(dy) < 36) return;
        writeIndex(side, readIndex(side) + (dy > 0 ? 1 : -1));
      },
      { passive: true }
    );

    root.addEventListener("pointerdown", function (e) {
      if (e.pointerType === "mouse" && e.button !== 0) return;
      startY = e.clientY;
      active = true;
      try {
        root.setPointerCapture(e.pointerId);
      } catch (_) {}
    });

    root.addEventListener("pointerup", function (e) {
      if (!active) return;
      active = false;
      var dy = startY - e.clientY;
      if (Math.abs(dy) < 48) return;
      writeIndex(side, readIndex(side) + (dy > 0 ? 1 : -1));
    });
  }

  function boot() {
    bind("left");
    bind("right");
    var rail = document.getElementById("select-rail");
    if (rail && rail.dataset.clickBound !== "1") {
      rail.dataset.clickBound = "1";
      rail.querySelectorAll(".rail-item").forEach(function (btn) {
        btn.addEventListener("click", function () {
          var i = parseInt(btn.getAttribute("data-i") || "0", 10);
          // Apply to the side that last moved, default left
          var side = rail.dataset.side || "left";
          writeIndex(side, i);
        });
      });
    }
  }

  setInterval(boot, 600);
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.TeslaCarousel = {
    set: writeIndex,
    next: function (s) {
      writeIndex(s, readIndex(s) + 1);
    },
    icons: ICONS,
    labels: LABELS,
  };
})();
