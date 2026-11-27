"""Cines sin lector propio, leídos desde eCartelera (su robots.txt permite /cines/).

Cada cine tiene una página por día (/cines/<id>,<n>,1.html o /cines/<slug>/<n>/) con
cada película, su cartel, director, país, y los pases con hora, formato y enlace de
compra. Los cines que ya leemos de su propia web (Golem, Renoir, Verdi, Embajadores,
Doré, Círculo) no se repiten aquí.

`vo`: el cine proyecta en versión original salvo que diga lo contrario. Si el pase no
trae formato, se deduce VOSE para películas no españolas y «ES» para las españolas."""
from __future__ import annotations

import re
from datetime import date, timedelta

from bs4 import BeautifulSoup

from ..http import get_text
from ..model import Session
from ..text import at, clean, detect_version, split_cycle, strip_version

BASE = "https://www.ecartelera.com/cines/"
DAYS_AHEAD = 10   # días de cartelera que se leen por cine

# ruta en eCartelera: (nombre que mostramos, ¿sala de versión original?)
# Medido el 17-11-2026: eCartelera NO tiene sesiones de Pequeño Cine Estudio, Sala Berlanga,
# Sala Equis, Cine Iberia (Casa de América), Casa de México, Artistic Metropol y La Morada,
# Cine Arapiles, Palacio de la Prensa, Callao, Capitol ni Zoco Majadahonda («Este cine no
# tiene sesiones ahora mismo»). Esas salas necesitan lector propio.
CINEMAS = {
    "40,0,1.html": ("mk2 Cine Paz", True),
    "54,0,1.html": ("Yelmo Cines Ideal", True),
    "53,0,1.html": ("Cinesa Príncipe Pío", False),
    "dreams-cinema-palacio-hielo/": ("mk2 Palacio de Hielo", False),
    "56,0,1.html": ("Kinépolis Ciudad de la Imagen", False),
    "471,0,1.html": ("mk2 Cinesur Luz del Tajo (Toledo)", False),
}

WEEKDAYS = {"lunes": 0, "martes": 1, "miercoles": 2, "miércoles": 2, "jueves": 3,
            "viernes": 4, "sabado": 5, "sábado": 5, "domingo": 6}


def _date_from_label(label: str, today: date) -> date | None:
    """«Cartelera del Miércoles 18» → la próxima fecha (desde hoy) con ese día del mes."""
    m = re.search(r"(\d{1,2})\s*$", label)
    if not m:
        return None
    day = int(m.group(1))
    for i in range(0, 45):
        d = today + timedelta(days=i)
        if d.day == day:
            return d
    return None


def _prices(soup: BeautifulSoup):
    """General y reducida por día de la semana, del bloque «Precios» del cine."""
    general, reduced = None, {}
    for p in soup.select("p.crow"):
        t = clean(p.get_text(" ")).lower()
        nums = [float(x.replace(",", ".")) for x in re.findall(r"(\d+[,.]\d{1,2})\s*(?:euros|€)", t)]
        if t.startswith("precios") and nums and general is None:
            general = nums[0]
        elif t.startswith("reducidos") and nums:
            for wd, i in WEEKDAYS.items():
                if wd in t:
                    reduced[i] = nums[0]
    return general, reduced


def _day_urls(soup: BeautifulSoup, first_url: str, today: date) -> list[tuple[date, str]]:
    out = []
    for a in soup.select("ul.days a[href]"):
        d = _date_from_label(a.get("title") or a.get_text(), today)
        if d and d <= today + timedelta(days=DAYS_AHEAD):
            out.append((d, a["href"]))
    return sorted(set(out)) or [(today, first_url)]


def _parse(soup: BeautifulSoup, name: str, vo: bool, d: date, prices) -> list[Session]:
    general, reduced = prices
    out: list[Session] = []
    for it in soup.select("div.titem"):
        a = it.select_one(".tit a")
        if not a:
            continue
        raw = clean(a.get_text())
        title, cycle = split_cycle(strip_version(raw))
        data = [clean(x.get_text()) for x in it.select("p.data span")]
        dur = next((int(x.split()[0]) for x in data if re.match(r"\d+ min", x)), None)
        country = next((x for x in data if not re.match(r"\d", x)), None)
        director = ", ".join(clean(x.get_text()) for x in it.select("p.dir a")) or None
        img = it.select_one(".tposter img")
        for s in it.select(".sessions [data-session-time]"):
            fmt = clean(s.get("data-session-format"))
            version = detect_version(fmt, raw)
            if not version and vo and country:
                version = "ES" if country.lower() == "españa" else "VOSE"
            start = at(d, s["data-session-time"])
            price = reduced.get(start.weekday(), general)
            out.append(Session(
                source="ecartelera",
                cinema=name,
                title=title,
                raw_title=raw,
                start=start,
                version=version,
                director=director,
                duration_min=dur,
                cycle=cycle,
                tags=[fmt] if fmt and not detect_version(fmt) and fmt.lower() not in ("2d", "digital") else [],
                price_eur=price,
                price_note=("Tarifa publicada en eCartelera" + (" (día reducido)" if start.weekday() in reduced else "")) if price else None,
                ticket_url=s.get("href"),
                info_url=a.get("href"),
                poster=img.get("src") if img and img.get("src") else None,
            ))
    return out


def fetch() -> list[Session]:
    today = date.today()
    out: list[Session] = []
    errors = []
    for path, (name, vo) in CINEMAS.items():
        url = BASE + path
        try:
            soup = BeautifulSoup(get_text(url), "lxml")
            prices = _prices(soup)
            for d, durl in _day_urls(soup, url, today):
                page = soup if durl.rstrip("/") == url.rstrip("/") else BeautifulSoup(get_text(durl), "lxml")
                out.extend(_parse(page, name, vo, d, prices))
        except Exception as e:  # un cine roto no tumba a los demás de este lector
            errors.append(f"{name}: {type(e).__name__}")
    if errors and not out:
        raise RuntimeError("; ".join(errors))
    if errors:
        print("  eCartelera, cines con error:", "; ".join(errors))
    return out
