"""Sala Berlanga (Fundación SGAE).

La venta (Entradas.com) pinta los pases por JavaScript, así que se usa la web de la
sala: su API de WordPress lista las «actividades» de cine (categoría 11) y cada ficha
trae «En cartelera · 18 de Noviembre - 18:15h», si están agotadas, el ciclo y la línea
de datos («España | 2026 | 75' | Cortometrajes + Coloquio | V.O.S.E.»)."""
from __future__ import annotations

import html as htmllib
import re
from datetime import date

from bs4 import BeautifulSoup

from ..http import get_json, get_text
from ..model import Session
from ..text import MONTHS, at, clean, detect_version, infer_year, tidy_title

API = "https://salaberlanga.com/wp-json/wp/v2/actividad?categoria-ciclo=11&per_page=40&orderby=modified&_fields=id,link,title,modified"
CINEMA = "Sala Berlanga"
TICKETS = "https://cine.entradas.com/cine/madrid/sala-berlanga/sesiones?showAllDates=true"
WHEN_RE = re.compile(r"(\d{1,2})\s+de\s+([a-záéíóú]+)\s*-\s*(\d{1,2}[:.]\d{2})", re.I)


def fetch() -> list[Session]:
    today = date.today()
    out: list[Session] = []
    for act in get_json(API):
        title = tidy_title(clean(htmllib.unescape(BeautifulSoup(act["title"]["rendered"], "lxml").get_text())))
        soup = BeautifulSoup(get_text(act["link"]), "lxml")
        bar = soup.select_one(".barra-nar-ficha")
        if not bar:
            continue
        bar_text = clean(bar.get_text(" "))
        sold_out = "agotad" in bar_text.lower()
        buy = bar.select_one("a[href*='entradas.com']")
        data = soup.select_one(".ficha-actividad-date")
        fields = [clean(x) for x in (data.get_text("|") if data else "").split("|") if clean(x)]
        year = next((int(x) for x in fields if re.fullmatch(r"(19|20)\d{2}", x)), None)
        dur = next((int(m.group(1)) for x in fields if (m := re.fullmatch(r"(\d+)\s*['’]", x))), None)
        kind = next((x for x in fields if re.search(r"[a-z]", x) and not re.fullmatch(r"V\.?O.*|VOSE|Castellano", x, re.I)
                     and x != fields[0]), None)
        cycle_el = soup.select_one(".ficha-actividad span a")
        og = soup.select_one('meta[property="og:image"]')
        for m in WHEN_RE.finditer(bar_text):
            mon = MONTHS.get(m.group(2).lower())
            if not mon:
                continue
            day = int(m.group(1))
            d = date(infer_year(mon, day, today), mon, day)
            if d < today:
                continue
            note = " · ".join(x for x in [kind, "Entradas agotadas en web" if sold_out else None] if x) or None
            out.append(Session(
                source="berlanga",
                cinema=CINEMA,
                title=title,
                start=at(d, m.group(3)),
                room="Sala única",
                version=detect_version(" ".join(fields)),
                year=year,
                duration_min=dur,
                cycle=clean(cycle_el.get_text()) if cycle_el else None,
                note=note,
                ticket_url=buy["href"] if buy else TICKETS,
                info_url=act["link"],
                poster=og.get("content") if og else None,
            ))
    return out
