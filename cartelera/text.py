"""Utilidades de texto y fechas compartidas por los lectores."""
from __future__ import annotations

import re
from datetime import date, datetime

MONTHS = {
    "ene": 1, "enero": 1, "feb": 2, "febrero": 2, "mar": 3, "marzo": 3, "abr": 4, "abril": 4,
    "may": 5, "mayo": 5, "jun": 6, "junio": 6, "jul": 7, "julio": 7, "ago": 8, "agosto": 8,
    "sep": 9, "sept": 9, "septiembre": 9, "oct": 10, "octubre": 10, "nov": 11, "noviembre": 11,
    "dic": 12, "diciembre": 12,
}


def clean(s: str | None) -> str:
    return re.sub(r"\s+", " ", s or "").strip()


def infer_year(month: int, day: int, today: date | None = None) -> int:
    """Las carteleras no dan el año: es el de hoy salvo que la fecha quede muy atrás
    (en noviembre, un pase «2 ene» es del año que viene)."""
    today = today or date.today()
    y = today.year
    if (date(y, month, day) - today).days < -60:
        y += 1
    return y


def at(d: date, hhmm: str) -> datetime:
    h, m = re.match(r"(\d{1,2})[:.](\d{2})", hhmm).groups()
    return datetime(d.year, d.month, d.day, int(h), int(m))


VERSION_PATTERNS = [
    ("VOSE", r"v\.?\s?o\.?\s?s\.?\s?e|vose|subtitulad|sub\.?\s*castellano|v\.o\.\s*sub"),
    ("DOBLADA", r"doblad|\bv\.?\s?e\.?\b|\(cast\)"),
    ("ES", r"versi[oó]n original castellano|original en castellano"),
    ("VO", r"\bv\.?\s?o\.?\b(?!\s*s)|versi[oó]n original"),
]


def detect_version(*texts: str | None) -> str | None:
    t = " ".join(x for x in texts if x).lower()
    for code, pat in VERSION_PATTERNS:
        if re.search(pat, t):
            return code
    return None


def tidy_title(t: str) -> str:
    """«EL PRECIO DE LA RED» → «El precio de la red» (mayúscula de frase, como se titula
    en castellano). Solo toca títulos escritos enteros en mayúsculas."""
    letters = [c for c in t if c.isalpha()]
    if not letters or not all(c.isupper() for c in letters):
        return t
    s = t.lower()
    return re.sub(r"(^|[.:¿¡!?]\s+|\(\s*)([a-zà-ÿ])", lambda m: m.group(1) + m.group(2).upper(), s)


CYCLE_PREFIX = re.compile(
    r"cl[aá]sicos|ciclo|festival|cinemad|muestra|semana|domingo|jueves|noche|retrospectiva|"
    r"homenaje|especial|foro|filmoteca|documenta|rizoma|m[aá]rgenes", re.I,
)


def split_cycle(title: str) -> tuple[str, str | None]:
    """«Domingo de clásicos: Alien» → («Alien», «Domingo de clásicos»). Solo separa si lo
    de antes de los dos puntos suena a ciclo, para no romper «Dune: parte dos»."""
    if ":" not in title:
        return title, None
    pre, post = [clean(x) for x in title.split(":", 1)]
    if post and len(pre) <= 45 and CYCLE_PREFIX.search(pre):
        return post, pre
    return title, None


def strip_version(title: str) -> str:
    """Quita «(VOSE)», «(V.O.S.E.)», «(DOBLADA AL ESPAÑOL)», «(OCAP)»… del título."""
    t = re.sub(
        r"\s*[\(\[](v\.?\s?o\.?\s?s?\.?\s?e?\.?|vose|vos|vo|doblada[^)\]]*|ocap|cast|v\.e\.)[\)\]]\s*",
        " ", title, flags=re.I,
    )
    return clean(t)
