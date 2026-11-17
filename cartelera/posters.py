"""Completa el póster de los pases que no lo traen.

1. Si otro cine da cartel para el mismo título, se reutiliza (los verticales primero).
2. Si no, se lee una vez la ficha de la película en la web del cine (og:image) y se
   guarda en la tabla `posters` de SQLite para no volver a pedirla."""
from __future__ import annotations

import re
import sqlite3
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from .http import get_text
from .model import Session, norm

# Fuentes cuyo cartel del listado es vertical (mejor para la cuadrícula).
VERTICAL = {"embajadores": 0, "golem": 1, "renoir": 2, "cineteca": 3, "filmoteca": 4}
MAX_FETCH = 120  # tope de fichas nuevas por ejecución


def _og_image(url: str) -> str | None:
    soup = BeautifulSoup(get_text(url), "lxml")
    for sel in ('meta[property="og:image"]', 'meta[name="twitter:image"]'):
        m = soup.select_one(sel)
        if m and m.get("content"):
            return urljoin(url, m["content"])
    img = soup.select_one("main img[src], article img[src]")
    return urljoin(url, img["src"]) if img else None


def fill(sessions: list[Session], con: sqlite3.Connection) -> None:
    con.execute("CREATE TABLE IF NOT EXISTS posters (url TEXT PRIMARY KEY, image TEXT)")

    by_title: dict[str, tuple[int, str]] = {}
    for s in sessions:
        if s.poster:
            rank = VERTICAL.get(s.source, 9)
            k = norm(s.title)
            if k not in by_title or rank < by_title[k][0]:
                by_title[k] = (rank, s.poster)

    cached = dict(con.execute("SELECT url, image FROM posters"))
    fetched = 0
    for s in sessions:
        if s.poster:
            continue
        if norm(s.title) in by_title:
            s.poster = by_title[norm(s.title)][1]
            continue
        url = s.info_url
        if not url or url.rstrip("/").count("/") < 3:
            continue
        if url not in cached:
            if fetched >= MAX_FETCH:
                continue
            fetched += 1
            try:
                cached[url] = _og_image(url)
            except Exception:
                cached[url] = None
            con.execute("INSERT OR REPLACE INTO posters VALUES (?, ?)", (url, cached[url]))
        img = cached[url]
        if img and not re.search(r"logo|\.svg($|\?)", img, re.I):
            s.poster = img
            by_title[norm(s.title)] = (9, img)
    con.commit()
