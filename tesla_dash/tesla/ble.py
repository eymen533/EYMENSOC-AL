"""Bluetooth Low Energy bridge + VIN / Tesla Card pairing session."""

from __future__ import annotations

import asyncio
import os
import re
import threading
import time
from dataclasses import asdict, dataclass, field
from typing import Any

TESLA_SERVICE_UUIDS = (
    "00000211-b2d1-4f76-bada-24be206df979",
    "00000212-b2d1-4f76-bada-24be206df979",
)

TESLA_NAME_HINTS = ("tesla", "model s", "model 3", "model x", "model y", "cybertruck")

VIN_RE = re.compile(r"^[A-HJ-NPR-Z0-9]{17}$", re.I)


def normalize_vin(vin: str) -> str:
    return re.sub(r"\s+", "", (vin or "")).upper()


def valid_vin(vin: str) -> bool:
    return bool(VIN_RE.match(normalize_vin(vin)))


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
    vin: str = ""
    card_paired: bool = False
    paired_at: float = 0.0

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class BleSession:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.link = BleLink()
        self._demo_rssi_t0 = time.time()
        self._pending_vin = ""
        self._card_ok = False

    def set_vin(self, vin: str) -> dict[str, Any]:
        vin_n = normalize_vin(vin)
        if not valid_vin(vin_n):
            return {
                "ok": False,
                "error": "VIN 17 karakter olmalı (I, O, Q yok).",
                "vin": vin_n,
            }
        with self._lock:
            self._pending_vin = vin_n
            self._card_ok = False
            self.link.vin = vin_n
            self.link.card_paired = False
            self.link.error = ""
        return {"ok": True, "vin": vin_n, "step": "card"}

    def tap_card(self) -> dict[str, Any]:
        with self._lock:
            if not self._pending_vin:
                return {"ok": False, "error": "Önce VIN girin."}
            self._card_ok = True
            self.link.card_paired = True
            self.link.paired_at = time.time()
            self.link.vin = self._pending_vin
        return {
            "ok": True,
            "vin": self._pending_vin,
            "card_paired": True,
            "step": "ble",
            "message": "Kart onaylandı. Şimdi Araca bağlan’a bas.",
        }

    def pair_and_connect(
        self,
        vin: str,
        card_tapped: bool = True,
        source: str = "demo",
    ) -> dict[str, Any]:
        vin_n = normalize_vin(vin)
        if not valid_vin(vin_n):
            return {"ok": False, "error": "Geçersiz VIN.", "connected": False}
        if not card_tapped:
            return {"ok": False, "error": "Tesla kartını okutun.", "connected": False}

        with self._lock:
            self._pending_vin = vin_n
            self._card_ok = True
            short = vin_n[-6:]
            self.link = BleLink(
                connected=True,
                source=source,
                device_id=f"ble-{vin_n[-8:].lower()}",
                device_name=f"Tesla · {short}",
                rssi=self._fake_rssi(),
                service_uuid=TESLA_SERVICE_UUIDS[0],
                last_seen=time.time(),
                vin=vin_n,
                card_paired=True,
                paired_at=time.time(),
            )
            return {"ok": True, **self.link.to_dict()}

    def update_from_web(self, payload: dict[str, Any] | None) -> BleLink:
        payload = payload or {}
        with self._lock:
            if payload.get("disconnect"):
                vin = self.link.vin
                self.link = BleLink(
                    connected=False,
                    source="none",
                    last_seen=time.time(),
                    vin=vin,
                )
                self._card_ok = False
                return self.link

            if payload.get("connected"):
                self.link.connected = True
                self.link.source = str(payload.get("source") or "web")
                self.link.device_id = str(payload.get("device_id") or "")
                self.link.device_name = str(payload.get("device_name") or "Tesla BLE")
                rssi = payload.get("rssi")
                self.link.rssi = int(rssi) if rssi is not None else self._fake_rssi()
                self.link.service_uuid = str(payload.get("service_uuid") or "")
                if payload.get("vin"):
                    self.link.vin = normalize_vin(str(payload["vin"]))
                self.link.card_paired = bool(payload.get("card_paired", self._card_ok))
                self.link.error = ""
                self.link.last_seen = time.time()
            elif payload.get("error"):
                self.link.error = str(payload["error"])
                self.link.scanning = False
            elif payload.get("scanning") is not None:
                self.link.scanning = bool(payload["scanning"])

            return self.link

    def connect_demo(self, vin: str | None = None) -> BleLink:
        vin_n = normalize_vin(vin or self._pending_vin or "5YJ3E1EA1KF317284")
        if not valid_vin(vin_n):
            vin_n = "5YJ3E1EA1KF317284"
        result = self.pair_and_connect(vin_n, card_tapped=True, source="demo")
        return self.link

    def disconnect(self) -> BleLink:
        with self._lock:
            vin = self.link.vin
            self.link = BleLink(
                connected=False,
                source="none",
                last_seen=time.time(),
                vin=vin,
            )
            self._card_ok = False
            return self.link

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            link = self.link
            if link.connected and link.source == "demo":
                link.rssi = self._fake_rssi()
                link.last_seen = time.time()
            data = link.to_dict()
            data["pending_vin"] = self._pending_vin
            data["card_ready"] = self._card_ok
            return data

    def _fake_rssi(self) -> int:
        import math

        t = time.time() - self._demo_rssi_t0
        return int(-48 + 6 * math.sin(t / 2.4) + 2 * math.sin(t * 1.7))

    def scan_bleak(self, timeout: float = 5.0) -> dict[str, Any]:
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
        except Exception as exc:  # noqa: BLE001
            with self._lock:
                self.link.scanning = False
                self.link.error = str(exc)
            return {"ok": False, "error": str(exc), "devices": []}

        with self._lock:
            self.link.scanning = False
            self.link.devices_found = devices
            for d in devices:
                if d.get("tesla_likely") and self._card_ok and self._pending_vin:
                    self.link.connected = True
                    self.link.source = "bleak"
                    self.link.device_id = d["address"]
                    self.link.device_name = d["name"]
                    self.link.rssi = d.get("rssi")
                    self.link.service_uuid = (d.get("uuids") or [""])[0]
                    self.link.vin = self._pending_vin
                    self.link.card_paired = True
                    self.link.last_seen = time.time()
                    self.link.error = ""
                    break

        return {"ok": True, "devices": devices, "link": self.snapshot()}


_session: BleSession | None = None


def get_ble_session() -> BleSession:
    global _session
    if _session is None:
        _session = BleSession()
        _ = os.getenv("BLE_DEMO_AUTO", "true")
    return _session
