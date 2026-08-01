"""Bluetooth Low Energy bridge for Tesla proximity / vehicle link.

Web Bluetooth (browser) is the primary path. Optional ``bleak`` enables
server-side scanning when a local adapter is present. Full drive telemetry
still comes from the Owner API or the demo simulator; BLE establishes the
vehicle link and surfaces RSSI / device identity in the HUD.
"""

from __future__ import annotations

import asyncio
import os
import threading
import time
from dataclasses import asdict, dataclass, field
from typing import Any

# Tesla VCSEC / vehicle BLE service UUIDs used by modern vehicles
TESLA_SERVICE_UUIDS = (
    "00000211-b2d1-4f76-bada-24be206df979",
    "00000212-b2d1-4f76-bada-24be206df979",
)

# Common advertisement name patterns (owner-renamed cars vary)
TESLA_NAME_HINTS = ("tesla", "model s", "model 3", "model x", "model y", "cybertruck")


@dataclass
class BleLink:
    connected: bool = False
    source: str = "none"  # web | bleak | demo
    device_id: str = ""
    device_name: str = ""
    rssi: int | None = None
    service_uuid: str = ""
    last_seen: float = 0.0
    error: str = ""
    scanning: bool = False
    devices_found: list[dict[str, Any]] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class BleSession:
    """Process-wide BLE session shared by Flask routes and Dash callbacks."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.link = BleLink()
        self._demo_rssi_t0 = time.time()

    def update_from_web(self, payload: dict[str, Any] | None) -> BleLink:
        payload = payload or {}
        with self._lock:
            if payload.get("disconnect"):
                self.link = BleLink(connected=False, source="none", last_seen=time.time())
                return self.link

            if payload.get("connected"):
                self.link.connected = True
                self.link.source = str(payload.get("source") or "web")
                self.link.device_id = str(payload.get("device_id") or "")
                self.link.device_name = str(
                    payload.get("device_name") or "Tesla BLE"
                )
                rssi = payload.get("rssi")
                self.link.rssi = int(rssi) if rssi is not None else self._fake_rssi()
                self.link.service_uuid = str(payload.get("service_uuid") or "")
                self.link.error = ""
                self.link.last_seen = time.time()
            elif payload.get("error"):
                self.link.error = str(payload["error"])
                self.link.scanning = False
            elif payload.get("scanning") is not None:
                self.link.scanning = bool(payload["scanning"])

            return self.link

    def connect_demo(self) -> BleLink:
        """Emulate a BLE link when no adapter / Web Bluetooth is available."""
        with self._lock:
            self.link = BleLink(
                connected=True,
                source="demo",
                device_id="ble-demo-tesla-plaid",
                device_name="Model S Plaid · BLE",
                rssi=self._fake_rssi(),
                service_uuid=TESLA_SERVICE_UUIDS[0],
                last_seen=time.time(),
            )
            return self.link

    def disconnect(self) -> BleLink:
        with self._lock:
            self.link = BleLink(connected=False, source="none", last_seen=time.time())
            return self.link

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            link = self.link
            if link.connected and link.source == "demo":
                link.rssi = self._fake_rssi()
                link.last_seen = time.time()
            return link.to_dict()

    def _fake_rssi(self) -> int:
        # Gentle wander around a strong near-vehicle signal
        import math

        t = time.time() - self._demo_rssi_t0
        return int(-48 + 6 * math.sin(t / 2.4) + 2 * math.sin(t * 1.7))

    def scan_bleak(self, timeout: float = 5.0) -> dict[str, Any]:
        """Scan with bleak if installed and an adapter exists."""
        try:
            from bleak import BleakScanner
        except ImportError:
            return {
                "ok": False,
                "error": "bleak yüklü değil — pip install bleak",
                "devices": [],
            }

        async def _scan() -> list[dict[str, Any]]:
            devices = await BleakScanner.discover(timeout=timeout, return_adv=True)
            found: list[dict[str, Any]] = []
            for _addr, (dev, adv) in devices.items():
                name = (dev.name or adv.local_name or "").strip()
                uuids = [u.lower() for u in (adv.service_uuids or [])]
                name_l = name.lower()
                is_tesla = any(u in TESLA_SERVICE_UUIDS for u in uuids) or any(
                    h in name_l for h in TESLA_NAME_HINTS
                )
                found.append(
                    {
                        "address": dev.address,
                        "name": name or "Bilinmeyen",
                        "rssi": adv.rssi,
                        "uuids": uuids,
                        "tesla_likely": is_tesla,
                    }
                )
            found.sort(key=lambda d: (not d["tesla_likely"], -(d["rssi"] or -999)))
            return found

        with self._lock:
            self.link.scanning = True
        try:
            devices = asyncio.run(_scan())
        except Exception as exc:  # noqa: BLE001 — surface adapter errors to UI
            with self._lock:
                self.link.scanning = False
                self.link.error = str(exc)
            return {"ok": False, "error": str(exc), "devices": []}

        with self._lock:
            self.link.scanning = False
            self.link.devices_found = devices
            # Auto-link strongest Tesla-likely device
            for d in devices:
                if d.get("tesla_likely"):
                    self.link.connected = True
                    self.link.source = "bleak"
                    self.link.device_id = d["address"]
                    self.link.device_name = d["name"]
                    self.link.rssi = d.get("rssi")
                    self.link.service_uuid = (d.get("uuids") or [""])[0]
                    self.link.last_seen = time.time()
                    self.link.error = ""
                    break

        return {"ok": True, "devices": devices, "link": self.snapshot()}


_session: BleSession | None = None


def get_ble_session() -> BleSession:
    global _session
    if _session is None:
        _session = BleSession()
        # Cloud / headless: optional auto demo BLE so HUD shows BLE mode
        if os.getenv("BLE_DEMO_AUTO", "true").lower() in {"1", "true", "yes"}:
            pass  # user must click BLE — don't auto-connect
    return _session
