"""Realistic Tesla driving / charging telemetry simulator for demo mode."""

from __future__ import annotations

import math
import random
import time
from dataclasses import asdict, dataclass, field
from typing import Any

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

_STREETS = [
    "Ertürk Sk. No:29",
    "Şükrü Sk.",
    "Bağdat Cad.",
    "Caddebostan Sahil",
    "Moda Cad.",
    "Caferağa Mah.",
]

_PLAYLIST = [
    {"title": "Kayıp Kalp", "artist": "BLOK3", "service": "YouTube Music"},
    {"title": "Gesi Bağları", "artist": "Barış Manço", "service": "Spotify"},
    {"title": "Holocene", "artist": "Bon Iver", "service": "Apple Music"},
    {"title": "Midnight City", "artist": "M83", "service": "YouTube Music"},
    {"title": "Instant Crush", "artist": "Daft Punk", "service": "Spotify"},
]


@dataclass
class VehicleState:
    connected: bool
    mode: str
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
    # Cluster extras
    street: str = "Ertürk Sk. No:29"
    tire_fl: float = 42.0
    tire_fr: float = 42.0
    tire_rl: float = 40.0
    tire_rr: float = 40.0
    tire_unit: str = "psi"
    media_title: str = "Kayıp Kalp"
    media_artist: str = "BLOK3"
    media_service: str = "YouTube Music"
    media_progress: float = 0.35
    # Trip / navigation panel
    destination: str = "--"
    arrival_time: str = "--"
    energy_at_arrival: str = "--"
    trip_distance_km: str = "--"
    # Exterior light telltales
    light_parking: bool = False
    light_low: bool = False
    light_high: bool = False
    light_fog: bool = False
    turn_left: bool = False
    turn_right: bool = False
    # Vehicle-driven cluster theme
    ui_theme: str = "night"  # "day" | "night"

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class DemoSimulator:
    """Simulates a Model S Plaid drive with occasional Supercharging."""

    def __init__(self) -> None:
        self._t0 = time.time()
        self._battery = 69.0
        self._odo = 74832.0
        self._route_idx = 0.0
        self._charging = False
        self._charge_started = 0.0
        self._phase = "park"
        self._phase_until = self._t0 + 12
        self._gear = "P"
        self._trail: list[list[float]] = []
        self._speed = 0.0
        self._track_i = 0
        self._media_t0 = time.time()
        self._tires = {"fl": 42.0, "fr": 42.0, "rl": 40.0, "rr": 40.0}
        self._light_mode = "low"  # off | parking | low | high | fog
        self._light_i = 0
        self._light_until = self._t0 + 14
        self._turn = "off"  # off | left | right | hazard
        self._turn_i = 0
        self._turn_until = self._t0 + 8
        self._destinations = [
            "Zorlu Center",
            "Sabiha Gökçen",
            "Maslak 1453",
            "Kadıköy İskele",
            "İstinyePark",
        ]
        self._dest_i = 0

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

    def _nudge_tires(self) -> None:
        for k in self._tires:
            self._tires[k] = round(
                max(32.0, min(48.0, self._tires[k] + random.uniform(-0.15, 0.15))),
                1,
            )

    def tick(self) -> VehicleState:
        now = time.time()
        elapsed = now - self._t0

        if now >= self._phase_until:
            if self._phase == "drive":
                if self._battery < 28 or random.random() < 0.2:
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
                    self._phase_until = now + random.uniform(8, 14)
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

        if self._phase == "drive":
            wave = 0.5 + 0.5 * math.sin(elapsed * 0.35)
            target = 55 + wave * 70 + random.uniform(-4, 4)
            if random.random() < 0.02:
                target = random.uniform(8, 25)
            self._speed += (target - self._speed) * 0.12
            self._speed = max(0.0, min(250.0, self._speed))
            self._route_idx += (self._speed / 3600.0) * 8.5
            self._odo += self._speed / 3600.0 * 1.15
            power = (self._speed / 100.0) ** 1.5 * 95 + random.uniform(-8, 12)
            if self._speed < 5:
                power = random.uniform(-3, 2)
            drain = max(0.0, power) / 3600.0 * 2.2
            self._battery = max(5.0, self._battery - drain * 0.35)
            self._gear = "D" if self._speed > 1.5 else "N"
            charge_kw = 0.0
            minutes_to_full = 0
            autopilot = self._speed > 40 and random.random() > 0.3
        elif self._phase == "charge":
            self._speed = 0.0
            self._gear = "P"
            soc = self._battery / 100.0
            peak = 250.0
            charge_kw = peak * max(0.15, (1.0 - soc) ** 0.55)
            self._battery = min(92.0, self._battery + charge_kw / 3600.0 * 55)
            remaining = max(0.0, 92.0 - self._battery)
            minutes_to_full = int((remaining / max(charge_kw, 1)) * 60 * 1.1)
            autopilot = False
            power = -charge_kw
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

        self._nudge_tires()

        # Rotate tracks every ~45s
        track_elapsed = now - self._media_t0
        if track_elapsed > 45:
            self._track_i = (self._track_i + 1) % len(_PLAYLIST)
            self._media_t0 = now
            track_elapsed = 0
        track = _PLAYLIST[self._track_i]
        progress = min(0.98, track_elapsed / 45.0)

        street = _STREETS[int(self._route_idx) % len(_STREETS)]
        range_km = self._battery / 100.0 * 480.0

        # Cycle exterior lights for demo telltales (+ day/night UI)
        if now >= self._light_until:
            modes = ["off", "off", "parking", "low", "high", "low", "fog", "off"]
            self._light_i = (self._light_i + 1) % len(modes)
            self._light_mode = modes[self._light_i]
            self._light_until = now + random.uniform(10, 16)
        if now >= self._turn_until:
            turns = ["off", "left", "off", "right", "off", "hazard", "off"]
            self._turn_i = (self._turn_i + 1) % len(turns)
            self._turn = turns[self._turn_i]
            self._turn_until = now + random.uniform(4, 8)

        light_parking = self._light_mode in {"parking", "low", "high", "fog"}
        light_low = self._light_mode in {"low", "fog"}
        light_high = self._light_mode == "high"
        light_fog = self._light_mode == "fog"
        # Blink turns ~1.4Hz
        blink_on = int(now * 1.4) % 2 == 0
        turn_left = blink_on and self._turn in {"left", "hazard"}
        turn_right = blink_on and self._turn in {"right", "hazard"}

        # Trip panel — remaining route while driving
        if self._phase == "drive":
            rem_km = max(1.2, 18.0 - (self._route_idx % 18.0) * 0.85)
            eta_min = int(rem_km / max(self._speed, 25.0) * 60)
            arrive = time.localtime(now + eta_min * 60)
            arrival = time.strftime("%H:%M", arrive)
            energy_arr = max(8, int(self._battery - rem_km * 0.18))
            dest = self._destinations[int(self._route_idx / 4) % len(self._destinations)]
            destination = dest
            arrival_time = arrival
            energy_at_arrival = f"{energy_arr}%"
            trip_distance = f"{rem_km:.1f} km"
        else:
            destination = "--"
            arrival_time = "--"
            energy_at_arrival = "--"
            trip_distance = "--"

        # Vehicle decides day/night UI from headlights + ambient hour
        hour = time.localtime(now).tm_hour
        ambient_night = hour < 6 or hour >= 19
        headlights_on = self._light_mode in {"low", "high", "fog"}
        if headlights_on:
            ui_theme = "night"
        elif self._light_mode == "off" and 7 <= hour < 18:
            ui_theme = "day"
        else:
            ui_theme = "night" if ambient_night or self._light_mode == "parking" else "day"

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
            outside_temp_c=round(29 + 1.5 * math.sin(elapsed / 50), 0),
            inside_temp_c=21.5,
            is_locked=self._gear == "P",
            sentry_mode=self._gear == "P",
            autopilot=autopilot,
            timestamp=now,
            trail=list(self._trail),
            street=street,
            tire_fl=self._tires["fl"],
            tire_fr=self._tires["fr"],
            tire_rl=self._tires["rl"],
            tire_rr=self._tires["rr"],
            media_title=track["title"],
            media_artist=track["artist"],
            media_service=track["service"],
            media_progress=round(progress, 3),
            destination=destination,
            arrival_time=arrival_time,
            energy_at_arrival=energy_at_arrival,
            trip_distance_km=trip_distance,
            light_parking=light_parking,
            light_low=light_low,
            light_high=light_high,
            light_fog=light_fog,
            turn_left=turn_left,
            turn_right=turn_right,
            ui_theme=ui_theme,
        )
