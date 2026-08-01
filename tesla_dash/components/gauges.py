"""Visual building blocks: speed ring, battery arc, power."""

from __future__ import annotations

import plotly.graph_objects as go

TESLA_RED = "#E82127"
CYAN = "#3DE7C5"
AMBER = "#F5A623"


def _theme_colors(theme: str) -> dict[str, str]:
    if theme == "light":
        return {
            "bg": "rgba(0,0,0,0)",
            "paper": "rgba(0,0,0,0)",
            "text": "#0B0B0C",
            "muted": "rgba(11,11,12,0.35)",
            "track": "rgba(11,11,12,0.12)",
        }
    return {
        "bg": "rgba(0,0,0,0)",
        "paper": "rgba(0,0,0,0)",
        "text": "#F4F4F5",
        "muted": "rgba(244,244,245,0.4)",
        "track": "rgba(255,255,255,0.12)",
    }


def speed_gauge(speed: float, power_kw: float, theme: str = "dark") -> go.Figure:
    c = _theme_colors(theme)
    speed = max(0.0, min(260.0, float(speed)))
    accent = CYAN if power_kw >= 0 else TESLA_RED

    fig = go.Figure(
        go.Indicator(
            mode="gauge+number",
            value=speed,
            number={
                "font": {
                    "size": 72,
                    "color": c["text"],
                    "family": "Orbitron, sans-serif",
                },
                "suffix": "",
                "valueformat": ".0f",
            },
            title={
                "text": "km/h",
                "font": {
                    "size": 14,
                    "color": c["muted"],
                    "family": "Space Grotesk, sans-serif",
                },
            },
            gauge={
                "axis": {
                    "range": [0, 260],
                    "tickwidth": 1,
                    "tickcolor": c["muted"],
                    "tickfont": {"color": c["muted"], "size": 10},
                },
                "bar": {"color": accent, "thickness": 0.28},
                "bgcolor": "rgba(0,0,0,0)",
                "borderwidth": 0,
                "steps": [
                    {"range": [0, 260], "color": c["track"]},
                    {"range": [0, speed], "color": "rgba(61,231,197,0.08)"},
                ],
                "threshold": {
                    "line": {"color": TESLA_RED, "width": 2},
                    "thickness": 0.7,
                    "value": 200,
                },
            },
        )
    )
    fig.update_layout(
        margin=dict(l=20, r=20, t=40, b=10),
        paper_bgcolor=c["paper"],
        plot_bgcolor=c["bg"],
        height=280,
        font={"color": c["text"]},
    )
    return fig


def battery_gauge(
    percent: float,
    range_km: float,
    charging: bool,
    theme: str = "dark",
) -> go.Figure:
    c = _theme_colors(theme)
    percent = max(0.0, min(100.0, float(percent)))
    if percent < 20:
        color = TESLA_RED
    elif percent < 40:
        color = AMBER
    else:
        color = CYAN if charging else "#6EE7B7"

    fig = go.Figure(
        go.Indicator(
            mode="gauge+number",
            value=percent,
            number={
                "font": {
                    "size": 48,
                    "color": c["text"],
                    "family": "Orbitron, sans-serif",
                },
                "suffix": "%",
                "valueformat": ".0f",
            },
            title={
                "text": f"{range_km:.0f} km menzil"
                + (" · ŞARJ" if charging else ""),
                "font": {
                    "size": 13,
                    "color": c["muted"],
                    "family": "Space Grotesk, sans-serif",
                },
            },
            gauge={
                "axis": {
                    "range": [0, 100],
                    "tickwidth": 0,
                    "tickcolor": "rgba(0,0,0,0)",
                    "visible": False,
                },
                "bar": {"color": color, "thickness": 0.35},
                "bgcolor": "rgba(0,0,0,0)",
                "borderwidth": 0,
                "steps": [{"range": [0, 100], "color": c["track"]}],
            },
        )
    )
    fig.update_layout(
        margin=dict(l=16, r=16, t=36, b=8),
        paper_bgcolor=c["paper"],
        plot_bgcolor=c["bg"],
        height=220,
        font={"color": c["text"]},
    )
    return fig


def power_spark(power_kw: float, theme: str = "dark") -> go.Figure:
    c = _theme_colors(theme)
    val = float(power_kw)
    color = CYAN if val >= 0 else TESLA_RED
    fig = go.Figure(
        go.Indicator(
            mode="number",
            value=val,
            number={
                "font": {
                    "size": 36,
                    "color": color,
                    "family": "Orbitron, sans-serif",
                },
                "suffix": " kW",
                "valueformat": "+.0f" if val >= 0 else ".0f",
            },
            title={
                "text": "GÜÇ",
                "font": {
                    "size": 12,
                    "color": c["muted"],
                    "family": "Space Grotesk, sans-serif",
                },
            },
        )
    )
    fig.update_layout(
        margin=dict(l=10, r=10, t=30, b=10),
        paper_bgcolor=c["paper"],
        height=100,
    )
    return fig
