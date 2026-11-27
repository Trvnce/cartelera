"""Genera el icono de Cartelera en Madrid desde una única geometría.

Logo «Estrella»: una C gruesa centrada en el icono con una estrella de cinco puntas (la de la
bandera de Madrid) en su abertura. Rejilla de icono adaptativo de Android: lienzo 108 dp, zona
visible 72 dp (18..90), zona segura 66 dp.

- La C está centrada: misma distancia al borde (10,5 dp) por los cuatro lados.
- La estrella cabe dentro del círculo exterior de la C y queda a 4 dp de sus dos extremos
  (calculado numéricamente; por eso sube 1 dp: tiene una punta arriba y dos abajo).

Uso (desde la raíz del proyecto):  python branding/gen_icon.py
Escribe: branding/logo.svg, branding/play_store_512.png, los recursos de Android
(vector adaptativo + monocromo + PNG heredados) y el AppIcon de iOS.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"

BG = "#0F0E0D"      # AppColors.bg
CREAM = "#F0E9DD"   # AppColors.cream
AMBER = "#F5B841"   # AppColors.amber

# Geometría (dp, lienzo 108, y hacia abajo)
CX = CY = 54.0
R_C, W_C = 20.0, 11.0
RI, RO = R_C - W_C / 2, R_C + W_C / 2
GAP = 45.06                         # media apertura de la C, grados
STAR = (69.64, 52.98, 9.0, 3.78)    # centro x, centro y, radio exterior, radio interior


def _f(v: float) -> str:
    return f"{v:.2f}".rstrip("0").rstrip(".")


def c_points() -> tuple[tuple[float, float], ...]:
    g = math.radians(GAP)
    return (
        (CX + RO * math.cos(g), CY - RO * math.sin(g)),  # exterior, arriba
        (CX + RO * math.cos(g), CY + RO * math.sin(g)),  # exterior, abajo
        (CX + RI * math.cos(g), CY + RI * math.sin(g)),  # interior, abajo
        (CX + RI * math.cos(g), CY - RI * math.sin(g)),  # interior, arriba
    )


def c_path() -> str:
    """La C como figura rellena (sector de corona), sin trazos: vale para SVG y VectorDrawable."""
    (ox1, oy1), (ox2, oy2), (ix2, iy2), (ix1, iy1) = c_points()
    return (f"M{_f(ox1)},{_f(oy1)} A{_f(RO)},{_f(RO)} 0 1 0 {_f(ox2)},{_f(oy2)} "
            f"L{_f(ix2)},{_f(iy2)} A{_f(RI)},{_f(RI)} 0 1 1 {_f(ix1)},{_f(iy1)} Z")


def star_points() -> list[tuple[float, float]]:
    sx, sy, R, r = STAR
    out = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        rr = r if i % 2 else R
        out.append((sx + rr * math.cos(a), sy + rr * math.sin(a)))
    return out


def star_path() -> str:
    p = star_points()
    return "M" + " L".join(f"{_f(x)},{_f(y)}" for x, y in p) + " Z"


# ---------- SVG maestro ----------
def write_svg() -> None:
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="18 18 72 72" width="512" height="512">
  <rect x="18" y="18" width="72" height="72" fill="{BG}"/>
  <path d="{c_path()}" fill="{CREAM}"/>
  <path d="{star_path()}" fill="{AMBER}"/>
</svg>
"""
    (ROOT / "branding" / "logo.svg").write_text(svg, encoding="utf-8")


# ---------- Android ----------
def write_android() -> None:
    res = APP / "android/app/src/main/res"
    fg = f"""<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por branding/gen_icon.py: no editar a mano. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="{CREAM}" android:pathData="{c_path()}"/>
    <path android:fillColor="{AMBER}" android:pathData="{star_path()}"/>
</vector>
"""
    mono = fg.replace(CREAM, "#FFFFFFFF").replace(AMBER, "#FFFFFFFF")
    # Icono pequeño de la notificación de progreso: blanco, recortado al logo (28..80).
    stat = f"""<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por branding/gen_icon.py: no editar a mano. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp" android:height="24dp"
    android:viewportWidth="54" android:viewportHeight="54">
    <group android:translateX="-27" android:translateY="-27">
        <path android:fillColor="#FFFFFFFF" android:pathData="{c_path()}"/>
        <path android:fillColor="#FFFFFFFF" android:pathData="{star_path()}"/>
    </group>
</vector>
"""
    (res / "drawable").mkdir(parents=True, exist_ok=True)
    (res / "drawable/ic_launcher_foreground.xml").write_text(fg, encoding="utf-8")
    (res / "drawable/ic_launcher_monochrome.xml").write_text(mono, encoding="utf-8")
    (res / "drawable/ic_stat_cartelera.xml").write_text(stat, encoding="utf-8")
    (res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por branding/gen_icon.py: no editar a mano. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
""", encoding="utf-8")
    (res / "values/ic_launcher_colors.xml").write_text(f"""<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por branding/gen_icon.py: no editar a mano. -->
<resources>
    <color name="ic_launcher_background">{BG}</color>
</resources>
""", encoding="utf-8")
    # PNG heredados (Android < 8): cuadrado redondeado con la zona visible de 72 dp.
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        render(px, rounded=True).save(res / f"mipmap-{folder}/ic_launcher.png")


# ---------- Render PNG ----------
def render(px: int, rounded: bool = False) -> Image.Image:
    ss = 8
    size = px * ss
    k = size / 72.0                     # dp → píxel; la imagen es la zona visible 18..90

    def tx(p):
        return ((p[0] - 18) * k, (p[1] - 18) * k)

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if rounded:
        d.rounded_rectangle((0, 0, size - 1, size - 1), radius=16 * k, fill=BG)
    else:
        d.rectangle((0, 0, size, size), fill=BG)

    # C como polígono denso del sector de corona
    g = GAP
    steps = 720
    outer = [(CX + RO * math.cos(math.radians(a)), CY - RO * math.sin(math.radians(a)))
             for a in [g + (360 - 2 * g) * i / steps for i in range(steps + 1)]]
    inner = [(CX + RI * math.cos(math.radians(a)), CY - RI * math.sin(math.radians(a)))
             for a in [360 - g - (360 - 2 * g) * i / steps for i in range(steps + 1)]]
    d.polygon([tx(p) for p in outer + inner], fill=CREAM)
    d.polygon([tx(p) for p in star_points()], fill=AMBER)
    return img.resize((px, px), Image.LANCZOS)


# ---------- iOS ----------
def write_ios() -> None:
    folder = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((folder / "Contents.json").read_text(encoding="utf-8"))
    for im in contents["images"]:
        name = im.get("filename")
        if not name:
            continue
        pts = float(im["size"].split("x")[0])
        scale = int(im["scale"].rstrip("x"))
        render(round(pts * scale)).convert("RGB").save(folder / name)


if __name__ == "__main__":
    write_svg()
    write_android()
    write_ios()
    render(512).convert("RGB").save(ROOT / "branding" / "play_store_512.png")
    print("Icono generado.")
