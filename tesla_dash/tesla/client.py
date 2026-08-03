"""Tesla Owner / Fleet API client with graceful demo fallback."""

from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Any

import requests

from .simulator import DemoSimulator, VehicleState

OWNER_API = "https://owner-api.teslamotors.com/api/1"
ENV_PATH = Path(__file__).resolve().parents[2] / ".env"

_client: "TeslaClient | None" = None
_street_cache: dict[str, tuple[float, str]] = {}


def reset_client() -> None:
    global _client
    _client = None


def _upsert_env(updates: dict[str, str]) -> None:
    """Persist live credentials into .env (create keys if missing)."""
    lines: list[str] = []
    if ENV_PATH.is_file():
        lines = ENV_PATH.read_text(encoding="utf-8").splitlines()
    seen: set[str] = set()
    out: list[str] = []
    for line in lines:
        if "=" in line and not line.lstrip().startswith("#"):
            key = line.split("=", 1)[0].strip()
            if key in updates:
                out.append(f"{key}={updates[key]}")
                seen.add(key)
                continue
        out.append(line)
    for key, val in updates.items():
        if key not in seen:
            out.append(f"{key}={val}")
    ENV_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")
    for key, val in updates.items():
        os.environ[key] = val


def enable_live(*, access_token: str, vehicle_id: str = "", vin: str = "") -> dict[str, Any]:
    """Enable live mode from a PIN-authenticated API call. Returns status dict."""
    token = access_token.strip()
    if not token:
        return {"ok": False, "error": "access_token gerekli"}

    tmp = TeslaClient(access_token=token, vehicle_id=vehicle_id.strip() or "0")
    tmp.live = True
    vid = (vehicle_id or "").strip()
    if not vid:
        vid = tmp.resolve_vehicle_id(vin=vin) or ""
    if not vid:
        return {"ok": False, "error": "vehicle_id bulunamadi — hesabindaki araclari kontrol et"}

    # Probe vehicle_data once
    probe = TeslaClient(access_token=token, vehicle_id=vid)
    probe.live = True
    state = probe.fetch_live()
    if state is None:
        # Still save — car may be asleep; wake was attempted inside fetch_live
        _upsert_env(
            {
                "TESLA_ACCESS_TOKEN": token,
                "TESLA_VEHICLE_ID": vid,
                "TESLA_LIVE": "true",
            }
        )
        if vin:
            _upsert_env({"TESLA_VIN": vin.strip().upper()})
        reset_client()
        return {
            "ok": True,
            "live": True,
            "vehicle_id": vid,
            "warning": "Kaydedildi ama vehicle_data henuz gelmedi (arac uyanıyor olabilir)",
        }

    _upsert_env(
        {
            "TESLA_ACCESS_TOKEN": token,
            "TESLA_VEHICLE_ID": vid,
            "TESLA_LIVE": "true",
        }
    )
    if vin:
        _upsert_env({"TESLA_VIN": vin.strip().upper()})
    reset_client()
    return {
        "ok": True,
        "live": True,
        "vehicle_id": vid,
        "vehicle_name": state.vehicle_name,
        "gear": state.gear,
        "speed_kmh": state.speed_kmh,
        "battery_percent": state.battery_percent,
        "latitude": state.latitude,
        "longitude": state.longitude,
    }


def live_status() -> dict[str, Any]:
    c = TeslaClient()
    return {
        "ok": True,
        "live_configured": c.can_live,
        "has_token": bool(c.access_token),
        "vehicle_id": c.vehicle_id or "",
        "tesla_live_flag": c.live,
    }


class TeslaClient:
    def __init__(
        self,
        access_token: str | None = None,
        vehicle_id: str | None = None,
    ) -> None:
        from dotenv import load_dotenv

        load_dotenv(ENV_PATH, override=False)
        self.access_token = access_token or os.getenv("TESLA_ACCESS_TOKEN", "").strip()
        self.vehicle_id = vehicle_id or os.getenv("TESLA_VEHICLE_ID", "").strip()
        self.live = os.getenv("TESLA_LIVE", "false").lower() in {"1", "true", "yes"}
        self._demo = DemoSimulator()
        self._session = requests.Session()
        if self.access_token:
            self._session.headers.update(
                {
                    "Authorization": f"Bearer {self.access_token}",
                    "Content-Type": "application/json",
                }
            )

    @property
    def can_live(self) -> bool:
        return bool(self.live and self.access_token and self.vehicle_id)

    def _get(self, path: str, timeout: float = 12.0, params: dict | None = None) -> dict[str, Any] | None:
        try:
            r = self._session.get(f"{OWNER_API}{path}", timeout=timeout, params=params)
            if r.status_code == 200:
                return r.json()
        except requests.RequestException:
            return None
        return None

    def _wake(self) -> bool:
        try:
            r = self._session.post(
                f"{OWNER_API}/vehicles/{self.vehicle_id}/wake_up",
                timeout=20,
            )
            return r.status_code in (200, 202)
        except requests.RequestException:
            return False

    def resolve_vehicle_id(self, vin: str = "") -> str | None:
        data = self._get("/vehicles")
        if not data or "response" not in data:
            return None
        vehicles = data["response"] or []
        want = (vin or os.getenv("TESLA_VIN", "")).strip().upper()
        if want:
            for v in vehicles:
                if str(v.get("vin", "")).upper() == want:
                    return str(v.get("id") or v.get("id_s") or "")
        if len(vehicles) == 1:
            v = vehicles[0]
            return str(v.get("id") or v.get("id_s") or "")
        # Prefer first online
        for v in vehicles:
            if v.get("state") == "online":
                return str(v.get("id") or v.get("id_s") or "")
        if vehicles:
            v = vehicles[0]
            return str(v.get("id") or v.get("id_s") or "")
        return None

    @staticmethod
    def _tpms_to_psi(raw: Any, unit_hint: str) -> float:
        try:
            v = float(raw)
        except (TypeError, ValueError):
            return 42.0
        u = (unit_hint or "bar").lower()
        if "psi" in u:
            return round(v, 1)
        # Tesla reports bar (~2.9). Values already in psi are usually > 20.
        if v < 10:
            return round(v * 14.5038, 1)
        return round(v, 1)

    @staticmethod
    def _reverse_street(lat: float, lon: float) -> str:
        if not lat and not lon:
            return "—"
        key = f"{lat:.4f},{lon:.4f}"
        now = time.time()
        cached = _street_cache.get(key)
        if cached and now - cached[0] < 120:
            return cached[1]
        try:
            r = requests.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={"format": "jsonv2", "lat": lat, "lon": lon, "zoom": 18},
                headers={"User-Agent": "TeslaPulseDash/1.0 (personal HUD)"},
                timeout=4,
            )
            if r.status_code == 200:
                j = r.json()
                addr = j.get("address") or {}
                road = addr.get("road") or addr.get("pedestrian") or addr.get("suburb") or ""
                house = addr.get("house_number") or ""
                name = (j.get("name") or "").strip()
                if road and house:
                    street = f"{road} {house}"
                elif road:
                    street = road
                elif name:
                    street = name
                else:
                    street = (j.get("display_name") or "—").split(",")[0]
                _street_cache[key] = (now, street)
                return street
        except requests.RequestException:
            pass
        return "—"

    def fetch_live(self) -> VehicleState | None:
        if not self.can_live and not (self.access_token and self.vehicle_id and self.live):
            if self.access_token and self.live and not self.vehicle_id:
                resolved = self.resolve_vehicle_id()
                if resolved:
                    self.vehicle_id = resolved
                else:
                    return None
            else:
                return None
        if not self.access_token or not self.vehicle_id:
            return None

        # location_data required on newer firmware for lat/lon
        params = {
            "endpoints": "charge_state;climate_state;drive_state;gui_settings;location_data;vehicle_config;vehicle_state"
        }
        data = self._get(f"/vehicles/{self.vehicle_id}/vehicle_data", params=params)
        if data is None:
            self._wake()
            time.sleep(2.5)
            data = self._get(f"/vehicles/{self.vehicle_id}/vehicle_data", params=params)
        if not data or "response" not in data:
            return None

        resp = data["response"]
        drive = resp.get("drive_state") or {}
        charge = resp.get("charge_state") or {}
        climate = resp.get("climate_state") or {}
        vehicle = resp.get("vehicle_state") or {}
        gui = resp.get("gui_settings") or {}
        media = vehicle.get("media_info") or resp.get("media_info") or {}

        shift = (drive.get("shift_state") or "P") or "P"
        speed_raw = drive.get("speed")
        units = (gui.get("gui_distance_units") or "km/hr").lower()
        if speed_raw is None:
            speed_kmh = 0.0
        else:
            speed_kmh = float(speed_raw) * (1.60934 if "mi" in units else 1.0)

        battery = float(charge.get("battery_level") or 0)
        charging_state = (charge.get("charging_state") or "").lower()
        charging = charging_state in {"charging", "starting"}
        charge_kw = float(charge.get("charger_power") or 0)
        minutes = int(charge.get("minutes_to_full_charge") or 0)

        lat = float(drive.get("latitude") or 0)
        lon = float(drive.get("longitude") or 0)
        heading = float(drive.get("heading") or 0)
        power = float(drive.get("power") or 0)

        name = vehicle.get("vehicle_name") or resp.get("display_name") or "Tesla"
        model = (resp.get("vehicle_config") or {}).get("car_type") or "Tesla"

        est_range = charge.get("battery_range") or charge.get("est_battery_range") or 0
        range_km = float(est_range) * (1.60934 if "mi" in units else 1.0)

        odo = float(vehicle.get("odometer") or 0)
        if "mi" in units:
            odo *= 1.60934

        tire_unit = str(gui.get("gui_tirepressure_units") or "Bar")
        tire_fl = self._tpms_to_psi(vehicle.get("tpms_pressure_fl"), tire_unit)
        tire_fr = self._tpms_to_psi(vehicle.get("tpms_pressure_fr"), tire_unit)
        tire_rl = self._tpms_to_psi(vehicle.get("tpms_pressure_rl"), tire_unit)
        tire_rr = self._tpms_to_psi(vehicle.get("tpms_pressure_rr"), tire_unit)

        # Navigation (when a route is active in the car)
        dest = drive.get("active_route_destination") or vehicle.get("active_route_destination")
        minutes_arr = drive.get("active_route_minutes_to_arrival")
        miles_arr = drive.get("active_route_miles_to_arrival")
        energy_arr = drive.get("active_route_energy_at_arrival")
        dest_lat = float(
            drive.get("active_route_latitude")
            or vehicle.get("active_route_latitude")
            or 0
        )
        dest_lon = float(
            drive.get("active_route_longitude")
            or vehicle.get("active_route_longitude")
            or 0
        )

        if dest:
            destination = str(dest)
        else:
            destination = "—"

        if minutes_arr is not None:
            try:
                eta_dt = time.localtime(time.time() + float(minutes_arr) * 60)
                arrival_time = time.strftime("%H:%M", eta_dt)
            except (TypeError, ValueError):
                arrival_time = "—"
        else:
            arrival_time = "—"

        if energy_arr is not None:
            try:
                energy_at_arrival = f"{int(float(energy_arr))}%"
            except (TypeError, ValueError):
                energy_at_arrival = "—"
        else:
            energy_at_arrival = "—"

        if miles_arr is not None:
            try:
                # Field name is miles; always convert to km for HUD
                dist_km = float(miles_arr) * 1.60934
                trip_distance_km = f"{dist_km:.1f} km"
            except (TypeError, ValueError):
                trip_distance_km = "—"
        else:
            trip_distance_km = "—"

        title = (
            media.get("now_playing_title")
            or media.get("audio_now_playing_title")
            or ""
        )
        artist = (
            media.get("now_playing_artist")
            or media.get("audio_now_playing_artist")
            or ""
        )
        service = (
            media.get("now_playing_source")
            or media.get("audio_now_playing_source")
            or media.get("now_playing_station")
            or "Media"
        )
        playing = str(media.get("media_playback_status") or "").lower() in {
            "playing",
            "play",
            "1",
            "true",
        }
        vol = media.get("audio_volume")
        try:
            media_progress = min(1.0, max(0.0, float(vol or 0) / 11.0)) if vol is not None else 0.0
        except (TypeError, ValueError):
            media_progress = 0.0

        street = self._reverse_street(lat, lon)

        return VehicleState(
            connected=True,
            mode="live",
            vehicle_name=str(name),
            model=str(model),
            gear=str(shift),
            speed_kmh=round(speed_kmh, 1),
            power_kw=round(power, 1),
            battery_percent=round(battery, 1),
            battery_range_km=round(range_km, 1),
            charging=charging,
            charge_rate_kw=round(charge_kw, 1),
            minutes_to_full=minutes,
            charge_limit=int(charge.get("charge_limit_soc") or 80),
            latitude=lat,
            longitude=lon,
            heading=heading,
            odometer_km=round(odo, 1),
            outside_temp_c=float(climate.get("outside_temp") or 0),
            inside_temp_c=float(climate.get("inside_temp") or 0),
            is_locked=bool(vehicle.get("locked")),
            sentry_mode=bool(vehicle.get("sentry_mode")),
            autopilot=False,
            timestamp=time.time(),
            trail=[[lat, lon]] if lat and lon else [],
            street=street,
            tire_fl=tire_fl,
            tire_fr=tire_fr,
            tire_rl=tire_rl,
            tire_rr=tire_rr,
            tire_unit="psi",
            media_title=str(title or "—"),
            media_artist=str(artist or "—"),
            media_service=str(service or "Media"),
            media_progress=media_progress if not playing else max(0.05, media_progress),
            destination=destination,
            destination_lat=dest_lat,
            destination_lon=dest_lon,
            arrival_time=arrival_time,
            energy_at_arrival=energy_at_arrival,
            trip_distance_km=trip_distance_km,
            light_parking=bool(vehicle.get("parking_lights") or vehicle.get("drl")),
            light_low=bool(vehicle.get("headlamp") or vehicle.get("headlight")),
            light_high=bool(vehicle.get("high_beam") or vehicle.get("high_beams")),
            light_fog=bool(vehicle.get("front_fog") or vehicle.get("fog_lights")),
            turn_left=bool(vehicle.get("turn_indicator_left")),
            turn_right=bool(vehicle.get("turn_indicator_right")),
            door_fl=bool(vehicle.get("df")),
            door_fr=bool(vehicle.get("pf")),
            door_rl=bool(vehicle.get("dr")),
            door_rr=bool(vehicle.get("pr")),
            frunk_open=bool(vehicle.get("ft")),
            trunk_open=bool(vehicle.get("rt")),
            charge_port_open=bool(vehicle.get("charge_port_door_open") or charge.get("charge_port_door_open")),
            ui_theme=(
                "night"
                if (
                    vehicle.get("high_beam")
                    or vehicle.get("high_beams")
                    or vehicle.get("headlamp")
                    or vehicle.get("headlight")
                    or time.localtime().tm_hour < 6
                    or time.localtime().tm_hour >= 19
                )
                else "day"
            ),
        )

    def get_state(self) -> VehicleState:
        if self.can_live or (self.live and self.access_token):
            if not self.vehicle_id and self.access_token:
                resolved = self.resolve_vehicle_id()
                if resolved:
                    self.vehicle_id = resolved
                    _upsert_env({"TESLA_VEHICLE_ID": resolved})
            live = self.fetch_live()
            if live is not None:
                return live
        return self._demo.tick()


def get_vehicle_state() -> dict[str, Any]:
    global _client
    if _client is None:
        from dotenv import load_dotenv

        load_dotenv(ENV_PATH, override=True)
        _client = TeslaClient()
    return _client.get_state().to_dict()
