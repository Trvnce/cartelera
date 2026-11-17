"""Cines Embajadores (Glorieta de Santa María de la Cabeza) y Embajadores Río (Ercilla).

Fuente: cinesembajadores.es/madrid/, HTML con cada pase en atributos data-* (día, hora,
sala, recinto). Venta en reservaentradas.com. Las tarifas no están en texto."""
from __future__ import annotations

import re
from datetime import date

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session, norm
from ..text import at, clean, detect_version, infer_year, split_cycle, strip_version

URL = "https://cinesembajadores.es/madrid/"


def _room(raw: str | None) -> str | None:
    """«Emb3» / «RIO 5» → «Sala 3» / «Sala 5»."""
    m = re.search(r"(\d+)", raw or "")
    return f"Sala {m.group(1)}" if m else (clean(raw) or None)


def fetch() -> list[Session]:
    soup = BeautifulSoup(get_text(URL), "lxml")
    today = date.today()
    out: list[Session] = []
    seen: set[str] = set()
    for movie in soup.select("li.movie"):
        a = movie.select_one(".info h2 a")
        if not a:
            continue
        raw = clean(a.get_text())
        title, cycle = split_cycle(strip_version(raw))
        version = detect_version(raw, clean(movie.select_one("li.doblaje").get_text()) if movie.select_one("li.doblaje") else "")
        director = None
        for h5 in movie.select(".more h5"):
            t = clean(h5.get_text(" "))
            if t.lower().startswith("direcci"):
                director = clean(t.split(":", 1)[-1])
        img = movie.select_one(".poster img")
        poster = img.get("src") if img else None
        dur = movie.select_one("li.minutos")
        dm = re.search(r"(\d+)", dur.get_text()) if dur else None
        for p in movie.select("p[data-dia][data-hora]"):
            dd, mm = [int(x) for x in p["data-dia"].split("/")]
            d = date(infer_year(mm, dd, today), mm, dd)
            if d < today:
                continue
            recinto = clean(p.get("data-recinto")) or "Cines Embajadores"
            link = p.select_one("a")
            s = Session(
                source="embajadores",
                cinema="Embajadores Río" if "rio" in norm(recinto).split() else "Cines Embajadores",
                title=title,
                cycle=cycle,
                raw_title=raw,
                start=at(d, p["data-hora"]),
                room=_room(p.get("data-sala")),
                version=version,
                director=director,
                duration_min=int(dm.group(1)) if dm else None,
                ticket_url=link["href"] if link else None,
                info_url=a["href"],
                poster=poster,
            )
            if s.key not in seen:  # la cartelera repite películas en varias secciones
                seen.add(s.key)
                out.append(s)
    return out
