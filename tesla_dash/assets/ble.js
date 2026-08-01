/**
 * Tesla Pulse — optional Web Bluetooth GATT probe (NOT vehicle key pairing).
 * Chrome/Android only. Does not send VCSEC add-key; car Pair UI will not appear.
 * Loaded as a Dash asset. Exposes window.TeslaBLE for clientside callbacks.
 */
(function (global) {
  "use strict";

  var TESLA_SERVICE = "00000211-b2d1-43f0-9b88-960cebf8b91e";

  var state = {
    connected: false,
    device_id: "",
    device_name: "",
    rssi: null,
    service_uuid: "",
    error: "",
    scanning: false,
    server: null,
    device: null,
  };

  function snapshot() {
    return {
      connected: state.connected,
      device_id: state.device_id,
      device_name: state.device_name,
      rssi: state.rssi,
      service_uuid: state.service_uuid,
      error: state.error,
      scanning: state.scanning,
      source: state.connected ? "web" : "none",
      ts: Date.now(),
    };
  }

  function supported() {
    return !!(navigator.bluetooth && navigator.bluetooth.requestDevice);
  }

  async function connect() {
    state.error = "";
    state.scanning = true;

    if (!supported()) {
      state.scanning = false;
      state.error = "Web Bluetooth yok (iPhone Safari desteklemez). HUD’u aç kullan — araç Pair için Tesla app.";
      return Object.assign(snapshot(), { demo_fallback: true });
    }

    try {
      // Prefer Tesla-named devices; acceptAllDevices confuses drivers in the car
      var device;
      try {
        device = await navigator.bluetooth.requestDevice({
          filters: [
            { namePrefix: "Tesla" },
            { namePrefix: "Model" },
            { services: [TESLA_SERVICE] },
          ],
          optionalServices: [TESLA_SERVICE, "battery_service", "device_information"],
        });
      } catch (filterErr) {
        device = await navigator.bluetooth.requestDevice({
          acceptAllDevices: true,
          optionalServices: [TESLA_SERVICE, "battery_service", "device_information"],
        });
      }

      state.device = device;
      state.device_id = device.id || "";
      state.device_name = device.name || "Tesla BLE";
      device.addEventListener("gattserverdisconnected", onDisconnect);

      var server = await device.gatt.connect();
      state.server = server;
      state.connected = true;
      state.scanning = false;
      state.service_uuid = TESLA_SERVICE;
      state.rssi = null;

      // Best-effort battery read if standard service is exposed
      try {
        var batt = await server.getPrimaryService("battery_service");
        var level = await batt.getCharacteristic("battery_level");
        var value = await level.readValue();
        state.battery_level = value.getUint8(0);
      } catch (_) {
        /* vehicle may not expose standard battery GATT */
      }

      return snapshot();
    } catch (err) {
      state.scanning = false;
      state.connected = false;
      var msg = (err && err.message) || String(err);
      // User cancelled picker → offer demo BLE so the HUD still works
      if (/cancel|chooser|user/i.test(msg)) {
        state.error = "";
        return Object.assign(snapshot(), { demo_fallback: true, cancelled: true });
      }
      state.error = msg;
      return Object.assign(snapshot(), { demo_fallback: true });
    }
  }

  function onDisconnect() {
    state.connected = false;
    state.server = null;
  }

  async function disconnect() {
    try {
      if (state.device && state.device.gatt && state.device.gatt.connected) {
        state.device.gatt.disconnect();
      }
    } catch (_) {}
    state.connected = false;
    state.server = null;
    state.device = null;
    state.device_id = "";
    state.device_name = "";
    state.rssi = null;
    state.error = "";
    return Object.assign(snapshot(), { disconnect: true });
  }

  global.TeslaBLE = {
    supported: supported,
    connect: connect,
    disconnect: disconnect,
    snapshot: snapshot,
  };
})(window);
