"""Realistic Tesla driving / charging telemetry simulator for demo mode."""

from __future__ import annotations

import math
import random
import time
from dataclasses import asdict, dataclass
from typing import Any


# Istanbul → coastal drive path (demo map trail)
_ROUTE = [
    (41.0082, 28.9784),
    (41.0150, 28.9850),
    (41.0220, 28.9920),
    (41.0300, 29.0000),
    (41.0380, 29.0100),
    (41.0450, 29.0200),
    (41.0520, 29.0280),
    (41.0580, 29.0350),
    (41.0620, 29.0420),
    (41.0550, 29.0500),
    (41.0480, 29.0550),
    (41.0400, 29.0480),
    (41.0320, 29.0400),
    (41.0250, 29.0300),
    (41.0180, 29.0180),
    (41.0120, 29.0050),
    (41.0082, 28.9784),
]


@dataclass
class VehicleState:
    connected: bool
    mode: str  # "demo" | "live"
    vehicle_name: str
    model: str
    gear: str
    speed_kmh: float
    power_kw: float
    battery_percent: float
    battery_range_km: float
    charging: bool
    charge_rate_kw: float
    minutes_to_full: int
    charge_limit: int
    latitude: float
    longitude: float
    heading: float
    odometer_km: float
    outside_temp_c: float
    inside_temp_c: float
    is_locked: bool
    sentry_mode: bool
    autopilot: bool
    timestamp: float
    trail: list[list[float]]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class DemoSimulator:
    """Simulates a Model S Plaid drive with occasional Supercharging."""

    def __init__(self) -> None:
        self._t0 = time.time()
        self._battery = 72.0
        self._odo = 18432.0
        self._route_idx = 0.0
        self._charging = False
        self._charge_started = 0.0
        self._phase = "drive"  # drive | charge | park
        self._phase_until = self._t0 + 45
        self._gear = "D"
        self._trail: list[list[float]] = []
        self._speed = 0.0

    def _interp_route(self, idx: float) -> tuple[float, float, float]:
        n = len(_ROUTE)
        i0 = int(idx) % n
        i1 = (i0 + 1) % n
        f = idx - int(idx)
        lat0, lon0 = _ROUTE[i0]
        lat1, lon1 = _ROUTE[i1]
        lat = lat0 + (lat1 - lat0) * f
        lon = lon0 + (lon1 - lon0) * f
        heading = math.degrees(math.atan2(lon1 - lon0, lat1 - lat0)) % 360
        return lat, lon, heading

    def tick(self) -> VehicleState:
        now = time.time()
        elapsed = now - self._t0

        if now >= self._phase_until:
            if self._phase == "drive":
                if self._battery < 28 or random.random() < 0.25:
                    self._phase = "charge"
                    self._charging = True
                    self._gear = "P"
                    self._speed = 0.0
                    self._charge_started = now
                    self._phase_until = now + random.uniform(18, 28)
                else:
                    self._phase = "park"
                    self._charging = False
                    self._gear = "P"
                    self._speed = 0.0
                    self._phase_until = now + random.uniform(6, 10)
            elif self._phase == "charge":
                self._phase = "drive"
                self._charging = False
                self._gear = "D"
                self._phase_until = now + random.uniform(40, 70)
            else:
                self._phase = "drive"
                self._charging = False
                self._gear = "D"
                self._phase_until = now + random.uniform(35, 60)

        lat, lon, heading = self._interp_route(self._route_idx)

        if self._phase == "drive":
            # Smooth speed profile with slight randomness
            wave = 0.5 + 0.5 * math.sin(elapsed * 0.35)
            target = 55 + wave * 70 + random.uniform(-4, 4)
            if random.random() < 0.02:
                target = random.uniform(8, 25)  # brief slowdown
            self._speed += (target - self._speed) * 0.12
            self._speed = max(0.0, min(250.0, self._speed))

            # Advance along route proportional to speed
            self._route_idx += (self._speed / 3600.0) * 8.5  # demo scale
            self._odo += self._speed / 3600.0 * 1.15

            # Power draw ~ speed^1.6 + accel
            power = (self._speed / 100.0) ** 1.5 * 95 + random.uniform(-8, 12)
            if self._speed < 5:
                power = random.uniform(-3, 2)
            drain = max(0.0, power) / 3600.0 * 2.2  # % per tick-ish
            self._battery = max(5.0, self._battery - drain * 0.35)
            self._gear = "D" if self._speed > 1.5 else "N"
            charge_kw = 0.0
            minutes_to_full = 0
            autopilot = self._speed > 40 and random.random() > 0.3
        elif self._phase == "charge":
            self._speed = 0.0
            self._gear = "P"
            # Supercharger curve: faster when empty
            soc = self._battery / 100.0
            peak = 250.0
            charge_kw = peak * max(0.15, (1.0 - soc) ** 0.55)
            self._battery = min(92.0, self._battery + charge_kw / 3600.0 * 55)
            remaining = max(0.0, 92.0 - self._battery)
            minutes_to_full = int((remaining / max(charge_kw, 1)) * 60 * 1.1)
            autopilot = False
            power = -charge_kw
            lat, lon, heading = self._interp_route(self._route_idx)
        else:
            self._speed = max(0.0, self._speed * 0.7)
            self._gear = "P"
            power = random.uniform(-1.5, 0.5)
            charge_kw = 0.0
            minutes_to_full = 0
            autopilot = False

        lat, lon, heading = self._interp_route(self._route_idx)
        self._trail.append([lat, lon])
        if len(self._trail) > 80:
            self._trail = self._trail[-80:]

        range_km = self._battery / 100.0 * 520.0

        return VehicleState(
            connected=True,
            mode="demo",
            vehicle_name="Model S Plaid",
            model="Model S",
            gear=self._gear,
            speed_kmh=round(self._speed, 1),
            power_kw=round(power, 1),
            battery_percent=round(self._battery, 1),
            battery_range_km=round(range_km, 1),
            charging=self._charging,
            charge_rate_kw=round(charge_kw if self._charging else 0.0, 1),
            minutes_to_full=minutes_to_full if self._charging else 0,
            charge_limit=90,
            latitude=lat,
            longitude=lon,
            heading=heading,
            odometer_km=round(self._odo, 1),
            outside_temp_c=round(18 + 3 * math.sin(elapsed / 40), 1),
            inside_temp_c=21.5,
            is_locked=self._gear == "P",
            sentry_mode=self._gear == "P",
            autopilot=autopilot,
            timestamp=now,
            trail=list(self._trail),
        )
