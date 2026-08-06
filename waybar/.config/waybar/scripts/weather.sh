#!/usr/bin/env bash
# Waybar JSON weather: BOM api.weather.bom.gov.au (°C). Kensington VIC 3031 → geohash r1r0cz.
# Terms: see https://www.bom.gov.au/resources/data-services — API responses include a copyright notice.
set -uo pipefail
command -v python3 >/dev/null 2>&1 || {
  printf '%s\n' '{"text":"⚠️ Weather","tooltip":"Install python3"}'
  exit 0
}
exec python3 - "$@" <<'PY'
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime
from typing import Any, Dict, Optional
from zoneinfo import ZoneInfo

# 6-character geohash required by BOM API (from location search: Kensington, 3031, VIC).
GEO6 = "r1r0cz"
LABEL = "Kensington, Melbourne"
BASE = "https://api.weather.bom.gov.au/v1/locations/{}".format(GEO6)
UA = "Mozilla/5.0 (compatible; WaybarWeather/1.0; +personal desktop)"
TZ_MEL = ZoneInfo("Australia/Melbourne")


def out_error(msg: str) -> None:
    print(json.dumps({"text": "⚠️ Weather", "tooltip": msg}, ensure_ascii=False))
    sys.exit(0)


def get_json(path: str) -> Dict[str, Any]:
    url = "{}/{}".format(BASE, path)
    req = urllib.request.Request(url, headers={"User-Agent": UA}, method="GET")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def get_json_retry(path: str, attempts: int = 8, delay_s: float = 2.5) -> Dict[str, Any]:
    """Retry fetches after resume when DNS/routing may not be ready yet (~20s total)."""
    last_exc: Optional[Exception] = None
    for attempt in range(attempts):
        try:
            return get_json(path)
        except (OSError, urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError) as exc:
            last_exc = exc
            if attempt < attempts - 1:
                time.sleep(delay_s)
    assert last_exc is not None
    raise last_exc


def try_get_json(path: str) -> Optional[Dict[str, Any]]:
    try:
        return get_json(path)
    except (OSError, urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError):
        return None


def icon_from_descriptor(desc: str) -> str:
    if not desc:
        return "🌡️"
    x = desc.lower().replace("-", "_")
    if "storm" in x or "thunder" in x:
        return "⛈️"
    if "shower" in x or "rain" in x:
        return "🌧️"
    if "snow" in x:
        return "❄️"
    if "fog" in x or "mist" in x:
        return "🌫️"
    if "cloud" in x:
        return "☁️"
    if "sunny" in x or "clear" in x:
        return "☀️"
    return "🌡️"


def format_observation_time(iso_z: Optional[str]) -> Optional[str]:
    """Format BOM UTC timestamp for Melbourne local display."""
    if not iso_z:
        return None
    try:
        dt = datetime.fromisoformat(iso_z.replace("Z", "+00:00"))
        return dt.astimezone(TZ_MEL).strftime("%a %d %b %H:%M %Z")
    except ValueError:
        return None


def css_class_from_descriptor(key: str) -> str:
    """Stable class name for Waybar CSS (e.g. bom-sunny, bom-shower)."""
    slug = re.sub(r"[^a-z0-9]+", "-", key.lower()).strip("-")
    return "bom-{}".format(slug if slug else "unknown")


try:
    obs_body = get_json_retry("observations")
except (OSError, urllib.error.HTTPError, urllib.error.URLError, json.JSONDecodeError) as e:
    out_error("Failed to fetch observations ({})".format(e))

if obs_body.get("errors"):
    out_error(obs_body["errors"][0].get("detail", "Observation error"))

o = obs_body.get("data") or {}
if not isinstance(o, dict) or "temp" not in o:
    out_error("No observation data")

daily_body = try_get_json("forecasts/daily") or {}
days = (daily_body.get("data") or []) if isinstance(daily_body.get("data"), list) else []
day0 = days[0] if days else {}
short_text = (day0.get("short_text") or "").strip() or "—"
icon_key = day0.get("icon_descriptor") or ""
uv = day0.get("uv") or {}
uv_line = ""
if isinstance(uv, dict) and uv.get("max_index") is not None:
    uv_line = "UV (today): {} ({})".format(uv["max_index"], uv.get("category") or "—")

st = o.get("station") or {}
st_name = st.get("name", "?")
st_dist = st.get("distance")
st_line = st_name
if st_dist is not None:
    try:
        d = float(st_dist)
    except (TypeError, ValueError):
        st_line = "{} (~{})".format(st_name, st_dist)
    else:
        if d >= 1000:
            st_line = "{} (~{:.1f} km)".format(st_name, d / 1000.0)
        else:
            st_line = "{} (~{:.0f} m)".format(st_name, d)

wind = o.get("wind") or {}
gust = o.get("gust") or {}

meta = obs_body.get("metadata") or {}
obs_when = format_observation_time(meta.get("observation_time") if isinstance(meta, dict) else None)

tooltip_lines = ["{} — BOM".format(LABEL)]
if obs_when:
    tooltip_lines.append("Observed: {}".format(obs_when))
tooltip_lines.extend(
    [
    "Station: {}".format(st_line),
    "Now: {:.1f}°C (feels {:.1f}°C)".format(float(o["temp"]), float(o.get("temp_feels_like", o["temp"]))),
    "Humidity: {}%".format(o.get("humidity", "?")),
    "Wind: {} km/h {}".format(wind.get("speed_kilometre", "?"), wind.get("direction", "")),
    "Gust: {} km/h".format(gust.get("speed_kilometre", "?")),
    "Rain since 9am: {} mm".format(o.get("rain_since_9am", "?")),
    "Today: {}".format(short_text),
    ]
)
if uv_line:
    tooltip_lines.append(uv_line)

t = float(o["temp"])
f = float(o.get("temp_feels_like", t))
temp_s = "{:.0f}".format(t)
feel_s = "{:.0f}".format(f)
icon = icon_from_descriptor(icon_key)
if temp_s == feel_s:
    bar_text = "{} {}°C".format(icon, temp_s)
else:
    bar_text = "{} {}°C ({}°C)".format(icon, temp_s, feel_s)

print(
    json.dumps(
        {
            "text": bar_text,
            "tooltip": "\n".join(tooltip_lines),
            "class": css_class_from_descriptor(icon_key),
            "alt": "Weather: {} degrees, feels like {}. {}".format(temp_s, feel_s, short_text),
        },
        ensure_ascii=False,
    )
)
PY
