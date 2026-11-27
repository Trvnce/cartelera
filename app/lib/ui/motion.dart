import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive.dart';

/// Movimiento de la interfaz en Android (Material 3). En iOS no se usa nada de esto: allí
/// mandan las transiciones y los controles nativos.
abstract final class Motion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 280);
  static const long = Duration(milliseconds: 400);

  /// «Emphasized decelerate» de Material 3: entra rápido y se posa suave.
  static const enter = Cubic(0.05, 0.7, 0.1, 1.0);

  /// «Emphasized accelerate»: para lo que sale.
  static const exit = Cubic(0.3, 0.0, 0.8, 0.15);

  static const standard = Cubic(0.2, 0.0, 0, 1.0);
}

/// Android (o la vista Material en los tests): aquí sí hay animaciones propias.
bool useMaterialMotion(BuildContext context) => !isCupertino(context);

/// El usuario ha pedido reducir animaciones en el sistema.
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Póster que vuela de la cuadrícula a la ficha. Solo en Android; [tag] null = sin vuelo.
class PosterHero extends StatelessWidget {
  const PosterHero({super.key, required this.tag, required this.radius, required this.child});

  final String? tag;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clipped = ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
    if (tag == null || !useMaterialMotion(context)) return clipped;
    return Hero(
      tag: tag!,
      // Durante el vuelo el redondeo pasa de uno a otro en lugar de saltar al final.
      flightShuttleBuilder: (ctx, anim, dir, from, to) {
        final fromR = _radiusOf(from.widget) ?? radius;
        final toR = _radiusOf(to.widget) ?? radius;
        return AnimatedBuilder(
          animation: anim,
          builder: (_, _) {
            final t = Curves.easeInOut.transform(anim.value);
            final r = dir == HeroFlightDirection.push ? fromR + (toR - fromR) * t : toR + (fromR - toR) * (1 - t);
            return ClipRRect(borderRadius: BorderRadius.circular(r), child: child);
          },
        );
      },
      child: _Radius(radius: radius, child: clipped),
    );
  }

  static double? _radiusOf(Widget w) => w is Hero && w.child is _Radius ? (w.child as _Radius).radius : null;
}

class _Radius extends StatelessWidget {
  const _Radius({required this.radius, required this.child});
  final double radius;
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// Se hunde un poco al pulsarlo (respuesta táctil de las tarjetas). En iOS, tal cual.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.onLongPress, this.borderRadius, this.scale = 0.95});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final motion = useMaterialMotion(context) && !reduceMotion(context);
    final ink = InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (motion) HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      onHighlightChanged: motion ? (v) => setState(() => _down = v) : null,
      borderRadius: widget.borderRadius,
      child: widget.child,
    );
    if (!motion) return ink;
    return AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: _down ? Motion.short : Motion.medium,
      curve: _down ? Curves.easeOut : Curves.easeOutBack,
      child: ink,
    );
  }
}

/// Como [IndexedStack] (las pestañas conservan su estado y su scroll), pero en Android el
/// cambio es un «fade through» de Material 3: la saliente se apaga y la entrante aparece
/// creciendo un poco. En iOS cambia en seco, como la barra de pestañas nativa.
class FadeThroughIndexedStack extends StatefulWidget {
  const FadeThroughIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeThroughIndexedStack> createState() => _FadeThroughIndexedStackState();
}

class _FadeThroughIndexedStackState extends State<FadeThroughIndexedStack> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.medium, value: 1);
  int? _from;

  @override
  void didUpdateWidget(FadeThroughIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      if (useMaterialMotion(context) && !reduceMotion(context)) {
        _from = old.index;
        _c.forward(from: 0).whenCompleteOrCancel(() {
          if (mounted) setState(() => _from = null);
        });
      } else {
        _from = null;
        _c.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // 0–35 %: se apaga la saliente; 35–100 %: entra la nueva.
        final outOpacity = (1 - t / 0.35).clamp(0.0, 1.0);
        final inT = Motion.enter.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _child(i, outOpacity, inT),
          ],
        );
      },
    );
  }

  Widget _child(int i, double outOpacity, double inT) {
    final active = i == widget.index;
    final leaving = i == _from && outOpacity > 0;
    final entering = active && _from != null;
    // Siempre la misma estructura de widgets: cambiarla haría perder el estado (y el
    // scroll) de la pestaña.
    return Offstage(
      offstage: !(active || leaving),
      child: TickerMode(
        enabled: active,
        child: ExcludeFocus(
          excluding: !active,
          child: IgnorePointer(
            ignoring: leaving,
            child: Opacity(
              opacity: entering ? inT : (leaving ? outOpacity : 1),
              child: Transform.scale(scale: entering ? 0.94 + 0.06 * inT : 1, child: widget.children[i]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cambia un icono por otro con un pequeño giro y escala (corazón, actualizar…).
class SwapIcon extends StatelessWidget {
  const SwapIcon({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!useMaterialMotion(context)) return child;
    return AnimatedSwitcher(
      duration: Motion.medium,
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
      child: child,
    );
  }
}
