"""Cineteca Madrid (Matadero).

Fuente: el listado /programacion (Drupal, HTML) para saber qué títulos hay en los
próximos días con su ciclo y su sección, y la ficha de cada título para la sala,
las horas exactas y el enlace de compra (tienda.madrid-destino.com)."""
from __future__ import annotations

import re
from datetime import date, timedelta
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import MONTHS, at, clean, infer_year, tidy_title

BASE = "https://www.cinetecamadrid.com"
CINEMA = "Cineteca Madrid"
DAYS_AHEAD = 7
MAX_PAGES = 8


def _listing(today: date) -> dict[str, dict]:
    """url de ficha → {cycle, section, duration}. En este formulario «to» es la fecha
    de inicio y «since» la de fin (los nombres están cruzados en la web)."""
    films: dict[str, dict] = {}
    end = today + timedelta(days=DAYS_AHEAD)
    for page in range(MAX_PAGES):
        url = f"{BASE}/programacion?to={today:%Y-%m-%d}&since={end:%Y-%m-%d}&page={page}"
        soup = BeautifulSoup(get_text(url), "lxml")
        items = soup.select(".content-wrap .field-name-node-title a")
        if not items:
            break
        new = 0
        for a in items:
            wrap = a.find_parent(class_="content-wrap")
            href = urljoin(BASE, a["href"])
            if href in films:
                continue
            new += 1
            prog = wrap.select_one(".field-name-field-program a")
            sec = wrap.select_one(".field-name-field-parent-section a")
            dur = wrap.select_one(".field-name-field-duration")
            dm = re.search(r"(\d+)", dur.get_text()) if dur else None
            films[href] = {
                "title": clean(a.get_text()),
                "cycle": tidy_title(clean(prog.get_text())) if prog else None,
                "section": tidy_title(clean(sec.get_text())) if sec else None,
                "duration": int(dm.group(1)) if dm else None,
            }
        if not new:
            break
    return films


def _detail(url: str, meta: dict, today: date) -> list[Session]:
    soup = BeautifulSoup(get_text(url), "lxml")
    box = soup.select_one(".sb-sessions__items")
    if not box:
        return []
    buy = soup.select_one(".field--name-field-ticketing-links a")
    poster = soup.select_one(".field-name-field-poster a")
    director = year = None
    if poster and poster.get("title"):
        # «Un hombre en un puente (David Martín de los Santos, España, 2026)»
        pm = re.search(r"\(([^()]*)\)\s*$", poster["title"])
        if pm:
            parts = [clean(p) for p in pm.group(1).split(",")]
            if parts and re.fullmatch(r"\d{4}", parts[-1]):
                year = int(parts[-1])
            if len(parts) >= 3:
                director = parts[0]

    out: list[Session] = []
    month = None
    day = None
    for el in box.find_all(["h2", "h4", "ul"], recursive=True):
        txt = clean(el.get_text(" "))
        if el.name == "h2":
            month = MONTHS.get(txt.lower())
        elif el.name == "h4":
            dm = re.search(r"(\d{1,2})", txt)
            day = int(dm.group(1)) if dm else None
        elif el.name == "ul" and month and day:
            hours = el.select(".sb-sessions__date-hours-hour")
            rooms = el.select(".sb-sessions__date-hours-space")
            for i, h in enumerate(hours):
                d = date(infer_year(month, day, today), month, day)
                if d < today:
                    continue
                room = clean(rooms[i].get_text()) if i < len(rooms) else None
                out.append(Session(
                    source="cineteca",
                    cinema=CINEMA,
                    title=meta["title"],
                    start=at(d, clean(h.get_text())),
                    room=room,
                    year=year,
                    director=director,
                    duration_min=meta["duration"],
                    cycle=meta["cycle"],
                    section=meta["section"],
                    ticket_url=buy["href"] if buy else None,
                    info_url=url,
                    poster=urljoin(BASE, poster["href"]) if poster and poster.get("href") else None,
                ))
    return out


def fetch() -> list[Session]:
    today = date.today()
    out: list[Session] = []
    for url, meta in _listing(today).items():
        out.extend(_detail(url, meta, today))
    return out
