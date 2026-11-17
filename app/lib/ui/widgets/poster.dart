import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Póster que llena a su padre. Sin imagen (o si falla) pinta un cartel digno
/// con el título.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.url, required this.title, this.cacheWidth = 400, this.compact = false});

  final String? url;
  final String title;

  /// Ancho en píxeles al que se decodifica (ahorra memoria en las cuadrículas).
  final int cacheWidth;

  /// Miniatura: el cartel de reserva no cabe con título, solo el icono.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final u = url;
    final fallback = _Placeholder(title: title, compact: compact);
    if (u == null || u.isEmpty || !u.startsWith('http')) return fallback;
    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => const ColoredBox(color: AppColors.surfaceHigh),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, required this.compact});
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E2924), Color(0xFF171513)],
        ),
      ),
      child: compact
          ? const Center(child: Icon(Icons.movie_outlined, color: AppColors.muted, size: 20))
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_movies_outlined, color: AppColors.amber, size: 18),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cream,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
