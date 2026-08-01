"""Lightweight prayer-time helper (Diyanet-style angles) for next-namaz HUD."""

from __future__ import annotations

import math
from datetime import date, datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

# Istanbul default (cluster demo route)
DEFAULT_LAT = 41.025
DEFAULT_LON = 29.02
DEFAULT_TZ = ZoneInfo("Europe/Istanbul")

# Diyanet-like angles (Turkey)
FAJR_ANGLE = 18.0
ISHA_ANGLE = 17.0
SUNSET_ANGLE = 0.833

PRAYER_ORDER = ("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
# Display names for next-prayer chip (skip sunrise as "namaz")
NAMAZ_KEYS = ("İmsak", "Öğle", "İkindi", "Akşam", "Yatsı")


def _deg2rad(d: float) -> float:
    return math.radians(d)


def _rad2deg(r: float) -> float:
    return math.degrees(r)


def _sun_position(day: date) -> tuple[float, float]:
    """Return (declination_deg, equation_of_time_hours) approx for date."""
    # Day of year
    n = day.timetuple().tm_yday
    # Fractional year
    gamma = 2 * math.pi / 365 * (n - 1 + (12 - 12) / 24)
    eq_min = 229.18 * (
        0.000075
        + 0.001868 * math.cos(gamma)
        - 0.032077 * math.sin(gamma)
        - 0.014615 * math.cos(2 * gamma)
        - 0.040849 * math.sin(2 * gamma)
    )
    decl = (
        0.006918
        - 0.399912 * math.cos(gamma)
        + 0.070257 * math.sin(gamma)
        - 0.006758 * math.cos(2 * gamma)
        + 0.000907 * math.sin(2 * gamma)
        - 0.002697 * math.cos(3 * gamma)
        + 0.00148 * math.sin(3 * gamma)
    )
    return _rad2deg(decl), eq_min / 60.0


def _hour_angle(lat: float, decl: float, angle: float) -> float | None:
    """Hour angle in degrees for sun altitude `angle` (negative below horizon)."""
    lat_r, decl_r, ang_r = _deg2rad(lat), _deg2rad(decl), _deg2rad(angle)
    cos_h = (math.sin(ang_r) - math.sin(lat_r) * math.sin(decl_r)) / (
        math.cos(lat_r) * math.cos(decl_r)
    )
    if cos_h < -1 or cos_h > 1:
        return None
    return _rad2deg(math.acos(cos_h))


def _time_at(
    lat: float,
    lon: float,
    tz_offset_h: float,
    decl: float,
    eqt_h: float,
    angle: float,
    after_noon: bool,
) -> float | None:
    h = _hour_angle(lat, decl, angle)
    if h is None:
        return None
    # T = 12 + tz - lon/15 - eqt ± H/15
    base = 12 + tz_offset_h - lon / 15.0 - eqt_h
    return base + (h / 15.0 if after_noon else -h / 15.0)


def _asr_time(
    lat: float,
    lon: float,
    tz_offset_h: float,
    decl: float,
    eqt_h: float,
    hanafi: bool = False,
) -> float | None:
    lat_r, decl_r = _deg2rad(lat), _deg2rad(decl)
    # shadow factor: 1 (Shafi/Diyanet) or 2 (Hanafi)
    factor = 2 if hanafi else 1
    try:
        # Positive solar altitude at Asr (PrayTimes / astronomical form)
        alt = _rad2deg(math.atan(1.0 / (factor + math.tan(abs(lat_r - decl_r)))))
    except Exception:
        return None
    return _time_at(lat, lon, tz_offset_h, decl, eqt_h, alt, after_noon=True)


def _fmt_hours(h: float) -> str:
    if h is None:
        return "--:--"
    h = h % 24
    hh = int(h)
    mm = int(round((h - hh) * 60))
    if mm == 60:
        hh = (hh + 1) % 24
        mm = 0
    return f"{hh:02d}:{mm:02d}"


def prayer_times_for(
    day: date | None = None,
    lat: float = DEFAULT_LAT,
    lon: float = DEFAULT_LON,
    tz: ZoneInfo | None = None,
) -> dict[str, str]:
    tz = tz or DEFAULT_TZ
    day = day or datetime.now(tz).date()
    # timezone offset hours for that date (DST aware)
    noon_local = datetime(day.year, day.month, day.day, 12, 0, tzinfo=tz)
    tz_offset_h = noon_local.utcoffset().total_seconds() / 3600.0  # type: ignore[union-attr]
    decl, eqt_h = _sun_position(day)

    fajr = _time_at(lat, lon, tz_offset_h, decl, eqt_h, -FAJR_ANGLE, False)
    sunrise = _time_at(lat, lon, tz_offset_h, decl, eqt_h, -SUNSET_ANGLE, False)
    dhuhr = 12 + tz_offset_h - lon / 15.0 - eqt_h
    asr = _asr_time(lat, lon, tz_offset_h, decl, eqt_h, hanafi=False)
    maghrib = _time_at(lat, lon, tz_offset_h, decl, eqt_h, -SUNSET_ANGLE, True)
    isha = _time_at(lat, lon, tz_offset_h, decl, eqt_h, -ISHA_ANGLE, True)

    return {
        "İmsak": _fmt_hours(fajr) if fajr is not None else "--:--",
        "Güneş": _fmt_hours(sunrise) if sunrise is not None else "--:--",
        "Öğle": _fmt_hours(dhuhr),
        "İkindi": _fmt_hours(asr) if asr is not None else "--:--",
        "Akşam": _fmt_hours(maghrib) if maghrib is not None else "--:--",
        "Yatsı": _fmt_hours(isha) if isha is not None else "--:--",
    }


def next_prayer(
    now: datetime | None = None,
    lat: float = DEFAULT_LAT,
    lon: float = DEFAULT_LON,
    tz: ZoneInfo | None = None,
) -> dict[str, Any]:
    tz = tz or DEFAULT_TZ
    now = now or datetime.now(tz)
    if now.tzinfo is None:
        now = now.replace(tzinfo=tz)
    else:
        now = now.astimezone(tz)

    times = prayer_times_for(now.date(), lat, lon, tz)
    # parse today's namaz times
    candidates: list[tuple[str, datetime]] = []
    for name in NAMAZ_KEYS:
        hh, mm = times[name].split(":")
        if hh == "--":
            continue
        dt = datetime(now.year, now.month, now.day, int(hh), int(mm), tzinfo=tz)
        candidates.append((name, dt))

    for name, dt in candidates:
        if dt > now:
            delta = dt - now
            mins = int(delta.total_seconds() // 60)
            return {
                "name": name,
                "time": times[name],
                "label": f"{name} {times[name]}",
                "in_min": mins,
                "times": times,
            }

    # next is tomorrow's İmsak
    tomorrow = now.date() + timedelta(days=1)
    t2 = prayer_times_for(tomorrow, lat, lon, tz)
    hh, mm = t2["İmsak"].split(":")
    dt = datetime(tomorrow.year, tomorrow.month, tomorrow.day, int(hh), int(mm), tzinfo=tz)
    mins = int((dt - now).total_seconds() // 60)
    return {
        "name": "İmsak",
        "time": t2["İmsak"],
        "label": f"İmsak {t2['İmsak']}",
        "in_min": mins,
        "times": t2,
    }
