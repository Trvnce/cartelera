"""Etiqueta cada pase con lo que le importa a un cinéfilo: si es especial y por qué."""
from __future__ import annotations

import re
from datetime import date

from .model import Session, norm

# (etiqueta, patrón sobre título original + nota + ciclo + sección)
RULES = [
    ("coloquio", r"coloquio|encuentro con|q ?& ?a|debate"),
    ("presentación", r"presentaci[oó]n|presentad[ao] por|con la presencia"),
    ("preestreno", r"pre-?estreno|avant-?premi"),
    ("música en directo", r"m[uú]sica en directo|en vivo|live score|cine-?concierto"),
    ("35 mm", r"\b35 ?mm\b"),
    ("70 mm", r"\b70 ?mm\b"),
    ("restaurada", r"restaurad|remaster|\b4k\b|nueva copia"),
    ("festival", r"festival|queercinemad|rizoma|m[aá]rgenes|documenta|animario|alcine|semana de cine|muestra|cine por mujeres|another way"),
    ("pase especial", r"pase especial|pases especiales|sesi[oó]n especial|evento|proyecci[oó]n especial"),
    ("clásico", r"siempre cl[aá]sicos|cl[aá]sicos|domingo de cl[aá]sicos|retrospectiva|imprescindibles"),
]

CLASSIC_AGE = 15  # años: una película de 2011 proyectada en 2026 cuenta como reestreno


def classify(s: Session, today: date | None = None) -> Session:
    today = today or date.today()
    hay = " ".join(x for x in [s.raw_title, s.title, s.note, s.cycle, s.section] if x).lower()
    tags = list(dict.fromkeys(s.tags))
    for tag, pat in RULES:
        if re.search(pat, hay) and tag not in tags:
            tags.append(tag)
    if s.year and today.year - s.year >= CLASSIC_AGE and "reestreno" not in tags:
        tags.append("reestreno")
    if s.cycle and "ciclo" not in tags and norm(s.cycle) != "ciclo":
        tags.append("ciclo")
    elif s.cycle and norm(s.cycle) == "ciclo":
        tags.append("ciclo")
    s.tags = list(dict.fromkeys(tags))
    return s


SPECIAL = {"coloquio", "presentación", "preestreno", "música en directo", "35 mm", "70 mm",
           "restaurada", "festival", "pase especial", "clásico", "reestreno", "ciclo"}


def is_special(s: Session) -> bool:
    return any(t in SPECIAL for t in s.tags)
