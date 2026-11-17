# Cartelera en iPhone: cómo se instala

La app es la misma que la de Android, con los componentes de iOS: barra de pestañas y barra
superior de iOS, flecha «‹» y gesto de deslizar para volver, hojas de acción, interruptores
de iOS, iconos SF y búsqueda nativa. Lee la cartelera desde el propio iPhone, sin servidor.

## Lo que hay que saber antes

- **Apple solo deja compilar apps de iPhone en un Mac con Xcode.** Desde Windows no se
  puede. Hace falta un Mac (propio o prestado) o un servicio en la nube con Mac (Codemagic,
  GitHub Actions).
- **Apple no deja instalar una app «suelta» como en Android.** Toda app tiene que ir
  firmada con una cuenta de Apple, y según la cuenta cambia cuánto dura instalada.

## Tres formas de instalarla

### A) TestFlight — la más cómoda para quien la recibe (cuenta de pago)
- Requisito: Apple Developer Program, **99 €/año**, a nombre de quien la publica.
- Se sube la app a App Store Connect y se invita a la persona por correo o con un enlace.
- **Quien la recibe:** instala la app **TestFlight** desde la App Store, abre la invitación
  y pulsa «Instalar». Nada más: no necesita ordenador ni cambiar ajustes.
- Cada versión dura **90 días**; luego hay que subir otra (mismo enlace).
- La primera vez que se invita a alguien de fuera del equipo, Apple hace una revisión
  rápida de la beta (normalmente menos de un día).

### B) AltStore / SideStore — gratis, con el Apple ID de quien la usa
- Requisito: un archivo `.ipa` de la app (lo genero yo desde un Mac o un servicio en la
  nube) y que la persona instale **AltStore** (necesita un ordenador con AltServer la
  primera vez) o **SideStore** (sin ordenador después de configurarlo).
- **Quien la recibe:** activa *Ajustes › Privacidad y seguridad › Modo de desarrollador*,
  abre el `.ipa` con AltStore/SideStore y entra con su Apple ID (gratis).
- La app **caduca a los 7 días**: hay que «refrescarla» en AltStore/SideStore cada semana
  (lo hace solo si el ordenador con AltServer está en la misma wifi, o SideStore desde el
  propio iPhone). Máximo 3 apps instaladas así.

### C) Con un Mac y un cable — gratis, para probar
- Requisito: un Mac con Xcode y el iPhone conectado por cable.
- Se abre el proyecto (`app/ios/Runner.xcworkspace`), se elige un Apple ID gratis como
  equipo de firma y se pulsa «Ejecutar».
- **Quien la recibe:** activa el *Modo de desarrollador* y, la primera vez, confía en el
  desarrollador en *Ajustes › General › VPN y gestión de dispositivos*.
- También **caduca a los 7 días** (hay que volver a instalarla desde el Mac).

## Resumen para decidir

| | Coste | Necesita | Dura | Lo que hace la otra persona |
|---|---|---|---|---|
| A) TestFlight | 99 €/año | Cuenta de desarrollador | 90 días por versión | Instalar TestFlight y pulsar el enlace |
| B) AltStore / SideStore | Gratis | `.ipa` + AltStore | 7 días, se refresca | Activar Modo de desarrollador, instalar AltStore, refrescar cada semana |
| C) Mac + cable | Gratis | Un Mac a mano | 7 días | Activar Modo de desarrollador |

En la Unión Europea existen también tiendas alternativas (por ejemplo AltStore PAL), pero
igualmente exigen una cuenta de desarrollador de pago y la notarización de Apple: no ahorran
nada frente a TestFlight.
