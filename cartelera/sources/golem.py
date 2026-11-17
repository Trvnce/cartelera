"""Golem Madrid.

Fuente: golem.es/golem/golem-madrid (hoy) y /golem-madrid/AAAAMMDD (resto de días),
HTML de tablas con títulos y horas. No publica la sala. Precio según su tarifa,
que está en la propia página."""
from __future__ import annotations

import re
from datetime import date, datetime
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import at, clean, detect_version, split_cycle, strip_version

BASE = "https://www.golem.es"
URL = f"{BASE}/golem/golem-madrid"
CINEMA = "Golem Madrid"


def price_for(start: datetime) -> tuple[float, str]:
    wd, hour = start.weekday(), start.hour
    if wd in (0, 2):
        return 5.90, "Día del espectador"
    if wd >= 5:
        if wd == 6 and hour >= 22:
            return 6.90, "Última sesión del domingo"
        return 9.50, "Fin de semana"
    if wd in (1, 3, 4) and hour < 17:
        return 6.90, "Primera sesión laborable"
    return 8.30, "Laborable"


def _parse_day(html: str, d: date) -> list[Session]:
    soup = BeautifulSoup(html, "lxml")
    out: list[Session] = []
    for a in soup.select("a.txtNegXXL"):
        box = a.find_parent("table", attrs={"background": "#AEAEAE"})
        if not box:
            continue
        raw = clean(a.get_text())
        title, cycle = split_cycle(strip_version(raw))
        img = box.select_one("img.bordeCartel")
        fmt = [img.get("alt") for img in box.select("img[alt]") if img.get("alt") in ("digital", "35mm", "70mm")]
        for t in box.select("a.horaXXXL"):
            start = at(d, clean(t.get_text()))
            price, pnote = price_for(start)
            out.append(Session(
                source="golem",
                cinema=CINEMA,
                title=title,
                raw_title=raw,
                start=start,
                version=detect_version(raw),
                cycle=cycle,
                tags=[f for f in fmt if f != "digital"],
                price_eur=price,
                price_note=pnote,
                ticket_url=urljoin(BASE, t["href"]),
                info_url=urljoin(BASE, a["href"]),
                poster=urljoin(BASE, img["src"]) if img and img.get("src") else None,
            ))
    return out


def fetch() -> list[Session]:
    first = get_text(URL)
    out = _parse_day(first, date.today())
    for ds in sorted(set(re.findall(r"golem-madrid/(\d{8})", first))):
        d = date(int(ds[:4]), int(ds[4:6]), int(ds[6:]))
        if d != date.today():
            out.extend(_parse_day(get_text(f"{URL}/{ds}"), d))
    return out
