import 'package:flutter/material.dart';

import '../filters/catalog.dart';
import '../format.dart';
import '../motion.dart';
import '../theme.dart';
import 'poster.dart';

/// Tarjeta compacta del catálogo (3 por fila en móvil): póster 2:3 con marcas
/// mínimas y tres líneas de texto de alto fijo.
class FilmCard extends StatelessWidget {
  const FilmCard({
    super.key,
    required this.film,
    required this.now,
    required this.onTap,
    this.onLongPress,
    this.favorite = false,
    this.heroTag,
  });

  final Film film;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool favorite;
  final String? heroTag;

  static const _titleSize = 12.5;
  static const _smallSize = 11.0;

  /// Alto del bloque de texto bajo el póster, para una escala de texto dada.
  static double textHeight(TextScaler s) => 6 + s.scale(_titleSize) * 1.2 * 2 + s.scale(_smallSize) * 1.35 * 2;

  @override
  Widget build(BuildContext context) {
    final f = film;
    final versions = f.versions.map(versionLabel).whereType<String>().map((v) => v.replaceAll('V.O. castellano', 'V.O. cast.')).join(' · ');
    final n = f.sessions.length;
    final summary = n == 1
        ? f.next.cinema
        : '${plural(n, 'pase', 'pases')} · ${f.cinemas.length == 1 ? f.cinemas.first : plural(f.cinemas.length, 'cine', 'cines')}';
    const small = TextStyle(fontSize: _smallSize, height: 1.35, color: AppColors.muted);

    return Semantics(
      button: true,
      label: '${f.title}${favorite ? ', favorita' : ''}. ${fmtWhen(f.next.start, now)}. $summary',
      onLongPressHint: favorite ? 'Quitar de favoritas' : 'Guardar en favoritas',
      child: PressScale(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PosterHero(tag: heroTag, radius: 8, child: Poster(url: f.poster, title: f.title)),
                    if (f.hasSpecial)
                      Positioned(
                        left: 5,
                        top: 5,
                        child: _Dot(
                          color: AppColors.amber,
                          icon: Icons.star_rounded,
                          iconColor: AppColors.onAmber,
                          tooltip: f.specialTags.map(capitalize).join(', '),
                        ),
                      ),
                    Positioned(
                      right: 5,
                      top: 5,
                      // Aparece con un pequeño rebote al guardarla (Android).
                      child: SwapIcon(
                        child: favorite
                            ? const _Dot(key: ValueKey('fav'), color: Color(0xCC000000), icon: Icons.favorite, iconColor: AppColors.amber)
                            : const SizedBox(key: ValueKey('nofav'), width: 22, height: 22),
                      ),
                    ),
                    if (versions.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xCC000000)],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                            child: Text(
                              versions,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.cream),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRect(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: _titleSize, height: 1.2, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        fmtWhen(f.next.start, now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small.copyWith(
                          color: f.next.isSpecial ? AppColors.amber : AppColors.cream,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marca redonda sobre el póster (especial / favorita).
class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color, required this.icon, required this.iconColor, this.tooltip});
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Icon(icon, size: 14, color: iconColor),
    );
    return tooltip == null ? dot : Tooltip(message: tooltip!, child: dot);
  }
}
