"""Tesla Pulse — instrument cluster HUD with BLE + vertical side slides."""

from __future__ import annotations

import os
import sys
from datetime import datetime

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from dotenv import load_dotenv

load_dotenv()

import dash_bootstrap_components as dbc
import dash_leaflet as dl
from dash import ALL, Dash, Input, Output, State, callback, clientside_callback, ctx, dcc, html

from tesla_dash.tesla import get_vehicle_state
from tesla_dash.tesla.ble import get_ble_session

GEARS = ["P", "R", "N", "D"]
SLIDES = ["media", "tires", "map"]
SLIDE_LABELS = {"media": "Medya", "tires": "Lastik", "map": "Harita"}
LIGHT_TILES = "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
TILE_ATTR = "&copy; OSM &copy; CARTO"

app = Dash(
    __name__,
    external_stylesheets=[dbc.themes.DARKLY],
    suppress_callback_exceptions=True,
    title="TESLA PULSE · BLE",
    update_title=None,
)
server = app.server


@server.post("/api/ble/demo")
def api_ble_demo():
    return get_ble_session().connect_demo().to_dict()


@server.post("/api/ble/disconnect")
def api_ble_disconnect():
    return get_ble_session().disconnect().to_dict()


@server.get("/api/ble/status")
def api_ble_status():
    return get_ble_session().snapshot()


@server.post("/api/ble/scan")
def api_ble_scan():
    return get_ble_session().scan_bleak(timeout=4.0)


def _gear_row(active: str) -> html.Div:
    return html.Div(
        [html.Span(g, className=f"gear{' on' if g == active else ''}") for g in GEARS],
        className="gear-line",
    )


def _dots(side: str, active: int = 0) -> html.Div:
    return html.Div(
        [
            html.Button(
                "",
                id={"type": "slide-dot", "side": side, "index": i},
                n_clicks=0,
                className=f"slide-dot{' on' if i == active else ''}",
                title=SLIDE_LABELS[SLIDES[i]],
            )
            for i in range(3)
        ],
        className="slide-dots",
        id=f"{side}-dots",
    )


def _media_block(prefix: str) -> html.Div:
    return html.Div(
        className="slide media-slide",
        children=[
            html.Div(id=f"{prefix}-media-service", className="media-service"),
            html.Div(className="album-art", children=html.Div(className="album-glow")),
            html.Div(id=f"{prefix}-media-title", className="media-title"),
            html.Div(id=f"{prefix}-media-artist", className="media-artist"),
            html.Div(
                className="media-bar",
                children=html.Div(id=f"{prefix}-media-fill", className="media-bar-fill"),
            ),
            html.Div(
                className="media-controls",
                children=[
                    html.Span("⏮", className="mc"),
                    html.Span("⏯", className="mc play"),
                    html.Span("⏭", className="mc"),
                ],
            ),
        ],
    )


def _tires_block(prefix: str) -> html.Div:
    def cell(key: str, label: str) -> html.Div:
        return html.Div(
            className="tire-cell",
            id=f"{prefix}-tire-{key}-wrap",
            children=[
                html.Div(id=f"{prefix}-tire-{key}", className="tire-val"),
                html.Div("bar", className="tire-unit"),
                html.Div(label, className="tire-label"),
            ],
        )

    return html.Div(
        className="slide tires-slide",
        children=[
            html.Div("LASTİK BASINCI", className="slide-heading"),
            html.Div(
                className="tire-grid",
                children=[
                    cell("fl", "ÖN SOL"),
                    cell("fr", "ÖN SAĞ"),
                    html.Div(className="tire-car"),
                    cell("rl", "ARKA SOL"),
                    cell("rr", "ARKA SAĞ"),
                ],
            ),
            html.Div("Yukarı / aşağı kaydır", className="slide-hint"),
        ],
    )


def _map_block(side: str) -> html.Div:
    mid = f"{side}-map"
    return html.Div(
        className="slide map-slide",
        children=[
            dl.Map(
                id=mid,
                center=[41.025, 29.02],
                zoom=16,
                zoomControl=False,
                attributionControl=False,
                scrollWheelZoom=False,
                className="side-map",
                style={"width": "100%", "height": "100%"},
                children=[
                    dl.TileLayer(url=LIGHT_TILES, attribution=TILE_ATTR),
                    dl.Polyline(
                        id=f"{mid}-trail",
                        positions=[],
                        color="#E82127",
                        weight=4,
                        opacity=0.85,
                    ),
                    dl.Marker(id=f"{mid}-marker", position=[41.025, 29.02]),
                    html.Div("N", className="compass"),
                ],
            ),
            html.Div(id=f"{side}-map-odo", className="map-odo"),
        ],
    )


def _side_panel(side: str, initial_index: int) -> html.Aside:
    return html.Aside(
        id=f"{side}-panel",
        className=f"side-panel {side}-panel",
        children=[
            html.Div(
                className="carousel-host",
                children=[
                    html.Div(
                        id=f"{side}-carousel",
                        className="carousel-track",
                        **{"data-index": str(initial_index)},
                        style={"transform": f"translateY(-{initial_index * 100}%)"},
                        children=[
                            _media_block(side),
                            _tires_block(side),
                            _map_block(side),
                        ],
                    )
                ],
            ),
            _dots(side, initial_index),
            html.Div("↕ kaydır", className="swipe-cue"),
        ],
    )


app.layout = html.Div(
    [
        dcc.Store(id="ble-store", data={"connected": False, "source": "none"}),
        dcc.Store(id="left-slide-store", data=0),
        dcc.Store(id="right-slide-store", data=2),
        dcc.Interval(id="tick", interval=1000, n_intervals=0),
        html.Div(
            id="cluster",
            className="cluster",
            children=[
                html.Header(
                    className="topbar",
                    children=[
                        html.Div(
                            className="top-left",
                            children=[
                                html.Span(id="clock", className="clock"),
                                html.Span(id="out-temp", className="out-temp"),
                                html.Span(id="ble-pill", className="ble-pill"),
                            ],
                        ),
                        html.Div(
                            className="top-right",
                            children=[
                                html.Button(
                                    [html.Span("↻", className="ico"), " Bağlan"],
                                    id="ble-btn",
                                    n_clicks=0,
                                    className="reconnect-btn",
                                    title="Bluetooth Low Energy bağlan / kes",
                                ),
                                html.Span("▮▮▯ 50%", className="phone-batt"),
                                html.Span("⚙", className="settings-ico"),
                            ],
                        ),
                    ],
                ),
                html.Div(
                    className="triad",
                    children=[
                        _side_panel("left", 0),
                        html.Main(
                            className="center-panel",
                            children=[
                                html.Div(id="gear-display", className="gear-wrap"),
                                html.Div(
                                    className="speed-ring",
                                    children=[
                                        html.Div(id="speed-num", className="speed-num", children="0"),
                                        html.Div("km/h", className="speed-unit"),
                                    ],
                                ),
                                html.Div(
                                    className="place-row",
                                    children=[
                                        html.Span("📍", className="pin"),
                                        html.Span(id="street", className="street"),
                                    ],
                                ),
                            ],
                        ),
                        _side_panel("right", 2),
                    ],
                ),
                html.Footer(
                    className="bottombar",
                    children=[
                        html.Div(
                            className="batt-chip",
                            children=[
                                html.Span(id="batt-ico", className="batt-ico"),
                                html.Span(id="batt-pct", className="batt-pct"),
                                html.Span(id="batt-range", className="batt-range"),
                            ],
                        ),
                        html.Div(className="home-bar"),
                        html.Div(id="mode-line", className="mode-line"),
                    ],
                ),
            ],
        ),
    ]
)


clientside_callback(
    """
    async function(n, ble) {
        if (!n) { return window.dash_clientside.no_update; }
        const linked = ble && ble.connected;
        if (linked) {
            if (window.TeslaBLE) { await window.TeslaBLE.disconnect(); }
            try { await fetch('/api/ble/disconnect', {method:'POST'}); } catch(e) {}
            return {connected:false, source:'none', disconnect:true};
        }
        if (window.TeslaBLE) {
            const snap = await window.TeslaBLE.connect();
            if (snap.demo_fallback && !snap.connected) {
                try {
                    const r = await fetch('/api/ble/demo', {method:'POST'});
                    return await r.json();
                } catch(e) {
                    return {connected:true, source:'demo', device_name:'Model S Plaid · BLE',
                            device_id:'ble-demo', rssi:-52};
                }
            }
            return snap;
        }
        try {
            const r = await fetch('/api/ble/demo', {method:'POST'});
            return await r.json();
        } catch(e) {
            return {connected:true, source:'demo', device_name:'Model S Plaid · BLE', rssi:-52};
        }
    }
    """,
    Output("ble-store", "data"),
    Input("ble-btn", "n_clicks"),
    State("ble-store", "data"),
    prevent_initial_call=True,
)


# Slide transform + dots (clientside, smooth)
clientside_callback(
    """
    function(left, right) {
        left = ((left % 3) + 3) % 3;
        right = ((right % 3) + 3) % 3;
        function apply(side, idx) {
            const track = document.getElementById(side + '-carousel');
            if (track) {
                track.style.transform = 'translateY(-' + (idx * 100) + '%)';
                track.dataset.index = String(idx);
            }
            const dots = document.querySelectorAll('button[id*=\"\\\"side\\\":\\\"' + side + '\\\"\"]');
            // fallback query
            document.querySelectorAll('#' + side + '-dots .slide-dot').forEach((d, i) => {
                d.classList.toggle('on', i === idx);
            });
        }
        apply('left', left);
        apply('right', right);
        return window.dash_clientside.no_update;
    }
    """,
    Output("cluster", "data-slides"),
    Input("left-slide-store", "data"),
    Input("right-slide-store", "data"),
)


@callback(
    Output("left-slide-store", "data", allow_duplicate=True),
    Output("right-slide-store", "data", allow_duplicate=True),
    Input({"type": "slide-dot", "side": ALL, "index": ALL}, "n_clicks"),
    State("left-slide-store", "data"),
    State("right-slide-store", "data"),
    prevent_initial_call=True,
)
def on_dot_click(n_clicks, left_i, right_i):
    if not ctx.triggered_id or not any(n_clicks or []):
        return left_i or 0, right_i if right_i is not None else 2
    tid = ctx.triggered_id
    side = tid["side"]
    idx = int(tid["index"])
    if side == "left":
        return idx, right_i if right_i is not None else 2
    return left_i or 0, idx


def _fill_side_outputs(prefix: str, state: dict) -> list:
    pct = float(state.get("media_progress") or 0) * 100
    tires = []
    for key in ("fl", "fr", "rl", "rr"):
        val = float(state.get(f"tire_{key}") or 0)
        tires.append(f"{val:.1f}")
        tires.append(f"tire-cell{' low' if val < 2.4 else ''}")
    return [
        state.get("media_service") or "Music",
        state.get("media_title") or "—",
        state.get("media_artist") or "—",
        {"width": f"{pct}%"},
        *tires,
    ]


@callback(
    Output("clock", "children"),
    Output("out-temp", "children"),
    Output("ble-pill", "children"),
    Output("ble-pill", "className"),
    Output("ble-btn", "children"),
    Output("ble-btn", "className"),
    Output("gear-display", "children"),
    Output("speed-num", "children"),
    Output("street", "children"),
    Output("batt-pct", "children"),
    Output("batt-range", "children"),
    Output("batt-ico", "className"),
    Output("batt-ico", "style"),
    Output("mode-line", "children"),
    # left media/tires
    Output("left-media-service", "children"),
    Output("left-media-title", "children"),
    Output("left-media-artist", "children"),
    Output("left-media-fill", "style"),
    Output("left-tire-fl", "children"),
    Output("left-tire-fl-wrap", "className"),
    Output("left-tire-fr", "children"),
    Output("left-tire-fr-wrap", "className"),
    Output("left-tire-rl", "children"),
    Output("left-tire-rl-wrap", "className"),
    Output("left-tire-rr", "children"),
    Output("left-tire-rr-wrap", "className"),
    # right media/tires
    Output("right-media-service", "children"),
    Output("right-media-title", "children"),
    Output("right-media-artist", "children"),
    Output("right-media-fill", "style"),
    Output("right-tire-fl", "children"),
    Output("right-tire-fl-wrap", "className"),
    Output("right-tire-fr", "children"),
    Output("right-tire-fr-wrap", "className"),
    Output("right-tire-rl", "children"),
    Output("right-tire-rl-wrap", "className"),
    Output("right-tire-rr", "children"),
    Output("right-tire-rr-wrap", "className"),
    # maps
    Output("left-map", "center"),
    Output("left-map-marker", "position"),
    Output("left-map-trail", "positions"),
    Output("left-map-odo", "children"),
    Output("right-map", "center"),
    Output("right-map-marker", "position"),
    Output("right-map-trail", "positions"),
    Output("right-map-odo", "children"),
    Input("tick", "n_intervals"),
    Input("ble-store", "data"),
)
def refresh(_n, ble_store):
    state = get_vehicle_state()
    session = get_ble_session().snapshot()
    ble = {**session, **(ble_store or {})}
    if ble_store and ble_store.get("connected"):
        ble["connected"] = True
        for k in ("device_name", "device_id", "rssi", "source"):
            if ble_store.get(k) not in (None, ""):
                ble[k] = ble_store[k]
    elif ble_store and ble_store.get("disconnect"):
        ble["connected"] = False

    linked = bool(ble.get("connected"))
    if not linked:
        display = dict(state)
        display["speed_kmh"] = 0
        display["gear"] = "P"
        gear = "P"
    else:
        display = state
        gear = (state.get("gear") or "P").upper()
        if gear not in GEARS:
            gear = "P"

    lat = float(display.get("latitude") or 41.025)
    lon = float(display.get("longitude") or 29.02)
    trail = display.get("trail") or [[lat, lon]]
    positions = [[float(p[0]), float(p[1])] for p in trail if len(p) >= 2]
    if not linked:
        positions = []

    odo = f"ODO {int(display.get('odometer_km') or 0):,}km".replace(",", ".")
    batt = float(display.get("battery_percent") or 0)
    batt_cls = "batt-ico"
    if batt < 20:
        batt_cls += " low"
    elif display.get("charging"):
        batt_cls += " charge"

    if linked:
        rssi = ble.get("rssi")
        pill = f"BLE {rssi} dBm" if rssi is not None else "BLE LINK"
        pill_cls = "ble-pill on"
        btn_children = [html.Span("✕", className="ico"), " Kes"]
        btn_cls = "reconnect-btn on"
        mode = f"{ble.get('device_name') or 'Tesla'} · {(ble.get('source') or 'ble').upper()}"
    else:
        pill = "BLE HAZIR"
        pill_cls = "ble-pill"
        btn_children = [html.Span("↻", className="ico"), " Bağlan"]
        btn_cls = "reconnect-btn"
        mode = "Bluetooth Low Energy bekleniyor"

    left_bits = _fill_side_outputs("left", display)
    right_bits = _fill_side_outputs("right", display)

    return (
        datetime.now().strftime("%H:%M"),
        f"{int(display.get('outside_temp_c') or 0)}°C",
        pill,
        pill_cls,
        btn_children,
        btn_cls,
        _gear_row(gear),
        f"{int(display.get('speed_kmh') or 0)}",
        display.get("street") or "—",
        f"%{int(batt)}",
        f"{int(display.get('battery_range_km') or 0)} km",
        batt_cls,
        {"--batt-fill": f"{max(4, min(100, batt)):.0f}%"},
        mode,
        *left_bits,
        *right_bits,
        [lat, lon],
        [lat, lon],
        positions,
        odo,
        [lat, lon],
        [lat, lon],
        positions,
        odo,
    )


def main():
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8050"))
    debug = os.getenv("DEBUG", "false").lower() in {"1", "true", "yes"}
    app.run(host=host, port=port, debug=debug)


if __name__ == "__main__":
    main()
