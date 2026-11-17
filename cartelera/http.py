"""Descargas educadas: una petición cada pocos segundos por web, caché en disco y
decodificación robusta (algunas webs mezclan UTF-8 y Windows-1252)."""
from __future__ import annotations

import hashlib
import json
import time
from pathlib import Path
from urllib.parse import urlparse

import requests

try:
    # Usa el almacén de certificados del sistema: algunas webs (Embajadores) no envían
    # el certificado intermedio y solo validan con el de Windows/macOS.
    import truststore

    truststore.inject_into_ssl()
except ImportError:
    pass

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "cache"
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/130.0 Safari/537.36 CarteleraPersonal/0.1"
)
DELAY_PER_HOST = 1.5      # segundos entre dos peticiones a la misma web
CACHE_TTL = 3 * 3600      # una cartelera leída hace menos de 3 h no se vuelve a pedir

_session = requests.Session()
_session.headers.update({"User-Agent": UA, "Accept-Language": "es-ES,es;q=0.9"})
_last_hit: dict[str, float] = {}


def _decode(raw: bytes) -> str:
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252", errors="replace")


def get_text(url: str, *, use_cache: bool = True) -> str:
    CACHE.mkdir(exist_ok=True)
    path = CACHE / (hashlib.sha1(url.encode()).hexdigest() + ".bin")
    if use_cache and path.exists() and time.time() - path.stat().st_mtime < CACHE_TTL:
        return _decode(path.read_bytes())

    host = urlparse(url).netloc
    wait = DELAY_PER_HOST - (time.time() - _last_hit.get(host, 0))
    if wait > 0:
        time.sleep(wait)
    resp = _session.get(url, timeout=30)
    _last_hit[host] = time.time()
    resp.raise_for_status()
    path.write_bytes(resp.content)
    return _decode(resp.content)


def get_json(url: str, *, use_cache: bool = True):
    return json.loads(get_text(url, use_cache=use_cache))
