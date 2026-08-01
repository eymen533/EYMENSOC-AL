"""Tesla Pulse — cinematic vehicle Dash HUD with B/L (Black/Light) themes."""

from __future__ import annotations

import os
import sys

# Allow `python -m` / direct run from repo root or package dir
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

GEARS = ["P", "R", "N", "D"]

DARK_TILES = (
    "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
)
LIGHT_TILES = (
    "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
)
TILE_ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; CARTO'

app = Dash(
    __name__,
    external_stylesheets=[dbc.themes.DARKLY],
    suppress_callback_exceptions=True,
    title="TESLA PULSE",
    update_title=None,
)
server = app.server


def _gear_row(active: str) -> html.Div:
    return html.Div(
        [
            html.Div(
                g,
                className=f"gear-slot{' active' if g == active else ''}",
            )
            for g in GEARS
        ],
        className="gear-row",
    )


def _flags(state: dict) -> list:
    flags = []
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


app.layout = html.Div(
    [
        dcc.Store(id="theme-store", data="dark"),
        dcc.Store(id="trail-store", data=[]),
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
                                            "PULSE  ·  VEHICLE HUD",
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
                                                    className="status-dot",
                                                    id="conn-dot",
                                                ),
                                                html.Span(id="conn-label", children="DEMO"),
                                            ],
                                        ),
                                        html.Button(
                                            "B / L",
                                            id="theme-btn",
                                            className="theme-toggle",
                                            n_clicks=0,
                                            title="Black / Light tema",
                                        ),
                                    ],
                                ),
                            ],
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


clientside_callback(
    """
    function(theme) {
        return {"data-theme": theme || "dark"};
    }
    """,
    Output("stage", "data-theme"),
    Input("theme-store", "data"),
)


@callback(
    Output("theme-store", "data"),
    Input("theme-btn", "n_clicks"),
    State("theme-store", "data"),
    prevent_initial_call=True,
)
def toggle_theme(n, theme):
    return "light" if theme == "dark" else "dark"


@callback(
    Output("theme-btn", "children"),
    Input("theme-store", "data"),
)
def theme_btn_label(theme):
    return "B → L" if theme == "dark" else "L → B"


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
    Output("temp-out", "children"),
    Output("temp-in", "children"),
    Output("heading", "children"),
    Output("speed-text", "children"),
    Output("coords", "children"),
    Output("mode-badge", "children"),
    Output("odo", "children"),
    Output("conn-label", "children"),
    Output("conn-dot", "className"),
    Output("car-marker", "position"),
    Output("car-tooltip", "children"),
    Output("trail-line", "positions"),
    Output("map", "center"),
    Output("tiles", "url"),
    Output("trail-line", "color"),
    Input("tick", "n_intervals"),
    Input("theme-store", "data"),
)
def refresh(_n, theme):
    state = get_vehicle_state()
    theme = theme or "dark"

    gear = (state.get("gear") or "P").upper()
    if gear not in GEARS:
        gear = "P"

    lat = float(state.get("latitude") or 41.025)
    lon = float(state.get("longitude") or 29.02)
    trail = state.get("trail") or [[lat, lon]]
    # dash-leaflet wants [lat, lon]
    positions = [[float(p[0]), float(p[1])] for p in trail if len(p) >= 2]

    mode = state.get("mode") or "demo"
    connected = bool(state.get("connected"))
    label = "CANLI" if mode == "live" else "DEMO"
    dot_cls = "status-dot" if connected else "status-dot offline"

    tile_url = DARK_TILES if theme == "dark" else LIGHT_TILES
    trail_color = "#3DE7C5" if theme == "dark" else "#0D9488"

    return (
        speed_gauge(state["speed_kmh"], state["power_kw"], theme),
        battery_gauge(
            state["battery_percent"],
            state["battery_range_km"],
            state["charging"],
            theme,
        ),
        power_spark(state["power_kw"], theme),
        _gear_row(gear),
        state.get("vehicle_name") or "Tesla",
        _flags(state),
        _fmt_charge_time(state.get("minutes_to_full") or 0),
        f"{state.get('charge_rate_kw', 0):.0f} kW",
        f"%{state.get('charge_limit', 90)}",
        f"{state.get('battery_range_km', 0):.0f} km",
        f"{state.get('outside_temp_c', 0):.1f}°C",
        f"{state.get('inside_temp_c', 0):.1f}°C",
        f"{state.get('heading', 0):.0f}°",
        f"{state.get('speed_kmh', 0):.0f} km/h",
        f"{lat:.5f}° N  ·  {lon:.5f}° E",
        f"{'LIVE LINK' if mode == 'live' else 'SIMULATION'}  ·  {state.get('model', 'Tesla')}",
        f"ODO  {state.get('odometer_km', 0):,.0f} km".replace(",", "."),
        label,
        dot_cls,
        [lat, lon],
        state.get("vehicle_name") or "Tesla",
        positions,
        [lat, lon],
        tile_url,
        trail_color,
    )


def main():
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8050"))
    debug = os.getenv("DEBUG", "false").lower() in {"1", "true", "yes"}
    app.run(host=host, port=port, debug=debug)


if __name__ == "__main__":
    main()
