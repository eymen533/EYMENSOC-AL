"""Tesla Owner / Fleet API client with graceful demo fallback."""

from __future__ import annotations

import os
from typing import Any

import requests

from .simulator import DemoSimulator, VehicleState

OWNER_API = "https://owner-api.teslamotors.com/api/1"


class TeslaClient:
    def __init__(
        self,
        access_token: str | None = None,
        vehicle_id: str | None = None,
    ) -> None:
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

    def _get(self, path: str, timeout: float = 8.0) -> dict[str, Any] | None:
        try:
            r = self._session.get(f"{OWNER_API}{path}", timeout=timeout)
            if r.status_code == 200:
                return r.json()
        except requests.RequestException:
            return None
        return None

    def _wake(self) -> bool:
        try:
            r = self._session.post(
                f"{OWNER_API}/vehicles/{self.vehicle_id}/wake_up",
                timeout=15,
            )
            return r.status_code in (200, 202)
        except requests.RequestException:
            return False

    def fetch_live(self) -> VehicleState | None:
        if not self.can_live:
            return None

        data = self._get(f"/vehicles/{self.vehicle_id}/vehicle_data")
        if data is None:
            self._wake()
            data = self._get(f"/vehicles/{self.vehicle_id}/vehicle_data")
        if not data or "response" not in data:
            return None

        resp = data["response"]
        drive = resp.get("drive_state") or {}
        charge = resp.get("charge_state") or {}
        climate = resp.get("climate_state") or {}
        vehicle = resp.get("vehicle_state") or {}
        gui = resp.get("gui_settings") or {}

        shift = (drive.get("shift_state") or "P") or "P"
        speed_mph = drive.get("speed")
        if speed_mph is None:
            speed_kmh = 0.0
        else:
            # Tesla API often returns mph; convert if units suggest
            units = (gui.get("gui_distance_units") or "km/hr").lower()
            if "mi" in units:
                speed_kmh = float(speed_mph) * 1.60934
            else:
                speed_kmh = float(speed_mph)

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
        units = (gui.get("gui_distance_units") or "km/hr").lower()
        range_km = float(est_range) * (1.60934 if "mi" in units else 1.0)

        odo = float(vehicle.get("odometer") or 0)
        if "mi" in units:
            odo *= 1.60934

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
            timestamp=__import__("time").time(),
            trail=[[lat, lon]] if lat and lon else [],
            street="—",
            tire_fl=float((vehicle.get("tpms_pressure_fl") or 42)),
            tire_fr=float((vehicle.get("tpms_pressure_fr") or 42)),
            tire_rl=float((vehicle.get("tpms_pressure_rl") or 40)),
            tire_rr=float((vehicle.get("tpms_pressure_rr") or 40)),
            destination="—",
            arrival_time="—",
            energy_at_arrival="—",
            trip_distance_km="—",
            light_parking=bool(vehicle.get("parking_lights") or vehicle.get("drl")),
            light_low=bool(vehicle.get("headlamp") or vehicle.get("headlight")),
            light_high=bool(vehicle.get("high_beam") or vehicle.get("high_beams")),
            light_fog=bool(vehicle.get("front_fog") or vehicle.get("fog_lights")),
            turn_left=bool(vehicle.get("turn_indicator_left")),
            turn_right=bool(vehicle.get("turn_indicator_right")),
        )

    def get_state(self) -> VehicleState:
        if self.can_live:
            live = self.fetch_live()
            if live is not None:
                return live
        return self._demo.tick()


_client: TeslaClient | None = None


def get_vehicle_state() -> dict[str, Any]:
    global _client
    if _client is None:
        from dotenv import load_dotenv

        load_dotenv()
        _client = TeslaClient()
    return _client.get_state().to_dict()
