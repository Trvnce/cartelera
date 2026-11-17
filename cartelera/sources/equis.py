"""Sala Equis.

Su taquilla rellena las horas por JavaScript, pero cada mes publica un PDF con la
programación completa en un calendario de 8 columnas. Se recorta la página por columnas
y se lee cada día: hora, título (con el festival o ciclo delante), «presentación y
coloquio», director, año, versión y duración. Los carteles y el enlace de compra salen
de /taquilla/ (cada película enlaza a su ficha con el widget de venta)."""
from __future__ import annotations

import io
import re
import string
from datetime import date, datetime
from urllib.parse import quote

import pdfplumber
from bs4 import BeautifulSoup

from .. import http
from ..model import Session, norm
from ..text import at, clean, detect_version, split_cycle, tidy_title

HOME = "https://salaequis.es/"
TAQUILLA = "https://salaequis.es/taquilla/"
CINEMA = "Sala Equis"
DAY_RE = re.compile(r"^(\d{1,2})\s+(LUNES|MARTES|MI[EÉ]RCOLES|JUEVES|VIERNES|S[AÁ]BADO|DOMINGO)\b")
TIME_RE = re.compile(r"^(\d{1,2})(?::(\d{2}))?\s*h:\s*(.*)")
PREFIX_RE = re.compile(r"^F*FESTIVAL [A-ZÁÉÍÓÚÑ]+$|^CINE POR MUJERES$|^AETERNA$|^PASE ESPECIAL$|^EQUIS [A-Z]+$")
CREDITS_RE = re.compile(r"(.*?),?\s*(\d{4})\s*-+\s*(VOSE|VO/VOSE|VO|VE|V\.O\.S\.E\.)\s*-+\s*(\d+)?")


def _pdf_url() -> str | None:
    html = http.get_text(HOME)
    m = re.search(r'href="([^"]+\.pdf)"', html)
    return m.group(1) if m else None


def _taquilla() -> dict[str, tuple[str | None, str]]:
    """título normalizado → (cartel, ficha con la compra)."""
    soup = BeautifulSoup(http.get_text(TAQUILLA), "lxml")
    out = {}
    for row in soup.select("div.row"):
        a = row.select_one(".title a")
        if not a:
            continue
        img = row.select_one("img[data-src]") or row.select_one("noscript img")
        src = img.get("data-src") or img.get("src") if img else None
        out[norm(a.get_text())] = (re.sub(r"-\d+x\d+(\.\w+)$", r"\1", src) if src else None, a["href"])
    return out


def _columns(pdf_bytes: bytes) -> list[str]:
    cols = []
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        pg = pdf.pages[0]
        # Las cabeceras de día están en 8 columnas regulares: se recorta la página en 8.
        n = 8
        for i in range(n):
            cols.append(pg.crop((pg.width * i / n, 0, pg.width * (i + 1) / n, pg.height)).extract_text() or "")
    return cols


def _flush(cur: dict | None, out: list[dict]):
    if cur and cur.get("title"):
        out.append(cur)


def _parse_columns(cols: list[str], month: int, year: int) -> list[dict]:
    items: list[dict] = []
    for col in cols:
        day = None
        cur = None
        for line in [clean(x) for x in col.splitlines() if clean(x)]:
            dm = DAY_RE.match(line)
            if dm:
                _flush(cur, items)
                cur = None
                day = int(dm.group(1))
                continue
            if day is None:
                continue
            tm = TIME_RE.match(line)
            if tm:
                _flush(cur, items)
                cur = {"day": day, "time": f"{tm.group(1)}:{tm.group(2) or '00'}", "title": tm.group(3), "credits": "", "note": None, "title_done": False}
                continue
            if cur is None or "NO HAY SESIONES" in line:
                continue
            if line.startswith("*"):
                cur["note"] = line.lstrip("*").strip()
                cur["title_done"] = True
            elif CREDITS_RE.search(line) or re.match(r"^(Director:|\d{4}\s*-)", line) or re.search(r",\s*\d{4}\s*-*\s*$", line):
                cur["credits"] += " " + line
                cur["title_done"] = True
            elif re.fullmatch(r"\d+\s*[’'´]?", line):
                cur["credits"] += " " + line
            elif not cur["title_done"]:
                t = cur["title"]
                if t.endswith("-") and not PREFIX_RE.match(t[:-1].strip()):
                    t = t[:-1]                      # «SIEMPREVI-» + «VAS» → «SIEMPREVIVAS»
                    sep = ""
                else:
                    sep = "" if t.endswith("-") else " "
                cur["title"] = (t + sep + line).strip()
            else:
                cur["credits"] += " " + line
        _flush(cur, items)
    for it in items:
        it["month"], it["year"] = month, year
    return items


def fetch() -> list[Session]:
    today = date.today()
    url = _pdf_url()
    if not url:
        raise RuntimeError("No se encuentra el PDF del mes en la portada")
    raw = http._session.get(quote(url, safe=":/%"), timeout=60)
    raw.raise_for_status()
    cols = _columns(raw.content)
    head = " ".join(cols)
    mm = re.search(r"\b(\d{2})/(20\d{2})\b", head)
    month, year = (int(mm.group(1)), int(mm.group(2))) if mm else (today.month, today.year)
    taq = _taquilla()

    out: list[Session] = []
    for it in _parse_columns(cols, month, year):
        d = date(year, month, it["day"])
        if d < today:
            continue
        title = re.sub(r"^F+ESTIVAL", "FESTIVAL", it["title"]).rstrip("-")
        cycle = None
        m = re.match(r"^(FESTIVAL [^-:]+|CINE POR MUJERES|AETERNA|PASE ESPECIAL|EQUIS [A-Z]+|FESTIVAL ANFIBIA)\s*[-:]\s*(.+)$", title)
        if m:
            cycle, title = m.group(1), m.group(2)
        else:
            title, cycle = split_cycle(title)
        cm = CREDITS_RE.search(it["credits"])
        director = re.sub(r"^Director:\s*", "", clean(cm.group(1))).rstrip(" -,") if cm else None
        poster, info = taq.get(norm(title), (None, None))
        out.append(Session(
            source="equis",
            cinema=CINEMA,
            title=tidy_title(title),
            raw_title=it["title"],
            start=at(d, it["time"]),
            room="Sala única",
            version=detect_version(cm.group(3)) if cm else None,
            director=director or None,
            year=int(cm.group(2)) if cm else None,
            duration_min=int(cm.group(4)) if cm and cm.group(4) else None,
            cycle=string.capwords(cycle.lower()) if cycle else None,
            note=it["note"],
            ticket_url=info or TAQUILLA,
            info_url=info,
            poster=poster,
        ))
    return out
