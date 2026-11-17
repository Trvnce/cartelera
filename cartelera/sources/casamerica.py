"""Casa de América — Sala Iberia (Plaza de Cibeles).

Fuente: casamerica.es/cine (listado con la fecha en el resumen) y la ficha de cada
proyección («Fecha y hora: Miércoles 25 de noviembre de 2026. ⌚ 18:00.»), con ciclo,
director, país, año, duración y si la entrada es libre."""
from __future__ import annotations

import re
from datetime import date
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import MONTHS, at, clean, infer_year

BASE = "https://www.casamerica.es"
CINEMA = "Casa de América (Sala Iberia)"
DATE_RE = re.compile(r"(\d{1,2})\s+de\s+([a-záéíóú]+)(?:\s+de\s+(\d{4}))?", re.I)


def _first_date(text: str, today: date) -> date | None:
    for m in DATE_RE.finditer(text):
        mon = MONTHS.get(m.group(2).lower())
        if mon:
            day = int(m.group(1))
            year = int(m.group(3)) if m.group(3) else infer_year(mon, day, today)
            try:
                return date(year, mon, day)
            except ValueError:
                return None
    return None


def fetch() -> list[Session]:
    today = date.today()
    soup = BeautifulSoup(get_text(f"{BASE}/cine"), "lxml")
    out: list[Session] = []
    seen = set()
    for card in soup.select("article.card"):
        a = card.select_one(".card-title a, h3 a")
        if not a or a["href"] in seen:
            continue
        seen.add(a["href"])
        summary = clean(card.get_text(" "))
        d0 = _first_date(summary, today)
        # Del listado solo nos interesan las proyecciones que aún no han pasado
        # (los ciclos «Del 19 al 22 de octubre» se comprueban en la ficha).
        if d0 and d0 < today and "del " not in summary.lower():
            continue
        url = urljoin(BASE, a["href"])
        page = BeautifulSoup(get_text(url), "lxml")
        main = page.find("main") or page.body
        text = clean(main.get_text(" "))
        fm = re.search(r"Fecha y hora:?(.{0,160})", text)
        if not fm:
            continue
        d = _first_date(fm.group(1), today)
        tm = re.search(r"(\d{1,2}[:.]\d{2})", fm.group(1))
        if not d or not tm or d < today:
            continue
        title = clean(a.get_text())
        cm = re.search(re.escape(title) + r"\s+(.{3,90}?)\s+Proyecci", text)
        meta = re.search(r"([A-ZÁÉÍÓÚa-záéíóúñ ,]+),\s*((?:19|20)\d{2})\s*/\s*(\d+)\s*['’]", text)
        dm = re.search(r"Director(?:a|es)?:\s*([^\n:]{3,80}?)\s+(?:Guion|Int[eé]rpretes|Sinopsis|Reparto)", text)
        img = card.select_one("img")
        free = "entrada libre" in text.lower() or "entrada gratuita" in text.lower()
        out.append(Session(
            source="casamerica",
            cinema=CINEMA,
            title=title,
            start=at(d, tm.group(1)),
            room="Sala Iberia",
            year=int(meta.group(2)) if meta else None,
            duration_min=int(meta.group(3)) if meta else None,
            director=clean(dm.group(1)).rstrip(".") if dm else None,
            cycle=clean(cm.group(1)) if cm else None,
            note="Entrada libre hasta completar aforo; se reparte en taquilla una hora antes" if free else None,
            price_eur=0.0 if free else None,
            price_note="Gratis" if free else None,
            ticket_url=url,
            info_url=url,
            poster=urljoin(BASE, img["src"]) if img and img.get("src") else None,
        ))
    return out
