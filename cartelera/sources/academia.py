"""Academia de Cine (sala de proyecciones, calle Zurbano).

Fuente: academiadecine.com/actividades/, HTML con las actividades del mes. Muchas son
«PASE EXCLUSIVO PARA ACADÉMICOS»: se leen igual pero se marcan para ocultarlas por
defecto en la web. No hay precio en el listado."""
from __future__ import annotations

import re
from datetime import date

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import MONTHS, at, clean, infer_year

URL = "https://www.academiadecine.com/actividades/"
CINEMA = "Academia de Cine"


def fetch() -> list[Session]:
    soup = BeautifulSoup(get_text(URL), "lxml")
    today = date.today()
    out: list[Session] = []
    for act in soup.select(".listadoActividades-actividad"):
        f = act.select_one(".listadoActividades-actividad-fecha")
        name = act.select_one(".listadoActividades-actividad-nombre")
        if not f or not name:
            continue
        m = re.search(r"(\d{1,2})/([A-Za-zé]+)\D+(\d{1,2}:\d{2})", clean(f.get_text()))
        if not m or m.group(2).lower()[:3] not in MONTHS:
            continue
        dd, mm = int(m.group(1)), MONTHS[m.group(2).lower()[:3]]
        d = date(infer_year(mm, dd, today), mm, dd)
        if d < today:
            continue
        sub = act.select_one(".listadoActividades-actividad-subtitulo")
        sub_t = clean(sub.get_text()) if sub else ""
        exclusive = "exclusiv" in sub_t.lower()
        link = act.select_one("a.listadoActividades-actividad-enlace")
        img = act.select_one(".listadoActividades-actividad-imagen img")
        out.append(Session(
            source="academia",
            cinema=CINEMA,
            title=clean(name.get_text()),
            start=at(d, m.group(3)),
            room="Sala de proyecciones",
            tags=["solo académicos"] if exclusive else [],
            note=None if exclusive else (sub_t or None),
            ticket_url=link["href"] if link and not exclusive else None,
            info_url=link["href"] if link else None,
            poster=img.get("src") if img else None,
        ))
    return out
