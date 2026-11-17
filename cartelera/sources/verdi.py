"""Verdi Madrid.

Fuente: el JSON que usa su propia web (madrid.cines-verdi.com/api/get-events), con cada
pase, su precio en céntimos, la versión, el formato de proyección y el id de IMDb.
No publica la sala."""
from __future__ import annotations

from datetime import datetime

from ..http import get_json
from ..model import Session
from ..text import clean, detect_version, strip_version

BASE = "https://madrid.cines-verdi.com"
CINEMA = "Verdi Madrid"


def fetch() -> list[Session]:
    data = get_json(f"{BASE}/api/get-events")
    now = datetime.now()
    out: list[Session] = []
    for e in data.get("result", []):
        raw = clean(e.get("locale_title") or e.get("title_name"))
        directors = ", ".join(d[1] for d in (e.get("directors") or []) if len(d) > 1) or None
        try:
            year = int(e.get("year")) if e.get("year") else None
        except ValueError:
            year = None
        projection = clean(e.get("projection"))
        tags = [projection] if projection and projection.lower() not in ("digital 2d", "digital") else []
        keywords = clean(e.get("keywords")) or None
        for p in e.get("performances") or []:
            start = datetime.strptime(p["time"], "%Y%m%d%H%M")
            if start < now:
                continue
            prices = [int(x) / 100 for x in ((p.get("data") or {}).get("tickets") or {}).get("prices", []) if str(x).isdigit()]
            out.append(Session(
                source="verdi",
                cinema=CINEMA,
                title=strip_version(raw),
                raw_title=raw,
                start=start,
                version=detect_version(e.get("version"), raw),
                director=directors,
                year=year,
                duration_min=int(e["runtime"]) if str(e.get("runtime") or "").isdigit() else None,
                cycle=keywords,
                tags=tags,
                note=clean(e.get("notice")) or None,
                # El pase trae varias tarifas (general y reducidas): mostramos la general,
                # que es la más alta, y avisamos de la reducida.
                price_eur=max(prices) if prices else None,
                price_note=("Precio del pase" + (f" · reducida desde {min(prices):.2f} €".replace(".", ",") if len(set(prices)) > 1 else "")) if prices else None,
                ticket_url=f"{BASE}/{e.get('title_slug')}" if e.get("title_slug") else BASE,
                info_url=f"{BASE}/{e.get('title_slug')}" if e.get("title_slug") else None,
                imdb_id=e.get("imdbid") or None,
            ))
    return out
