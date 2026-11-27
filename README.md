# Cartelera Madrid

Cartelera personal de cine para Madrid, centrada en salas de autor, ciclos, reestrenos y
pases especiales. Lee la web de cada cine, junta los pases en un formato común, marca lo
especial y genera una web estática que se abre con doble clic.

## Uso

```bash
python -m pip install -r requirements.txt
python -m cartelera.run            # lee todas las fuentes y regenera web/data.js
```

Después, abre `web/index.html` en el navegador (no hace falta servidor).

- `python -m cartelera.run golem cba`: lee solo esas fuentes.
- `python -m cartelera.run --fresh`: ignora la caché (por defecto no repite una petición durante 3 h).
- El código de salida es 1 si alguna fuente falla. La web avisa en el pie y, de esa fuente,
  sigue mostrando lo último que se leyó bien.

## Fuentes (MVP)

| id | Cine | De dónde | Sala | Precio |
|---|---|---|---|---|
| `filmoteca` | Cine Doré | tienda sacatuentrada (HTML, ~3 días vista) | sí | 3 € general |
| `cineteca` | Cineteca Madrid | /programacion + ficha de cada título | sí | — |
| `renoir` | Princesa, Retiro, Plaza de España | /cine/<cine>/cartelera/?fecha= | sí | tarifa online por día |
| `golem` | Golem Madrid | /golem/golem-madrid/AAAAMMDD | no | tarifa por día y hora |
| `embajadores` | Embajadores Glorieta y Río | /madrid/ (atributos data-*) | sí | — |
| `verdi` | Verdi Madrid | JSON de su web /api/get-events | no | **precio de cada pase** |
| `cba` | Cine Estudio (Círculo de Bellas Artes) | /cine-estudio/ (2 semanas) | única | ciclo 5,50 € · estreno 8 € |
| `academia` | Academia de Cine | /actividades/ | única | — (muchos pases solo para académicos) |
| `berlanga` | Sala Berlanga | API WordPress (actividades de cine) + ficha | única | — (avisa si está agotado) |
| `equis` | Sala Equis | PDF mensual, leído por columnas + carteles de /taquilla/ | única | — |
| `casamerica` | Casa de América (Sala Iberia) | /cine + ficha | Iberia | gratis si es entrada libre |
| `ecartelera` | mk2 Cine Paz, Yelmo Ideal, Cinesa Príncipe Pío, mk2 Palacio de Hielo, Kinépolis Ciudad de la Imagen, mk2 Cinesur Luz del Tajo (Toledo) | eCartelera, una página por cine y día | no | tarifa publicada en eCartelera |

Las tarifas calculadas (Renoir, Golem, Círculo, eCartelera) no conocen festivos ni descuentos personales.
eCartelera no tiene sesiones (medido el 17-11-2026) de Pequeño Cine Estudio, Callao, Capitol,
Palacio de la Prensa, Zoco Majadahonda, Artistic, Arapiles ni Casa de México: esas salas
necesitan lector propio.

**Pósters**: cada lector guarda el cartel que da su web; si no lo da, se reutiliza el de otro cine
con el mismo título o se lee una vez la `og:image` de la ficha (`cartelera/posters.py`, guardado en
la tabla `posters` de SQLite).

## Cómo está hecho

- `cartelera/sources/*.py`: un lector por cine; todos devuelven `Session` (`cartelera/model.py`).
- `cartelera/classify.py`: etiquetas de cinéfilo (coloquio, presentación, preestreno, 35/70 mm,
  restaurada, festival, clásico, reestreno si la película tiene 15 años o más, ciclo).
- `cartelera/http.py`: una petición cada 1,5 s por web, caché en `cache/`, certificados del sistema
  (`truststore`; Embajadores no envía el intermedio).
- `data/cartelera.db`: histórico en SQLite (cada pase con su primera y última vez vista, y un
  registro de cada lectura por fuente).
- `web/`: `index.html` + `app.js` + `style.css`; lee `web/data.js`.

## Siguientes pasos posibles

1. Pequeño Cine Estudio, Zoco Majadahonda, Conde Duque, La Casa Encendida, Reina Sofía, Cineclub de Toledo.
2. Programa mensual completo de la Filmoteca (PDF) para ver más allá de 3 días.
3. Cruce con TMDB (pósters, año y director cuando el cine no los da) y con la watchlist de Letterboxd.
4. Contraste con la agenda abierta del Ayuntamiento (datos.madrid.es, dataset 206974) y con eCartelera.
5. Ejecución diaria programada (Programador de tareas de Windows o el NAS).

## Icono

Logo «Estrella» (C + estrella de la bandera de Madrid). Todo sale de `branding/gen_icon.py`: `branding/logo.svg`, `branding/play_store_512.png` (icono de la ficha de Play), el icono adaptativo de Android (vector + capa monocroma para iconos temáticos + PNG heredados) y el AppIcon de iOS. Para cambiarlo, edita la geometría del script y ejecuta `python branding/gen_icon.py`; no toques a mano los recursos generados.
