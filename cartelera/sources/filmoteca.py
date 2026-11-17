"""Filmoteca Española — Cine Doré.

Fuente: su tienda de entradas (sacatuentrada), que pinta en HTML los pases a la venta
(unos 3 días vista) con fecha, hora, sala y ciclo. El programa del mes completo solo
está en PDF; queda para más adelante."""
from __future__ import annotations

import re
from datetime import date

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import at, clean, tidy_title

URL = "https://entradasfilmoteca.sacatuentrada.es/es"
CINEMA = "Cine Doré (Filmoteca)"


def fetch() -> list[Session]:
    soup = BeautifulSoup(get_text(URL), "lxml")
    out: list[Session] = []
    for card in soup.select("div[data-fecha]"):
        title_el = card.select_one("h2.titulo")
        desc = clean(card.select_one(".descripcion").get_text(" ")) if card.select_one(".descripcion") else ""
        m = re.search(r"a las (\d{1,2}[:.]\d{2})\s*h\s*\((Sala\s*\d+)?\.?\s*([^)]*)\)", desc, re.I)
        if not title_el or not m:
            continue
        raw = clean(title_el.get_text())
        ym = re.search(r"\((\d{4})\)\s*$", raw)
        title = clean(raw[: ym.start()]) if ym else raw
        d = date.fromisoformat(card["data-fecha"])
        cat = card.select_one(".categoria p")
        cycle = clean(cat.get_text()) if cat else clean(m.group(3)) or None
        link = card.select_one(".enlaces a:not(.mas-info)") or card.select_one(".imagen a")
        info = card.select_one("a.mas-info")
        director = card.select_one("h3.subtitulo")
        img = card.select_one(".imagen img")
        poster = (img.get("data-src") or img.get("src")) if img else None
        if poster and "no_image" in poster:
            poster = None
        out.append(Session(
            source="filmoteca",
            cinema=CINEMA,
            title=title,
            raw_title=raw,
            start=at(d, m.group(1)),
            room=clean(m.group(2)) or None,
            year=int(ym.group(1)) if ym else None,
            director=clean(director.get_text()) if director else None,
            cycle=tidy_title(cycle.upper()) if cycle else None,
            price_eur=3.0,
            price_note="Tarifa general del Doré (hay reducida y bonos)",
            ticket_url=clean(link["href"]) if link else None,
            info_url=clean(info["href"]) if info else None,
            poster=poster,
            note="Si sale agotado en web, quedan entradas del día en taquilla (17–20 h)",
        ))
    return out
