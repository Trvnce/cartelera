"""Modelo común: un pase de cine, venga de la fuente que venga."""
from __future__ import annotations

import hashlib
from dataclasses import asdict, dataclass, field
from datetime import datetime


@dataclass
class Session:
    source: str                 # id del lector que lo ha leído («renoir», «cineteca»…)
    cinema: str                 # nombre del cine tal y como lo mostramos
    title: str                  # título limpio (sin «(VOSE)», sin «[CICLO]»)
    start: datetime             # hora local de Madrid, sin zona
    room: str | None = None     # «Sala 1», «sala 06», «Sala Azcona»…
    version: str | None = None  # VOSE · VO · ES (original en castellano) · DOBLADA
    director: str | None = None
    year: int | None = None
    duration_min: int | None = None
    cycle: str | None = None    # ciclo, festival o programa
    section: str | None = None  # sección del cine (Cineteca: «Pases especiales», «Siempre clásicos»…)
    tags: list[str] = field(default_factory=list)  # coloquio, presentación, preestreno, 35mm…
    note: str | None = None     # texto libre del cine («Presentación y coloquio con el equipo»)
    price_eur: float | None = None
    price_note: str | None = None  # de dónde sale el precio («tarifa del día», «precio del pase»)
    ticket_url: str | None = None
    info_url: str | None = None
    imdb_id: str | None = None
    poster: str | None = None      # URL de la imagen (cartel vertical si el cine lo da)
    raw_title: str | None = None   # el título tal cual venía, para depurar

    @property
    def key(self) -> str:
        """Identidad estable de un pase: cine + sala + hora + título normalizado."""
        base = f"{self.cinema}|{self.room or ''}|{self.start:%Y-%m-%dT%H:%M}|{norm(self.title)}"
        return hashlib.sha1(base.encode("utf-8")).hexdigest()[:16]

    def to_dict(self) -> dict:
        d = asdict(self)
        d["start"] = self.start.strftime("%Y-%m-%dT%H:%M")
        d["key"] = self.key
        return d


def norm(s: str) -> str:
    """Minúsculas sin tildes ni signos, para comparar títulos."""
    import unicodedata

    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    return " ".join("".join(c.lower() if c.isalnum() else " " for c in s).split())
