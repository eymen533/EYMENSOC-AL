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

from tesla_dash.auth import register_auth
from tesla_dash.prayer import next_prayer
from tesla_dash.tesla import get_vehicle_state
from tesla_dash.tesla.ble import get_ble_session

DIAL_STYLES = [
    {"id": "bmw", "title": "BMW Diagonal", "desc": "Trapez cam · sıcak amber metal"},
    {"id": "porsche", "title": "Porsche Sport", "desc": "Kokpit kesit · siyah / racing kırmızı"},
    {"id": "mercedes", "title": "Mercedes Glass", "desc": "Hyperscreen cam · gümüş / şampanya"},
    {"id": "audi", "title": "Audi Quattro", "desc": "Keskin kanat · platin / buz mavisi"},
]

TR_WEEKDAYS = [
    "Pazartesi",
    "Salı",
    "Çarşamba",
    "Perşembe",
    "Cuma",
    "Cumartesi",
    "Pazar",
]
TR_MONTHS = [
    "",
    "Oca",
    "Şub",
    "Mar",
    "Nis",
    "May",
    "Haz",
    "Tem",
    "Ağu",
    "Eyl",
    "Eki",
    "Kas",
    "Ara",
]

GEARS = ["P", "R", "N", "D"]
SLIDES = ["trip", "tires", "map", "media"]
SLIDE_LABELS = {
    "trip": "Seyahat",
    "tires": "Lastik",
    "map": "Harita",
    "media": "Medya",
}
LIGHT_TILES = "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
TILE_ATTR = "&copy; OSM &copy; CARTO"

app = Dash(
    __name__,
    external_stylesheets=[dbc.themes.DARKLY],
    suppress_callback_exceptions=True,
    title="TESLA PULSE · Özel",
    update_title=None,
)
server = app.server
register_auth(server)

app.index_string = """
<!DOCTYPE html>
<html>
  <head>
    {%metas%}
    <title>{%title%}</title>
    <meta name="apple-mobile-web-app-capable" content="yes" />
    <meta name="mobile-web-app-capable" content="yes" />
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
    <meta name="apple-mobile-web-app-title" content="Pulse" />
    <meta name="theme-color" content="#07080a" />
    <link rel="manifest" href="/manifest.webmanifest" />
    <link rel="apple-touch-icon" href="/assets/icons/apple-touch-icon.png" />
    {%favicon%}
    {%css%}
  </head>
  <body>
    {%app_entry%}
    <footer>
      {%config%}
      {%scripts%}
      {%renderer%}
    </footer>
    <script>
      if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(function () {});
      }
    </script>
  </body>
</html>
"""


@server.post("/api/ble/demo")
def api_ble_demo():
    from flask import request

    body = request.get_json(silent=True) or {}
    vin = body.get("vin")
    return get_ble_session().connect_demo(vin=vin).to_dict()


@server.post("/api/ble/disconnect")
def api_ble_disconnect():
    return get_ble_session().disconnect().to_dict()


@server.get("/api/ble/status")
def api_ble_status():
    return get_ble_session().snapshot()


@server.post("/api/ble/scan")
def api_ble_scan():
    return get_ble_session().scan_bleak(timeout=4.0)


@server.post("/api/ble/vin")
def api_ble_vin():
    from flask import request

    body = request.get_json(silent=True) or {}
    return get_ble_session().set_vin(body.get("vin") or "")


@server.post("/api/ble/card")
def api_ble_card():
    return get_ble_session().tap_card()


@server.post("/api/ble/pair")
def api_ble_pair():
    from flask import request

    body = request.get_json(silent=True) or {}
    return get_ble_session().pair_and_connect(
        vin=body.get("vin") or "",
        card_tapped=bool(body.get("card_tapped", True)),
        source=body.get("source") or "demo",
    )


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
            for i in range(len(SLIDES))
        ],
        className="slide-dots",
        id=f"{side}-dots",
    )


def _trip_block(prefix: str) -> html.Div:
    """Left-cluster trip readout — Destination / Arrival / Energy / Distance."""
    rows = [
        ("Destination", f"{prefix}-trip-dest"),
        ("Arrival Time", f"{prefix}-trip-eta"),
        ("Energy at Arrival", f"{prefix}-trip-energy"),
        ("Distance", f"{prefix}-trip-dist"),
    ]
    return html.Div(
        className="slide trip-slide",
        children=[
            html.Div(
                className="trip-list",
                children=[
                    html.Div(
                        className="trip-row",
                        children=[
                            html.Div(label, className="trip-label"),
                            html.Div(id=eid, className="trip-value", children="--"),
                        ],
                    )
                    for label, eid in rows
                ],
            )
        ],
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


def _model_y_visual() -> html.Div:
    """Photoreal top-down Model Y for PSI view."""
    return html.Div(
        className="model-y",
        children=html.Img(
            src="/assets/model-y-top.png",
            className="model-y-photo",
            alt="Model Y",
            draggable="false",
        ),
    )


def _tires_block(prefix: str) -> html.Div:
    def psi(key: str, corner: str) -> html.Div:
        return html.Div(
            className=f"psi-tag {corner}",
            id=f"{prefix}-tire-{key}-wrap",
            children=[
                html.Span(id=f"{prefix}-tire-{key}", className="psi-val"),
                html.Span(" psi", className="psi-unit"),
            ],
        )

    return html.Div(
        className="slide tires-slide",
        children=[
            html.Div(
                className="psi-stage",
                children=[
                    psi("fl", "fl"),
                    psi("fr", "fr"),
                    _model_y_visual(),
                    psi("rl", "rl"),
                    psi("rr", "rr"),
                ],
            ),
        ],
    )


def _telltale_row() -> html.Div:
    """Center-console exterior light / indicator telltales."""
    items = [
        ("tl-left", "Sol sinyal"),
        ("tl-parking", "Park"),
        ("tl-low", "Kısa far"),
        ("tl-high", "Uzun far"),
        ("tl-fog", "Sis"),
        ("tl-right", "Sağ sinyal"),
    ]
    return html.Div(
        id="telltale-row",
        className="telltale-row",
        children=[
            html.Span(id=tid, className=f"telltale {tid}", title=title)
            for tid, title in items
        ],
    )


def _select_rail(side: str) -> html.Div:
    """Narrow dark pill rail — flashes on selection, hides after 1.02s."""
    items = [
        ("dash", "0", "Seyahat"),
        ("gear", "1", "Lastik"),
        ("nav", "2", "Navigasyon"),
        ("map", "2", "Harita"),
        ("music", "3", "Medya"),
    ]
    default_on = "dash" if side == "left" else "nav"
    buttons = [
        html.Button(
            html.Span(className=f"ri ri-{kind}"),
            className=f"rail-item{' on' if kind == default_on else ''}",
            **{"data-i": slide_i, "data-kind": kind, "data-side": side},
            title=title,
            n_clicks=0,
        )
        for kind, slide_i, title in items
    ]
    return html.Div(
        id=f"select-rail-{side}",
        className=f"select-rail {side}-rail",
        **{"data-side": side},
        children=html.Div(className="rail-pill", children=buttons),
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
                            _trip_block(side),
                            _tires_block(side),
                            _map_block(side),
                            _media_block(side),
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
        dcc.Store(id="pair-ui", data={"open": False, "step": 1, "vin": "", "error": ""}),
        dcc.Store(id="left-slide-store", data=0),
        dcc.Store(id="right-slide-store", data=2),
        dcc.Store(id="theme-store", data="night"),
        dcc.Store(id="dial-style-store", data="bmw"),
        dcc.Store(id="settings-open", data=False),
        dcc.Interval(id="tick", interval=1000, n_intervals=0),
        # ——— Pairing modal (VIN + Tesla Card) ———
        html.Div(
            id="pair-overlay",
            className="pair-overlay hidden",
            children=[
                html.Div(
                    className="pair-sheet",
                    children=[
                        html.Button("✕", id="pair-close", className="pair-close", n_clicks=0),
                        html.Div("TESLA", className="pair-brand"),
                        html.H2("BLE Eşleşme", className="pair-title"),
                        html.P(
                            "Diğer uygulamalar gibi önce VIN, sonra Tesla Key Card ile eşleşin.",
                            className="pair-sub",
                        ),
                        html.Div(
                            className="pair-steps",
                            children=[
                                html.Span("1 VIN", id="step-chip-1", className="step-chip on"),
                                html.Span("2 Kart", id="step-chip-2", className="step-chip"),
                                html.Span("3 BLE", id="step-chip-3", className="step-chip"),
                            ],
                        ),
                        html.Div(
                            id="pair-step-vin",
                            className="pair-pane",
                            children=[
                                html.Label("Araç VIN kodu", className="pair-label"),
                                dcc.Input(
                                    id="vin-input",
                                    type="text",
                                    placeholder="Örn. 5YJ3E1EA1KF317284",
                                    maxLength=17,
                                    className="vin-input",
                                    value="",
                                    debounce=False,
                                ),
                                html.Div(id="vin-hint", className="vin-hint", children="17 karakter · I / O / Q yok"),
                                html.Button(
                                    "Devam",
                                    id="vin-next",
                                    n_clicks=0,
                                    className="pair-primary",
                                ),
                                html.Button(
                                    "Demo VIN kullan",
                                    id="vin-demo",
                                    n_clicks=0,
                                    className="pair-ghost",
                                ),
                            ],
                        ),
                        html.Div(
                            id="pair-step-card",
                            className="pair-pane hidden",
                            children=[
                                html.Div(className="card-visual", children=[
                                    html.Div("TESLA", className="card-logo"),
                                    html.Div("KEY CARD", className="card-sub"),
                                    html.Div(className="card-chip"),
                                    html.Div(id="card-vin-tag", className="card-vin"),
                                ]),
                                html.P(
                                    "Anahtarsız giriş kartını telefonun NFC alanına (veya ekrana) yaklaştırın.",
                                    className="pair-sub",
                                ),
                                html.Button(
                                    "Kartı okut / Onayla",
                                    id="card-tap",
                                    n_clicks=0,
                                    className="pair-primary",
                                ),
                                html.Button(
                                    "Geri",
                                    id="card-back",
                                    n_clicks=0,
                                    className="pair-ghost",
                                ),
                            ],
                        ),
                        html.Div(
                            id="pair-step-ble",
                            className="pair-pane hidden",
                            children=[
                                html.Div(className="ble-radar", children=html.Div(className="ble-radar-ring")),
                                html.P(id="ble-pair-msg", className="pair-sub", children="Yakındaki Tesla aranıyor…"),
                                html.Button(
                                    "BLE Bağlan",
                                    id="ble-finish",
                                    n_clicks=0,
                                    className="pair-primary",
                                ),
                            ],
                        ),
                        html.Div(id="pair-error", className="pair-error"),
                    ],
                )
            ],
        ),
        html.Div(
            id="cluster",
            className="cluster theme-night dial-bmw",
            children=[
                html.Header(
                    className="topbar",
                    children=[
                        html.Div(
                            className="top-left",
                            children=[
                                html.Div(
                                    className="datetime-block",
                                    children=[
                                        html.Span(id="day-name", className="day-name"),
                                        html.Span(id="date-line", className="date-line"),
                                    ],
                                ),
                                html.Span(id="clock", className="clock"),
                                html.Div(
                                    className="prayer-chip",
                                    title="Bir sonraki namaz",
                                    children=[
                                        html.Span("🕌", className="prayer-ico"),
                                        html.Span(id="next-prayer", className="next-prayer"),
                                    ],
                                ),
                                html.Span(id="out-temp", className="out-temp"),
                                html.Span(id="ble-pill", className="ble-pill"),
                            ],
                        ),
                        html.Div(
                            className="top-right",
                            children=[
                                html.Button(
                                    [
                                        html.Div(
                                            className="fs-speed-row",
                                            children=[
                                                html.Span(id="fs-speed", className="fs-speed", children="0"),
                                                html.Span("km/h", className="fs-unit"),
                                            ],
                                        ),
                                        html.Div(id="fs-odo", className="fs-odo", children="ODO --km"),
                                    ],
                                    id="fs-hud",
                                    n_clicks=0,
                                    className="fs-hud",
                                    title="Küme görünümüne dön",
                                ),
                                html.Button(
                                    [html.Span("↻", className="ico"), " Bağlan"],
                                    id="ble-btn",
                                    n_clicks=0,
                                    className="reconnect-btn",
                                    title="VIN + Tesla Kart + BLE eşleşme",
                                ),
                                html.Span("▮▮▯ 50%", className="phone-batt"),
                                html.Button(
                                    "⚙",
                                    id="settings-btn",
                                    n_clicks=0,
                                    className="settings-btn",
                                    title="Görünüm ayarları",
                                ),
                            ],
                        ),
                    ],
                ),
                # Settings sheet — dial style picker
                html.Div(
                    id="settings-sheet",
                    className="settings-sheet hidden",
                    children=[
                        html.Div(
                            className="settings-card",
                            children=[
                                html.Div(
                                    className="settings-head",
                                    children=[
                                        html.Span("Görünüm", className="settings-title"),
                                        html.Button("✕", id="settings-close", n_clicks=0, className="settings-close"),
                                    ],
                                ),
                                html.P(
                                    "Orta ekran paneli — BMW · Porsche · Mercedes · Audi",
                                    className="settings-sub",
                                ),
                                html.Div(
                                    className="dial-options",
                                    children=[
                                        html.Button(
                                            [
                                                html.Span(className=f"dial-preview dial-preview-{opt['id']}"),
                                                html.Span(
                                                    [
                                                        html.Span(opt["title"], className="opt-title"),
                                                        html.Span(opt["desc"], className="opt-desc"),
                                                    ],
                                                    className="opt-text",
                                                ),
                                            ],
                                            id={"type": "dial-opt", "style": opt["id"]},
                                            n_clicks=0,
                                            className=f"dial-opt{' on' if opt['id'] == 'bmw' else ''}",
                                            **{"data-style": opt["id"]},
                                        )
                                        for opt in DIAL_STYLES
                                    ],
                                ),
                            ],
                        )
                    ],
                ),
                html.Div(
                    className="triad",
                    children=[
                        _side_panel("left", 0),
                        html.Main(
                            className="center-panel",
                            children=[
                                html.Div(className="center-veil"),
                                _select_rail("left"),
                                _select_rail("right"),
                                html.Div(id="gear-display", className="gear-wrap"),
                                _telltale_row(),
                                html.Div(
                                    className="speed-dial",
                                    children=[
                                        html.Div(className="speed-dial-glow"),
                                        html.Div(
                                            className="speed-dial-panel",
                                            children=[
                                                html.Div(className="speed-dial-mesh"),
                                                html.Div(className="speed-dial-sheen"),
                                                html.Div(className="speed-dial-rim"),
                                                html.Div(
                                                    className="speed-dial-inner",
                                                    children=[
                                                        html.Div(className="speed-dial-halo"),
                                                        html.Div(
                                                            id="speed-num",
                                                            className="speed-num",
                                                            children="0",
                                                        ),
                                                        html.Div("km/h", className="speed-unit"),
                                                    ],
                                                ),
                                                html.Div(className="speed-dial-edge"),
                                            ],
                                        ),
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
                                html.Span("/", className="batt-sep"),
                                html.Span(id="batt-range", className="batt-range"),
                            ],
                        ),
                        html.Div(
                            className="place-row",
                            children=[
                                html.Span("📍", className="pin"),
                                html.Span(id="street", className="street"),
                            ],
                        ),
                        html.Div(id="footer-odo", className="footer-odo"),
                    ],
                ),
                html.Div(className="home-bar"),
                html.Div(id="mode-line", className="mode-line sr-only"),
            ],
        ),
    ]
)


# Bağlan → pairing modal aç / Kes → disconnect
clientside_callback(
    """
    async function(n, ble, pair) {
        if (!n) { return [window.dash_clientside.no_update, window.dash_clientside.no_update]; }
        const linked = ble && ble.connected;
        if (linked) {
            if (window.TeslaBLE) { await window.TeslaBLE.disconnect(); }
            try { await fetch('/api/ble/disconnect', {method:'POST'}); } catch(e) {}
            return [
                {connected:false, source:'none', disconnect:true},
                {open:false, step:1, vin:(pair&&pair.vin)||'', error:''}
            ];
        }
        return [
            window.dash_clientside.no_update,
            {open:true, step:1, vin:(pair&&pair.vin)||'', error:''}
        ];
    }
    """,
    Output("ble-store", "data"),
    Output("pair-ui", "data"),
    Input("ble-btn", "n_clicks"),
    State("ble-store", "data"),
    State("pair-ui", "data"),
    prevent_initial_call=True,
)


# Pairing UI orchestration
clientside_callback(
    """
    async function(closeN, nextN, demoN, cardN, backN, finishN, pair, vinVal) {
        const trig = dash_clientside.callback_context.triggered;
        if (!trig || !trig.length) {
            return [window.dash_clientside.no_update, window.dash_clientside.no_update];
        }
        const id = (trig[0].prop_id || '').split('.')[0];
        let ui = Object.assign({open:false, step:1, vin:'', error:''}, pair || {});

        if (id === 'pair-close') {
            ui.open = false; ui.error = '';
            return [ui, window.dash_clientside.no_update];
        }
        if (id === 'card-back') {
            ui.step = 1; ui.error = '';
            return [ui, window.dash_clientside.no_update];
        }
        if (id === 'vin-demo') {
            ui.vin = '5YJ3E1EA1KF317284';
            ui.step = 2; ui.error = '';
            try {
                await fetch('/api/ble/vin', {method:'POST', headers:{'Content-Type':'application/json'},
                    body: JSON.stringify({vin: ui.vin})});
            } catch(e) {}
            return [ui, window.dash_clientside.no_update];
        }
        if (id === 'vin-next') {
            const vin = (vinVal || ui.vin || '').replace(/\\s+/g,'').toUpperCase();
            try {
                const r = await fetch('/api/ble/vin', {method:'POST', headers:{'Content-Type':'application/json'},
                    body: JSON.stringify({vin})});
                const j = await r.json();
                if (!j.ok) { ui.error = j.error || 'VIN hatalı'; return [ui, window.dash_clientside.no_update]; }
                ui.vin = j.vin; ui.step = 2; ui.error = '';
            } catch(e) { ui.error = 'VIN doğrulanamadı'; }
            return [ui, window.dash_clientside.no_update];
        }
        if (id === 'card-tap') {
            try {
                const r = await fetch('/api/ble/card', {method:'POST'});
                const j = await r.json();
                if (!j.ok) { ui.error = j.error || 'Kart okunamadı'; return [ui, window.dash_clientside.no_update]; }
                ui.step = 3; ui.error = '';
            } catch(e) { ui.error = 'Kart adımı başarısız'; }
            return [ui, window.dash_clientside.no_update];
        }
        if (id === 'ble-finish') {
            // Try Web Bluetooth, then fall back to paired demo link with VIN
            let link = null;
            if (window.TeslaBLE) {
                const snap = await window.TeslaBLE.connect();
                if (snap && snap.connected) {
                    link = Object.assign({}, snap, {vin: ui.vin, card_paired: true, source: 'web'});
                }
            }
            if (!link) {
                try {
                    const r = await fetch('/api/ble/pair', {method:'POST', headers:{'Content-Type':'application/json'},
                        body: JSON.stringify({vin: ui.vin, card_tapped: true, source: 'demo'})});
                    link = await r.json();
                } catch(e) {
                    ui.error = 'BLE bağlantısı kurulamadı';
                    return [ui, window.dash_clientside.no_update];
                }
            }
            if (link && (link.ok === false)) {
                ui.error = link.error || 'Eşleşme başarısız';
                return [ui, window.dash_clientside.no_update];
            }
            ui.open = false; ui.error = '';
            return [ui, Object.assign({connected:true, card_paired:true}, link)];
        }
        return [window.dash_clientside.no_update, window.dash_clientside.no_update];
    }
    """,
    Output("pair-ui", "data", allow_duplicate=True),
    Output("ble-store", "data", allow_duplicate=True),
    Input("pair-close", "n_clicks"),
    Input("vin-next", "n_clicks"),
    Input("vin-demo", "n_clicks"),
    Input("card-tap", "n_clicks"),
    Input("card-back", "n_clicks"),
    Input("ble-finish", "n_clicks"),
    State("pair-ui", "data"),
    State("vin-input", "value"),
    prevent_initial_call=True,
)


# Reflect pair-ui on overlay visibility / steps
clientside_callback(
    """
    function(ui) {
        ui = ui || {open:false, step:1, vin:'', error:''};
        const step = ui.step || 1;
        ['pair-step-vin','pair-step-card','pair-step-ble'].forEach((id, i) => {
            const el = document.getElementById(id);
            if (el) el.classList.toggle('hidden', step !== (i+1));
        });
        [1,2,3].forEach(i => {
            const c = document.getElementById('step-chip-' + i);
            if (c) c.classList.toggle('on', step === i);
        });
        const tag = document.getElementById('card-vin-tag');
        if (tag) tag.textContent = ui.vin ? ('VIN · ' + ui.vin.slice(-6)) : '';
        const err = document.getElementById('pair-error');
        if (err) err.textContent = ui.error || '';
        const msg = document.getElementById('ble-pair-msg');
        if (msg && step === 3) {
            msg.textContent = ui.vin
                ? (ui.vin.slice(-6) + ' için BLE link kuruluyor…')
                : 'Yakındaki Tesla aranıyor…';
        }
        return ui.open ? 'pair-overlay' : 'pair-overlay hidden';
    }
    """,
    Output("pair-overlay", "className"),
    Input("pair-ui", "data"),
)


# Slide transform + dots + selection rail flash (1.02s)
clientside_callback(
    """
    function(left, right) {
        left = ((left % 4) + 4) % 4;
        right = ((right % 4) + 4) % 4;
        function apply(side, idx) {
            const track = document.getElementById(side + '-carousel');
            if (track) {
                track.style.transform = 'translateY(-' + (idx * 100) + '%)';
                track.dataset.index = String(idx);
            }
            document.querySelectorAll('#' + side + '-dots .slide-dot').forEach((d, i) => {
                d.classList.toggle('on', i === idx);
            });
        }
        apply('left', left);
        apply('right', right);
        const trig = (dash_clientside.callback_context.triggered || [])[0];
        let side = 'left';
        let idx = left;
        if (trig && String(trig.prop_id).indexOf('right') !== -1) {
            side = 'right'; idx = right;
        }
        if (window.TeslaCarousel && TeslaCarousel.flash) {
            TeslaCarousel.flash(side, idx);
        }
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


def _fill_side_outputs(prefix: str, state: dict, linked: bool) -> list:
    pct = float(state.get("media_progress") or 0) * 100
    tires = []
    for key in ("fl", "fr", "rl", "rr"):
        # Prefer PSI; convert bar→psi if value looks like bar (< 10)
        raw = float(state.get(f"tire_{key}") or 0)
        psi = raw if raw >= 10 else raw * 14.5038
        if linked:
            tires.append(f"{psi:.0f}")
        else:
            tires.append("--")
        tires.append(f"psi-tag {key}{' low' if linked and psi < 35 else ''}")

    def _trip_txt(key: str) -> str:
        val = state.get(key)
        if not linked or val in (None, "", "—", "-"):
            return "--"
        return str(val)

    trip = [
        _trip_txt("destination"),
        _trip_txt("arrival_time"),
        _trip_txt("energy_at_arrival"),
        _trip_txt("trip_distance_km"),
    ]

    return [
        *trip,
        state.get("media_service") or "Music",
        state.get("media_title") or "—",
        state.get("media_artist") or "—",
        {"width": f"{pct}%"},
        *tires,
    ]


def _telltale_classes(state: dict, linked: bool) -> list[str]:
    def on(flag: str, base: str) -> str:
        active = linked and bool(state.get(flag))
        return f"telltale {base}{' on' if active else ''}"

    return [
        on("turn_left", "tl-left"),
        on("light_parking", "tl-parking"),
        on("light_low", "tl-low"),
        on("light_high", "tl-high"),
        on("light_fog", "tl-fog"),
        on("turn_right", "tl-right"),
    ]


# Vehicle theme → cluster.theme-day / theme-night (keeps fs-* / dial-* classes)
clientside_callback(
    """
    function(theme) {
        const c = document.getElementById('cluster');
        if (!c) { return window.dash_clientside.no_update; }
        const t = (theme === 'day') ? 'day' : 'night';
        c.classList.remove('theme-day', 'theme-night');
        c.classList.add('theme-' + t);
        return t;
    }
    """,
    Output("cluster", "data-theme"),
    Input("theme-store", "data"),
)

# Dial style picker + settings sheet
clientside_callback(
    """
    function(nOpen, nClose, optClicks, style, isOpen) {
        const trig = (dash_clientside.callback_context.triggered || [])[0];
        if (!trig) {
            return [window.dash_clientside.no_update, window.dash_clientside.no_update];
        }
        const prop = String(trig.prop_id);
        let next = style || localStorage.getItem('pulse_dial') || 'bmw';
        let open = !!isOpen;

        if (prop.indexOf('settings-btn') !== -1) {
            open = !open;
        } else if (prop.indexOf('settings-close') !== -1) {
            open = false;
        } else if (prop.indexOf('dial-opt') !== -1) {
            try {
                const id = JSON.parse(prop.split('.')[0]);
                if (id && id.style) next = id.style;
            } catch (e) {}
            open = true;
        }

        const allowed = ['bmw','porsche','mercedes','audi'];
        // migrate legacy ids
        if (next === 'blade') next = 'porsche';
        if (next === 'obsidian') next = 'mercedes';
        if (next === 'volt') next = 'audi';
        if (allowed.indexOf(next) === -1) next = 'bmw';
        localStorage.setItem('pulse_dial', next);

        const c = document.getElementById('cluster');
        if (c) {
            ['bmw','porsche','mercedes','audi','blade','obsidian','volt'].forEach(s => c.classList.remove('dial-' + s));
            c.classList.add('dial-' + next);
        }
        document.querySelectorAll('.dial-opt').forEach(el => {
            el.classList.toggle('on', el.getAttribute('data-style') === next);
        });
        const sheet = document.getElementById('settings-sheet');
        if (sheet) sheet.classList.toggle('hidden', !open);

        return [next, open];
    }
    """,
    Output("dial-style-store", "data"),
    Output("settings-open", "data"),
    Input("settings-btn", "n_clicks"),
    Input("settings-close", "n_clicks"),
    Input({"type": "dial-opt", "style": ALL}, "n_clicks"),
    State("dial-style-store", "data"),
    State("settings-open", "data"),
    prevent_initial_call=True,
)


@callback(
    Output("theme-store", "data"),
    Output("day-name", "children"),
    Output("date-line", "children"),
    Output("clock", "children"),
    Output("next-prayer", "children"),
    Output("out-temp", "children"),
    Output("ble-pill", "children"),
    Output("ble-pill", "className"),
    Output("ble-btn", "children"),
    Output("ble-btn", "className"),
    Output("gear-display", "children"),
    Output("speed-num", "children"),
    Output("fs-speed", "children"),
    Output("fs-odo", "children"),
    Output("tl-left", "className"),
    Output("tl-parking", "className"),
    Output("tl-low", "className"),
    Output("tl-high", "className"),
    Output("tl-fog", "className"),
    Output("tl-right", "className"),
    Output("street", "children"),
    Output("batt-pct", "children"),
    Output("batt-range", "children"),
    Output("batt-ico", "className"),
    Output("batt-ico", "style"),
    Output("footer-odo", "children"),
    Output("mode-line", "children"),
    # left trip/media/tires
    Output("left-trip-dest", "children"),
    Output("left-trip-eta", "children"),
    Output("left-trip-energy", "children"),
    Output("left-trip-dist", "children"),
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
    # right trip/media/tires
    Output("right-trip-dest", "children"),
    Output("right-trip-eta", "children"),
    Output("right-trip-energy", "children"),
    Output("right-trip-dist", "children"),
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
        vin = ble.get("vin") or ""
        vin_bit = f" · VIN {vin[-6:]}" if len(vin) >= 6 else ""
        mode = f"{ble.get('device_name') or 'Tesla'}{vin_bit} · {(ble.get('source') or 'ble').upper()}"
    else:
        pill = "BLE HAZIR"
        pill_cls = "ble-pill"
        btn_children = [html.Span("↻", className="ico"), " Bağlan"]
        btn_cls = "reconnect-btn"
        mode = "VIN + Tesla Kart ile BLE eşleş"

    if linked:
        batt_pct_txt = f"{int(batt)}%"
        batt_range_txt = f"{int(display.get('battery_range_km') or 0)}km"
    else:
        batt_pct_txt = "--%"
        batt_range_txt = "--km"

    left_bits = _fill_side_outputs("left", display, linked)
    right_bits = _fill_side_outputs("right", display, linked)
    # Show exterior-light telltales from live/demo telemetry on the center dial
    telltales = _telltale_classes(display, True)

    theme = (display.get("ui_theme") or "night").lower()
    if theme not in {"day", "night"}:
        theme = "night"

    speed_txt = f"{int(display.get('speed_kmh') or 0)}"

    now = datetime.now()
    day_name = TR_WEEKDAYS[now.weekday()]
    date_line = f"{now.day} {TR_MONTHS[now.month]} {now.year}"
    try:
        lat_p = float(display.get("latitude") or 41.025)
        lon_p = float(display.get("longitude") or 29.02)
        prayer = next_prayer(lat=lat_p, lon=lon_p)
        prayer_txt = prayer.get("label") or "--"
    except Exception:
        prayer_txt = "--"

    return (
        theme,
        day_name,
        date_line,
        now.strftime("%H:%M"),
        prayer_txt,
        f"{int(display.get('outside_temp_c') or 0)}°C",
        pill,
        pill_cls,
        btn_children,
        btn_cls,
        _gear_row(gear),
        speed_txt,
        speed_txt,
        odo,
        *telltales,
        display.get("street") or "—",
        batt_pct_txt,
        batt_range_txt,
        batt_cls,
        {"--batt-fill": f"{max(4, min(100, batt)):.0f}%"},
        odo,
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
