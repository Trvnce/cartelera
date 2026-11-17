"""Cine Estudio del Círculo de Bellas Artes.

Fuente: circulobellasartes.com/cine-estudio/, HTML con dos semanas de cartelera:
día, hora, título + director, tipo (Estreno / Ciclo) y una nota (coloquios,
«Precio reducido»). Una sola sala. Precio según su tarifa publicada."""
from __future__ import annotations

import re
from datetime import date

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import MONTHS, at, clean, infer_year, split_cycle

URL = "https://www.circulobellasartes.com/cine-estudio/"
CINEMA = "Cine Estudio (Círculo de Bellas Artes)"
TICKETS = "https://entradas.circulobellasartes.reservaentradas.com/"


def fetch() -> list[Session]:
    soup = BeautifulSoup(get_text(URL), "lxml")
    today = date.today()
    out: list[Session] = []
    seen: set[str] = set()
    for day in soup.select(".cba_cine_table_container"):
        dl = day.select_one(".cba_cine_table_dia")
        m = re.search(r"(\d{1,2})\s+([A-Za-z]+)", clean(dl.get_text()) if dl else "")
        if not m or m.group(2).lower()[:3] not in MONTHS:
            continue
        dd, mm = int(m.group(1)), MONTHS[m.group(2).lower()[:3]]
        d = date(infer_year(mm, dd, today), mm, dd)
        if d < today:
            continue
        cont = day.select_one(".cba_cine_sesiones_container")
        cur: dict = {}
        cells = cont.find_all("div", recursive=False) if cont else []
        rows: list[dict] = []
        for c in cells:
            cls = " ".join(c.get("class", []))
            if "table_hora" in cls:
                cur = {"hora": clean(c.get_text())}
                rows.append(cur)
            elif "table_titulo" in cls:
                a = c.select_one("a")
                cur["title"] = clean(a.get_text()) if a else clean(c.get_text())
                cur["url"] = a["href"] if a else None
                cur["director"] = clean(c.get_text().replace(a.get_text(), "", 1)) if a else None
            elif "table_tipo" in cls:
                cur["tipo"] = clean(c.get_text())
            elif "table_info" in cls:
                cur["info"] = clean(c.get_text())
        for r in rows:
            if not r.get("title") or not re.match(r"\d", r.get("hora", "")):
                continue
            tipo, info = r.get("tipo") or "", r.get("info") or ""
            price = 8.0 if tipo.lower().startswith("estreno") else 5.5
            pnote = "Estreno" if price == 8.0 else "Ciclo"
            title, named_cycle = split_cycle(r["title"])
            if "reducido" in info.lower():
                pnote += " · precio reducido en este pase (importe sin publicar)"
            s = Session(
                source="cba",
                cinema=CINEMA,
                title=title,
                raw_title=r["title"],
                start=at(d, r["hora"]),
                room="Sala única",
                director=r.get("director") or None,
                cycle=named_cycle or (None if tipo.lower().startswith("estreno") else "Ciclo"),
                tags=["estreno"] if tipo.lower().startswith("estreno") else [],
                note=info or None,
                price_eur=price,
                price_note=pnote,
                ticket_url=TICKETS,
                info_url=r.get("url"),
            )
            if s.key not in seen:
                seen.add(s.key)
                out.append(s)
    return out
