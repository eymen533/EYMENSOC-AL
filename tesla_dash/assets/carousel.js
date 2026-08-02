/**
 * Side carousels + dual selection rails.
 * Rails show on selection, hide after 1.02s; next selection shows again.
 * Slides: 0 trip, 1 tires, 2 map, 3 media
 */
(function () {
  "use strict";

  var COUNT = 4;
  var HIDE_MS = 1020;
  var cool = { left: 0, right: 0 };
  var hideTimers = { left: null, right: null };
  var KIND_FOR_SLIDE = { 0: "dash", 1: "gear", 2: "nav", 3: "music" };

  function clamp(i) {
    return ((i % COUNT) + COUNT) % COUNT;
  }

  function railEl(side) {
    return document.getElementById("select-rail-" + side);
  }

  function readIndex(side) {
    var track = document.getElementById(side + "-carousel");
    if (track && track.dataset.index != null) {
      return parseInt(track.dataset.index, 10) || 0;
    }
    return side === "right" ? 2 : 0;
  }

  function flashRail(side, index) {
    var rail = railEl(side);
    if (!rail) return;
    index = clamp(index);
    var want = KIND_FOR_SLIDE[index] || "nav";
    rail.classList.add("visible");
    rail.querySelectorAll(".rail-item").forEach(function (el) {
      el.classList.toggle("on", el.getAttribute("data-kind") === want);
    });
    if (hideTimers[side]) clearTimeout(hideTimers[side]);
    hideTimers[side] = setTimeout(function () {
      rail.classList.remove("visible");
      hideTimers[side] = null;
    }, HIDE_MS);
  }

  function writeIndex(side, index) {
    index = clamp(index);
    var now = Date.now();
    if (now - (cool[side] || 0) < 280) return;
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

  function bindRail(side) {
    var rail = railEl(side);
    if (!rail || rail.dataset.clickBound === "1") return;
    rail.dataset.clickBound = "1";
    rail.querySelectorAll(".rail-item").forEach(function (btn) {
      btn.addEventListener("click", function (e) {
        e.stopPropagation();
        var i = parseInt(btn.getAttribute("data-i") || "0", 10);
        writeIndex(side, i);
      });
    });
  }

  function boot() {
    bind("left");
    bind("right");
    bindRail("left");
    bindRail("right");
  }

  setInterval(boot, 600);
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }

  window.TeslaCarousel = { set: writeIndex, flash: flashRail };
})();
