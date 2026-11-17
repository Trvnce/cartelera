"""Cines Renoir de Madrid (Princesa, Retiro, Plaza de España).

Fuente: /cine/<cine>/cartelera/?fecha=AAAA-MM-DD, HTML con sala, versión y etiquetas
(PASE ESPECIAL, PASE CON COLOQUIO, PREESTRENO…). Venta en pillalas.com.
El precio sale de la tarifa pública (cinesrenoir.com/precios/madrid/, compra online)."""
from __future__ import annotations

import re
import string
from datetime import date, datetime
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import at, clean, detect_version, tidy_title

BASE = "https://www.cinesrenoir.com"
CINEMAS = {
    "cines-princesa": "Cines Princesa (Renoir)",
    "renoir-retiro": "Renoir Retiro",
    "renoir-plaza-de-espana": "Renoir Plaza de España",
}


def price_for(start: datetime) -> tuple[float, str]:
    """Tarifa online para no socios. No conoce festivos."""
    wd = start.weekday()  # 0 = lunes
    if wd in (0, 2):
        return 5.40, "Día del espectador (tarifa online)"
    if wd in (1, 3):
        return 8.40, "Laborable (tarifa online)"
    return 9.70, "Fin de semana (tarifa online)"


def _parse_day(html: str, slug: str, d: date) -> list[Session]:
    soup = BeautifulSoup(html, "lxml")
    out: list[Session] = []
    for block in soup.select("div.my-account-content.d-lg-block"):
        a = block.select_one(".col-4 a[href^='/pelicula/']")
        if not a:
            continue
        raw = clean(a.get_text())
        cm = re.search(r"\[([^\]]+)\]", raw)
        title = tidy_title(clean(re.sub(r"\[[^\]]*\]", "", raw)))
        smalls = [clean(s.get_text()) for s in block.select(".col-4 small")]
        director = next((s[3:] for s in smalls if s.lower().startswith("de ")), None)
        if director and "," in director:  # «Kurosawa, Akira» → «Akira Kurosawa»
            last, first = [clean(x) for x in director.split(",", 1)]
            director = f"{first} {last}"
        img = block.select_one("img")
        version_txt = next((s for s in smalls if "versi" in s.lower()), None)
        dur = next((int(m.group(1)) for s in smalls if (m := re.search(r"Duraci.n (\d+)", s))), None)
        for pase in block.select("div.pase-cartelera"):
            t = pase.select_one("a.btn-evento, a.btn-primary, a[href*='pillalas.com/pase']")
            if not t:
                continue
            sala = pase.select_one("span")
            tags = [clean(x.get_text()) for x in pase.select(".pase-cartelera-tag")]
            tags = [t for t in tags if not (cm and t.lower() == cm.group(1).lower())]  # el ciclo ya va aparte
            start = at(d, clean(t.get_text()))
            price, pnote = price_for(start)
            out.append(Session(
                source="renoir",
                cinema=CINEMAS[slug],
                title=title,
                raw_title=raw,
                start=start,
                room=clean(sala.get_text()).capitalize() if sala else None,
                version=detect_version(version_txt),
                director=director,
                duration_min=dur,
                cycle=string.capwords(cm.group(1).lower()) if cm else None,
                note=" · ".join(tags) or None,
                price_eur=price,
                price_note=pnote,
                ticket_url=t["href"],
                info_url=BASE + a["href"],
                poster=urljoin(BASE, img["src"]) if img and img.get("src") else None,
            ))
    return out


def fetch() -> list[Session]:
    out: list[Session] = []
    for slug in CINEMAS:
        first = get_text(f"{BASE}/cine/{slug}/cartelera/")
        dates = sorted(set(re.findall(r"cartelera/\?fecha=(\d{4}-\d{2}-\d{2})", first)))
        if not dates:
            dates = [date.today().isoformat()]
        for ds in dates:
            d = date.fromisoformat(ds)
            html = first if d == date.today() else get_text(f"{BASE}/cine/{slug}/cartelera/?fecha={ds}")
            out.extend(_parse_day(html, slug, d))
    return out
