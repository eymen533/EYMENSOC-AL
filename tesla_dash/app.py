"""Tesla Pulse — cinematic vehicle Dash HUD over Bluetooth Low Energy."""

from __future__ import annotations

import os
import sys

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from dotenv import load_dotenv

load_dotenv()

import dash_bootstrap_components as dbc
import dash_leaflet as dl
from dash import Dash, Input, Output, State, callback, clientside_callback, dcc, html

from tesla_dash.components import battery_gauge, power_spark, speed_gauge
from tesla_dash.tesla import get_vehicle_state
from tesla_dash.tesla.ble import get_ble_session

GEARS = ["P", "R", "N", "D"]
DARK_TILES = "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
TILE_ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; CARTO'

app = Dash(
    __name__,
    external_stylesheets=[dbc.themes.DARKLY],
    suppress_callback_exceptions=True,
    title="TESLA PULSE · BLE",
    update_title=None,
)
server = app.server


# ——— REST helpers for BLE (optional bleak scan from phone-less host) ———
@server.post("/api/ble/demo")
def api_ble_demo():
    link = get_ble_session().connect_demo()
    return link.to_dict()


@server.post("/api/ble/disconnect")
def api_ble_disconnect():
    link = get_ble_session().disconnect()
    return link.to_dict()


@server.get("/api/ble/status")
def api_ble_status():
    return get_ble_session().snapshot()


@server.post("/api/ble/scan")
def api_ble_scan():
    return get_ble_session().scan_bleak(timeout=4.0)


def _gear_row(active: str) -> html.Div:
    return html.Div(
        [
            html.Div(g, className=f"gear-slot{' active' if g == active else ''}")
            for g in GEARS
        ],
        className="gear-row",
    )


def _flags(state: dict, ble: dict) -> list:
    flags = []
    if ble.get("connected"):
        rssi = ble.get("rssi")
        label = f"BLE {rssi} dBm" if rssi is not None else "BLE"
        flags.append(html.Span(label, className="flag on ble-flag"))
    if state.get("charging"):
        flags.append(html.Span("ŞARJ", className="flag charge"))
    if state.get("autopilot"):
        flags.append(html.Span("AUTOPILOT", className="flag on"))
    if state.get("sentry_mode"):
        flags.append(html.Span("SENTRY", className="flag on"))
    if state.get("is_locked"):
        flags.append(html.Span("KİLİTLİ", className="flag"))
    else:
        flags.append(html.Span("AÇIK", className="flag on"))
    return flags


def _fmt_charge_time(minutes: int) -> str:
    if not minutes or minutes <= 0:
        return "—"
    h, m = divmod(int(minutes), 60)
    if h:
        return f"{h}s {m:02d}dk"
    return f"{m} dk"


def _signal_bars(rssi: int | None) -> html.Div:
    """Visual BLE signal strength 0–4 bars from RSSI."""
    if rssi is None:
        level = 0
    elif rssi >= -55:
        level = 4
    elif rssi >= -65:
        level = 3
    elif rssi >= -75:
        level = 2
    elif rssi >= -85:
        level = 1
    else:
        level = 0
    return html.Div(
        [
            html.Span(
                className=f"ble-bar{' on' if i <= level else ''}",
                style={"height": f"{6 + i * 4}px"},
            )
            for i in range(1, 5)
        ],
        className="ble-bars",
        title=f"RSSI {rssi} dBm" if rssi is not None else "BLE sinyal yok",
    )


app.layout = html.Div(
    [
        dcc.Store(id="ble-store", data={"connected": False, "source": "none"}),
        dcc.Store(id="ble-action", data=None),
        dcc.Interval(id="tick", interval=1000, n_intervals=0),
        html.Div(
            id="stage",
            className="dash-stage",
            **{"data-theme": "dark"},
            children=[
                html.Div(
                    className="map-layer",
                    children=[
                        dl.Map(
                            id="map",
                            center=[41.025, 29.02],
                            zoom=13,
                            zoomControl=False,
                            attributionControl=False,
                            style={"width": "100%", "height": "100vh"},
                            children=[
                                dl.TileLayer(
                                    id="tiles",
                                    url=DARK_TILES,
                                    attribution=TILE_ATTR,
                                ),
                                dl.Polyline(
                                    id="trail-line",
                                    positions=[],
                                    color="#3DE7C5",
                                    weight=3,
                                    opacity=0.75,
                                ),
                                dl.Marker(
                                    id="car-marker",
                                    position=[41.025, 29.02],
                                    children=[
                                        dl.Tooltip(id="car-tooltip", children="Tesla"),
                                    ],
                                ),
                            ],
                        )
                    ],
                ),
                html.Div(className="map-overlay"),
                html.Div(
                    className="ui-layer",
                    children=[
                        html.Header(
                            className="top-bar",
                            children=[
                                html.Div(
                                    className="brand-block",
                                    children=[
                                        html.H1("TESLA", className="brand"),
                                        html.P(
                                            "PULSE  ·  BLE VEHICLE HUD",
                                            className="brand-sub",
                                        ),
                                    ],
                                ),
                                html.Div(
                                    className="top-actions",
                                    children=[
                                        html.Div(
                                            id="conn-status",
                                            className="status-pill",
                                            children=[
                                                html.Span(
                                                    className="status-dot offline",
                                                    id="conn-dot",
                                                ),
                                                html.Span(
                                                    id="conn-label",
                                                    children="BLE HAZIR",
                                                ),
                                                html.Div(id="ble-signal"),
                                            ],
                                        ),
                                        html.Button(
                                            "BLE BAĞLAN",
                                            id="ble-btn",
                                            className="theme-toggle ble-btn",
                                            n_clicks=0,
                                            title="Bluetooth Low Energy ile Tesla'ya bağlan",
                                        ),
                                    ],
                                ),
                            ],
                        ),
                        html.Div(
                            id="ble-banner",
                            className="ble-banner",
                            children="Bluetooth Low Energy ile araca bağlanın — hız, vites, batarya ve harita canlı HUD.",
                        ),
                        html.Div(
                            className="hud-grid",
                            children=[
                                html.Section(
                                    className="panel gear-panel",
                                    children=[
                                        html.H2("VİTES", className="panel-title"),
                                        html.Div(id="gear-display"),
                                    ],
                                ),
                                html.Section(
                                    className="speed-panel",
                                    children=[
                                        dcc.Graph(
                                            id="speed-gauge",
                                            className="speed-hero dash-graph",
                                            config={
                                                "displayModeBar": False,
                                                "staticPlot": True,
                                            },
                                        ),
                                        html.Div(
                                            className="vehicle-meta",
                                            children=[
                                                html.P(
                                                    id="vehicle-name",
                                                    className="vehicle-name",
                                                ),
                                                html.Div(
                                                    id="vehicle-flags",
                                                    className="vehicle-flags",
                                                ),
                                            ],
                                        ),
                                    ],
                                ),
                                html.Section(
                                    className="panel battery-panel",
                                    children=[
                                        html.H2("BATARYA", className="panel-title"),
                                        dcc.Graph(
                                            id="battery-gauge",
                                            className="dash-graph",
                                            config={
                                                "displayModeBar": False,
                                                "staticPlot": True,
                                            },
                                        ),
                                        html.Div(
                                            className="charge-meta",
                                            children=[
                                                html.Div(
                                                    className="meta-cell",
                                                    children=[
                                                        html.Span(
                                                            "Şarj süresi",
                                                            className="meta-label",
                                                        ),
                                                        html.Span(
                                                            id="charge-eta",
                                                            className="meta-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="meta-cell",
                                                    children=[
                                                        html.Span(
                                                            "Şarj gücü",
                                                            className="meta-label",
                                                        ),
                                                        html.Span(
                                                            id="charge-kw",
                                                            className="meta-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="meta-cell",
                                                    children=[
                                                        html.Span(
                                                            "Limit",
                                                            className="meta-label",
                                                        ),
                                                        html.Span(
                                                            id="charge-limit",
                                                            className="meta-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="meta-cell",
                                                    children=[
                                                        html.Span(
                                                            "Menzil",
                                                            className="meta-label",
                                                        ),
                                                        html.Span(
                                                            id="range-km",
                                                            className="meta-value",
                                                        ),
                                                    ],
                                                ),
                                            ],
                                        ),
                                    ],
                                ),
                                html.Section(
                                    className="panel stats-panel",
                                    children=[
                                        html.H2("TELEMETRİ", className="panel-title"),
                                        html.Div(
                                            className="stat-list",
                                            children=[
                                                html.Div(
                                                    className="stat-row",
                                                    children=[
                                                        html.Span(
                                                            "BLE cihaz",
                                                            className="stat-label",
                                                        ),
                                                        html.Span(
                                                            id="ble-device",
                                                            className="stat-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="stat-row",
                                                    children=[
                                                        html.Span(
                                                            "RSSI",
                                                            className="stat-label",
                                                        ),
                                                        html.Span(
                                                            id="ble-rssi",
                                                            className="stat-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="stat-row",
                                                    children=[
                                                        html.Span(
                                                            "Dış sıcaklık",
                                                            className="stat-label",
                                                        ),
                                                        html.Span(
                                                            id="temp-out",
                                                            className="stat-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="stat-row",
                                                    children=[
                                                        html.Span(
                                                            "İç sıcaklık",
                                                            className="stat-label",
                                                        ),
                                                        html.Span(
                                                            id="temp-in",
                                                            className="stat-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="stat-row",
                                                    children=[
                                                        html.Span(
                                                            "Yön",
                                                            className="stat-label",
                                                        ),
                                                        html.Span(
                                                            id="heading",
                                                            className="stat-value",
                                                        ),
                                                    ],
                                                ),
                                                html.Div(
                                                    className="stat-row",
                                                    children=[
                                                        html.Span(
                                                            "Hız",
                                                            className="stat-label",
                                                        ),
                                                        html.Span(
                                                            id="speed-text",
                                                            className="stat-value",
                                                        ),
                                                    ],
                                                ),
                                            ],
                                        ),
                                    ],
                                ),
                                html.Section(
                                    className="panel power-panel",
                                    children=[
                                        html.H2("GÜÇ AKIŞI", className="panel-title"),
                                        dcc.Graph(
                                            id="power-gauge",
                                            className="dash-graph",
                                            config={
                                                "displayModeBar": False,
                                                "staticPlot": True,
                                            },
                                        ),
                                    ],
                                ),
                                html.Footer(
                                    className="bottom-strip",
                                    children=[
                                        html.Span(id="coords", className="coords"),
                                        html.Span(id="mode-badge", className="mode-badge"),
                                        html.Span(id="odo", className="odo"),
                                    ],
                                ),
                            ],
                        ),
                    ],
                ),
            ],
        ),
    ]
)


# Web Bluetooth connect / disconnect from the BLE button
clientside_callback(
    """
    async function(n, ble) {
        if (!n) { return window.dash_clientside.no_update; }
        const linked = ble && ble.connected;
        if (linked) {
            if (window.TeslaBLE) {
                const snap = await window.TeslaBLE.disconnect();
                try { await fetch('/api/ble/disconnect', {method:'POST'}); } catch(e) {}
                return Object.assign({}, snap, {disconnect:true, connected:false});
            }
            try { await fetch('/api/ble/disconnect', {method:'POST'}); } catch(e) {}
            return {connected:false, source:'none', disconnect:true};
        }
        if (window.TeslaBLE) {
            const snap = await window.TeslaBLE.connect();
            if (snap.demo_fallback && !snap.connected) {
                try {
                    const r = await fetch('/api/ble/demo', {method:'POST'});
                    const demo = await r.json();
                    return Object.assign({}, demo, {source: demo.source || 'demo'});
                } catch(e) {
                    return {connected:true, source:'demo', device_name:'Model S Plaid · BLE',
                            device_id:'ble-demo', rssi:-52, error:''};
                }
            }
            try {
                await fetch('/api/ble/status');
            } catch(e) {}
            return snap;
        }
        // No Web Bluetooth script — server demo link
        try {
            const r = await fetch('/api/ble/demo', {method:'POST'});
            return await r.json();
        } catch(e) {
            return {connected:true, source:'demo', device_name:'Model S Plaid · BLE',
                    device_id:'ble-demo', rssi:-52};
        }
    }
    """,
    Output("ble-store", "data"),
    Input("ble-btn", "n_clicks"),
    State("ble-store", "data"),
    prevent_initial_call=True,
)


@callback(
    Output("ble-btn", "children"),
    Output("ble-btn", "className"),
    Output("ble-banner", "children"),
    Output("ble-banner", "className"),
    Input("ble-store", "data"),
)
def ble_chrome(ble):
    ble = ble or {}
    if ble.get("connected"):
        src = (ble.get("source") or "ble").upper()
        name = ble.get("device_name") or "Tesla"
        return (
            "BLE KES",
            "theme-toggle ble-btn connected",
            f"Bağlı · {name} · {src} Low Energy link aktif",
            "ble-banner on",
        )
    err = ble.get("error") or ""
    msg = err or "Bluetooth Low Energy ile araca bağlanın — hız, vites, batarya ve harita canlı HUD."
    return (
        "BLE BAĞLAN",
        "theme-toggle ble-btn",
        msg,
        "ble-banner",
    )


@callback(
    Output("speed-gauge", "figure"),
    Output("battery-gauge", "figure"),
    Output("power-gauge", "figure"),
    Output("gear-display", "children"),
    Output("vehicle-name", "children"),
    Output("vehicle-flags", "children"),
    Output("charge-eta", "children"),
    Output("charge-kw", "children"),
    Output("charge-limit", "children"),
    Output("range-km", "children"),
    Output("ble-device", "children"),
    Output("ble-rssi", "children"),
    Output("temp-out", "children"),
    Output("temp-in", "children"),
    Output("heading", "children"),
    Output("speed-text", "children"),
    Output("coords", "children"),
    Output("mode-badge", "children"),
    Output("odo", "children"),
    Output("conn-label", "children"),
    Output("conn-dot", "className"),
    Output("ble-signal", "children"),
    Output("car-marker", "position"),
    Output("car-tooltip", "children"),
    Output("trail-line", "positions"),
    Output("map", "center"),
    Input("tick", "n_intervals"),
    Input("ble-store", "data"),
)
def refresh(_n, ble_store):
    state = get_vehicle_state()
    session = get_ble_session().snapshot()
    ble = {**session, **(ble_store or {})}
    # Prefer explicit store connection flag
    if ble_store and ble_store.get("connected"):
        ble["connected"] = True
        for k in ("device_name", "device_id", "rssi", "source"):
            if ble_store.get(k) not in (None, ""):
                ble[k] = ble_store[k]
    elif ble_store and ble_store.get("disconnect"):
        ble["connected"] = False

    gear = (state.get("gear") or "P").upper()
    if gear not in GEARS:
        gear = "P"

    lat = float(state.get("latitude") or 41.025)
    lon = float(state.get("longitude") or 29.02)
    trail = state.get("trail") or [[lat, lon]]
    positions = [[float(p[0]), float(p[1])] for p in trail if len(p) >= 2]

    linked = bool(ble.get("connected"))
    src = ble.get("source") or "none"
    if linked:
        label = "BLE LINK"
        dot_cls = "status-dot"
        mode_txt = f"BLE · {(src or 'link').upper()}  ·  {state.get('model', 'Tesla')}"
        vname = ble.get("device_name") or state.get("vehicle_name") or "Tesla"
    else:
        label = "BLE HAZIR"
        dot_cls = "status-dot offline"
        mode_txt = f"BEKLENİYOR  ·  {state.get('model', 'Tesla')}"
        vname = state.get("vehicle_name") or "Tesla"

    # Until BLE is linked, park the HUD visually (P / 0) for dramatic connect moment
    if not linked:
        display = dict(state)
        display["speed_kmh"] = 0
        display["gear"] = "P"
        display["power_kw"] = 0
        display["autopilot"] = False
        gear = "P"
    else:
        display = state
        # Optional GATT battery override from Web Bluetooth
        if ble_store and ble_store.get("battery_level") is not None:
            display = dict(state)
            display["battery_percent"] = float(ble_store["battery_level"])

    rssi = ble.get("rssi") if linked else None
    ble_dev = (ble.get("device_name") or "—") if linked else "—"
    ble_rssi = f"{rssi} dBm" if linked and rssi is not None else "—"

    return (
        speed_gauge(display["speed_kmh"], display["power_kw"], "dark"),
        battery_gauge(
            display["battery_percent"],
            display["battery_range_km"],
            display["charging"],
            "dark",
        ),
        power_spark(display["power_kw"], "dark"),
        _gear_row(gear),
        vname,
        _flags(display, ble if linked else {}),
        _fmt_charge_time(display.get("minutes_to_full") or 0) if linked else "—",
        f"{display.get('charge_rate_kw', 0):.0f} kW" if linked else "—",
        f"%{display.get('charge_limit', 90)}" if linked else "—",
        f"{display.get('battery_range_km', 0):.0f} km" if linked else "—",
        ble_dev,
        ble_rssi,
        f"{display.get('outside_temp_c', 0):.1f}°C" if linked else "—",
        f"{display.get('inside_temp_c', 0):.1f}°C" if linked else "—",
        f"{display.get('heading', 0):.0f}°" if linked else "—",
        f"{display.get('speed_kmh', 0):.0f} km/h",
        f"{lat:.5f}° N  ·  {lon:.5f}° E" if linked else "BLE bağlantısı bekleniyor",
        mode_txt,
        f"ODO  {display.get('odometer_km', 0):,.0f} km".replace(",", ".")
        if linked
        else "ODO  —",
        label,
        dot_cls,
        _signal_bars(rssi) if linked else _signal_bars(None),
        [lat, lon],
        vname,
        positions if linked else [],
        [lat, lon],
    )


def main():
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8050"))
    debug = os.getenv("DEBUG", "false").lower() in {"1", "true", "yes"}
    app.run(host=host, port=port, debug=debug)


if __name__ == "__main__":
    main()
