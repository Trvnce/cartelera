import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

/// Fondo de la cabecera de la ficha (Android): un degradado con los colores del propio
/// póster y grano de película por encima, que se funde con el fondo de la app.
///
/// La paleta se saca de una miniatura de 32 px del póster (ya en la caché de imágenes) y
/// se guarda en memoria por URL; mientras llega, se ve el degradado neutro de la app.
class PosterBackdrop extends StatefulWidget {
  const PosterBackdrop({super.key, required this.url});
  final String? url;

  @override
  State<PosterBackdrop> createState() => _PosterBackdropState();
}

class _PosterBackdropState extends State<PosterBackdrop> {
  static const _neutral = PosterPalette(Color(0xFF2E2924), Color(0xFF1C1916), Color(0xFF3A3028));
  PosterPalette? _palette;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PosterBackdrop old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _load();
  }

  Future<void> _load() async {
    final u = widget.url;
    if (u == null || !u.startsWith('http')) return;
    final cached = PosterPalette._cache[u];
    if (cached != null) {
      _palette = cached;
      return;
    }
    final p = await PosterPalette.of(u);
    if (mounted && p != null) setState(() => _palette = p);
  }

  @override
  Widget build(BuildContext context) {
    final target = _palette ?? _neutral;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<PosterPalette>(
        tween: _PaletteTween(begin: _neutral, end: target),
        duration: Motion.long,
        curve: Curves.easeOut,
        builder: (context, p, _) => CustomPaint(painter: _BackdropPainter(p, _Grain.image)),
      ),
    );
  }
}

/// Tres colores del póster, ya oscurecidos para que el texto crema se lea encima.
@immutable
class PosterPalette {
  const PosterPalette(this.primary, this.secondary, this.accent);
  final Color primary, secondary, accent;

  static final _cache = <String, PosterPalette>{};

  static PosterPalette lerp(PosterPalette a, PosterPalette b, double t) => PosterPalette(
        Color.lerp(a.primary, b.primary, t)!,
        Color.lerp(a.secondary, b.secondary, t)!,
        Color.lerp(a.accent, b.accent, t)!,
      );

  static Future<PosterPalette?> of(String url) async {
    final hit = _cache[url];
    if (hit != null) return hit;
    try {
      final img = await _resolve(ResizeImage(CachedNetworkImageProvider(url), width: 32, policy: ResizeImagePolicy.fit));
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      if (data == null) return null;
      final p = fromPixels(data.buffer.asUint8List());
      if (p != null) _cache[url] = p;
      return p;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _resolve(ImageProvider provider) {
    final c = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      stream.removeListener(l);
      c.complete(info.image.clone());
      info.dispose();
    }, onError: (e, st) {
      stream.removeListener(l);
      c.completeError(e, st);
    });
    stream.addListener(l);
    return c.future.timeout(const Duration(seconds: 8));
  }

  /// Agrupa los píxeles por tono (12 sectores, más uno para los grises) pesando más los
  /// saturados; el sector con más peso da el color principal, el siguiente con un tono
  /// distinto el secundario y el más saturado de los restantes el acento.
  static PosterPalette? fromPixels(Uint8List rgba) {
    const bins = 13;
    final weight = List<double>.filled(bins, 0);
    final r = List<double>.filled(bins, 0), g = List<double>.filled(bins, 0), b = List<double>.filled(bins, 0);
    final sat = List<double>.filled(bins, 0);
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue;
      final c = Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
      final hsv = HSVColor.fromColor(c);
      if (hsv.value < 0.08) continue; // negros puros: no aportan color
      final grey = hsv.saturation < 0.18;
      final bin = grey ? 12 : (hsv.hue / 30).floor() % 12;
      final w = grey ? 0.35 : 0.4 + hsv.saturation * hsv.value;
      weight[bin] += w;
      r[bin] += rgba[i] * w;
      g[bin] += rgba[i + 1] * w;
      b[bin] += rgba[i + 2] * w;
      sat[bin] += hsv.saturation * w;
    }
    Color avg(int k) => Color.fromARGB(255, (r[k] / weight[k]).round(), (g[k] / weight[k]).round(), (b[k] / weight[k]).round());
    final order = [for (var k = 0; k < bins; k++) if (weight[k] > 0) k]..sort((x, y) => weight[y].compareTo(weight[x]));
    if (order.isEmpty) return null;
    final first = order.first;
    final second = order.firstWhere((k) => _hueDistance(k, first) >= 2, orElse: () => order.length > 1 ? order[1] : first);
    final rest = order.where((k) => k != first && k != second).toList()
      ..sort((x, y) => (sat[y] / weight[y]).compareTo(sat[x] / weight[x]));
    final third = rest.isEmpty ? second : rest.first;
    return PosterPalette(_tame(avg(first), 0.30), _tame(avg(second), 0.20), _tame(avg(third), 0.38));
  }

  static int _hueDistance(int a, int b) {
    if (a == 12 || b == 12) return a == b ? 0 : 6;
    final d = (a - b).abs();
    return math.min(d, 12 - d);
  }

  /// Oscurece y modera la saturación para que sea fondo y no protagonista.
  static Color _tame(Color c, double maxLightness) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness(math.min(hsl.lightness, maxLightness).clamp(0.08, 1.0))
        .withSaturation(math.min(hsl.saturation, 0.55))
        .toColor();
  }

  @override
  bool operator ==(Object other) =>
      other is PosterPalette && other.primary == primary && other.secondary == secondary && other.accent == accent;

  @override
  int get hashCode => Object.hash(primary, secondary, accent);
}

class _PaletteTween extends Tween<PosterPalette> {
  _PaletteTween({required super.begin, required super.end});
  @override
  PosterPalette lerp(double t) => PosterPalette.lerp(begin!, end!, t);
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.p, this.grain);
  final PosterPalette p;
  final ui.Image? grain;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Base: diagonal del color principal al secundario.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.primary, p.secondary],
        ).createShader(rect),
    );
    // Dos manchas de luz suaves: el acento arriba a la derecha y el principal a la izquierda.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.85, -0.7),
          radius: 0.9,
          colors: [p.accent.withValues(alpha: 0.85), p.accent.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.9, 0.1),
          radius: 0.8,
          colors: [p.primary.withValues(alpha: 0.7), p.primary.withValues(alpha: 0)],
        ).createShader(rect),
    );
    // Grano de película.
    final g = grain;
    if (g != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ImageShader(g, TileMode.repeated, TileMode.repeated, Matrix4.diagonal3Values(0.6, 0.6, 1).storage)
          ..filterQuality = FilterQuality.none,
      );
    }
    // Fundido largo al fondo de la app: sin borde visible abajo.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35, 0.7, 1],
          colors: [
            AppColors.bg.withValues(alpha: 0.15),
            AppColors.bg.withValues(alpha: 0.35),
            AppColors.bg.withValues(alpha: 0.8),
            AppColors.bg,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.p != p || old.grain != grain;
}

/// Textura de grano de 128×128 generada una vez: puntos claros y oscuros con poca opacidad.
abstract final class _Grain {
  static ui.Image? image;
  static bool _started = false;

  static void ensure() {
    if (_started) return;
    _started = true;
    const n = 128;
    final rnd = math.Random(7);
    final px = Uint8List(n * n * 4);
    for (var i = 0; i < n * n; i++) {
      final light = rnd.nextBool();
      final a = (rnd.nextDouble() * (light ? 14 : 24)).round();
      // Skia lee estos píxeles con alfa premultiplicado: el blanco es (a, a, a, a).
      final v = light ? a : 0;
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = a;
    }
    ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, (img) => image = img);
  }
}

/// Prepara la textura de grano antes de abrir la primera ficha.
void warmUpGrain() => _Grain.ensure();
