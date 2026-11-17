"""Lee todas las fuentes, clasifica, guarda el histórico y genera los datos de la web.

    python -m cartelera.run            # todas las fuentes
    python -m cartelera.run golem cba  # solo algunas
    python -m cartelera.run --fresh    # ignora la caché de 3 h
"""
from __future__ import annotations

import importlib
import json
import sqlite3
import sys
import time
import traceback
from datetime import datetime
from pathlib import Path

from . import http, posters
from .classify import classify, is_special

ROOT = Path(__file__).resolve().parent.parent
WEB_DATA = ROOT / "web" / "data.js"
DB = ROOT / "data" / "cartelera.db"

SOURCES = {
    # id: (nombre visible, web del cine)
    "filmoteca": ("Cine Doré (Filmoteca)", "https://www.cultura.gob.es/cultura/areas/cine/mc/fe/programacion-actividades/proyecciones.html"),
    "cineteca": ("Cineteca Madrid", "https://www.cinetecamadrid.com/programacion"),
    "renoir": ("Renoir (Princesa, Retiro, Pza. España)", "https://www.cinesrenoir.com/"),
    "golem": ("Golem Madrid", "https://www.golem.es/golem/golem-madrid"),
    "embajadores": ("Embajadores (Glorieta y Río)", "https://cinesembajadores.es/madrid/"),
    "verdi": ("Verdi Madrid", "https://madrid.cines-verdi.com/"),
    "cba": ("Cine Estudio (Círculo de Bellas Artes)", "https://www.circulobellasartes.com/cine-estudio/"),
    "academia": ("Academia de Cine", "https://www.academiadecine.com/actividades/"),
    "berlanga": ("Sala Berlanga", "https://salaberlanga.com/programacion/"),
    "equis": ("Sala Equis (PDF del mes)", "https://salaequis.es/"),
    "casamerica": ("Casa de América (Sala Iberia)", "https://www.casamerica.es/cine"),
    "ecartelera": ("vía eCartelera: Paz, Yelmo Ideal, Príncipe Pío, Palacio de Hielo, Toledo", "https://www.ecartelera.com/cines/0,30,1.html"),
}


def _db() -> sqlite3.Connection:
    DB.parent.mkdir(exist_ok=True)
    con = sqlite3.connect(DB)
    con.execute(
        """CREATE TABLE IF NOT EXISTS sessions (
            key TEXT PRIMARY KEY, source TEXT, cinema TEXT, title TEXT, start TEXT,
            data TEXT, first_seen TEXT, last_seen TEXT)"""
    )
    con.execute(
        """CREATE TABLE IF NOT EXISTS runs (
            at TEXT, source TEXT, ok INTEGER, count INTEGER, seconds REAL, error TEXT)"""
    )
    return con


def main(argv: list[str]) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # la consola de Windows es cp1252
    except AttributeError:
        pass
    fresh = "--fresh" in argv
    wanted = [a for a in argv if not a.startswith("--")] or list(SOURCES)
    if fresh:
        http.CACHE_TTL = 0

    now = datetime.now().strftime("%Y-%m-%dT%H:%M")
    con = _db()
    status = []
    all_sessions = []
    for sid in wanted:
        t0 = time.time()
        try:
            mod = importlib.import_module(f"cartelera.sources.{sid}")
            got = [classify(s) for s in mod.fetch()]
            all_sessions.extend(got)
            err = None if got else "La fuente respondió pero no se leyó ningún pase (¿ha cambiado la web?)"
        except Exception as e:  # una fuente rota no tumba las demás
            got, err = [], f"{type(e).__name__}: {e}"
            traceback.print_exc()
        secs = round(time.time() - t0, 1)
        status.append({"id": sid, "name": SOURCES[sid][0], "url": SOURCES[sid][1],
                       "ok": err is None, "count": len(got), "error": err, "at": now})
        con.execute("INSERT INTO runs VALUES (?,?,?,?,?,?)", (now, sid, int(err is None), len(got), secs, err))
        print(f"{'OK ' if err is None else 'ERR'} {sid:12} {len(got):4} pases  {secs:5}s  {err or ''}")

    t0 = time.time()
    posters.fill(all_sessions, con)
    print(f"pósters: {sum(bool(s.poster) for s in all_sessions)}/{len(all_sessions)} pases con imagen ({time.time() - t0:.0f}s)")

    for s in all_sessions:
        d = s.to_dict()
        con.execute(
            """INSERT INTO sessions VALUES (?,?,?,?,?,?,?,?)
               ON CONFLICT(key) DO UPDATE SET data=excluded.data, last_seen=excluded.last_seen""",
            (d["key"], s.source, s.cinema, s.title, d["start"], json.dumps(d, ensure_ascii=False), now, now),
        )
    con.commit()

    # La web muestra lo de esta lectura y, de las fuentes que hoy han fallado, lo último que se supo.
    failed = {st["id"] for st in status if not st["ok"]}
    rows = [s.to_dict() | {"special": is_special(s)} for s in all_sessions]
    if failed:
        for (data,) in con.execute(
            f"SELECT data FROM sessions WHERE source IN ({','.join('?' * len(failed))}) AND start >= ?",
            (*failed, now),
        ):
            d = json.loads(data)
            d["stale"] = True
            d.setdefault("special", False)
            rows.append(d)
    con.close()

    rows.sort(key=lambda r: (r["start"], r["cinema"], r["title"]))
    payload = {"generated_at": now, "sources": status, "sessions": rows}
    WEB_DATA.write_text("window.CARTELERA = " + json.dumps(payload, ensure_ascii=False) + ";\n", encoding="utf-8")
    print(f"\n{len(rows)} pases → {WEB_DATA.relative_to(ROOT)}")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
