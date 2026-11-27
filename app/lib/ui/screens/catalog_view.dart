import 'package:flutter/material.dart';

import '../app_model.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/film_card.dart';
import 'home_screen.dart' show EmptyResults, SortButton;

/// Abre la ficha de una película; [heroTag] es el póster que vuela hasta ella.
typedef OpenFilm = void Function(String filmKey, {String? heroTag});

/// Cuadrícula de pósters compacta (3 columnas en móvil). La usan el catálogo
/// (películas filtradas) y Favoritas.
class FilmGrid extends StatelessWidget {
  const FilmGrid({
    super.key,
    required this.model,
    required this.films,
    required this.onOpenFilm,
    required this.onRefresh,
    required this.storageKey,
    this.header,
    this.empty,
  });

  final AppModel model;
  final List<Film> films;
  final OpenFilm onOpenFilm;
  final Future<void> Function() onRefresh;
  final String storageKey;
  final Widget Function(BoxConstraints c)? header;
  final Widget? empty;

  /// Ancho mínimo de una tarjeta: 3 columnas en un móvil normal, más en pantallas anchas.
  static const minCardWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    final now = model.now;
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: films.isEmpty
          ? (empty ?? EmptyResults(model: model))
          : LayoutBuilder(
              builder: (context, c) {
                const pad = 12.0, gap = 10.0;
                final cols = ((c.maxWidth - pad * 2 + gap) / (minCardWidth + gap)).floor().clamp(3, 8);
                final cellW = (c.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
                final extent = cellW * 1.5 + FilmCard.textHeight(MediaQuery.textScalerOf(context)) + 2;
                return CustomScrollView(
                  key: PageStorageKey(storageKey),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (header != null) SliverToBoxAdapter(child: header!(c)),
                    SliverPadding(
                      // + lo que tape la barra de pestañas flotante (iOS nativo).
                      padding: EdgeInsets.fromLTRB(pad, 4, pad, 24 + MediaQuery.paddingOf(context).bottom),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: 14,
                          mainAxisExtent: extent,
                        ),
                        itemCount: films.length,
                        itemBuilder: (context, i) {
                          final f = films[i];
                          final tag = '$storageKey/${f.key}';
                          return FilmCard(
                            heroTag: tag,
                            key: ValueKey(f.key),
                            film: f,
                            now: now,
                            favorite: model.isFavorite(f.key),
                            onTap: () => onOpenFilm(f.key, heroTag: tag),
                            onLongPress: () => toggleFavoriteWithFeedback(context, model, f.key, f.title),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// Marca o desmarca una favorita y lo confirma con un aviso que permite deshacer.
void toggleFavoriteWithFeedback(BuildContext context, AppModel model, String key, String title) {
  final wasFav = model.isFavorite(key);
  model.toggleFavorite(key);
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        wasFav ? 'Quitada de favoritas: $title' : 'Guardada en favoritas: $title',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      // Con «Deshacer», Flutter la deja fija salvo persist: false.
      persist: false,
      action: SnackBarAction(label: 'Deshacer', onPressed: () => model.toggleFavorite(key)),
    ),
  );
}

/// Catálogo por película (películas que cumplen los filtros).
class CatalogView extends StatelessWidget {
  const CatalogView({super.key, required this.model, required this.onOpenFilm, required this.onRefresh});

  final AppModel model;
  final OpenFilm onOpenFilm;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final films = model.films;
    final special = films.where((f) => f.hasSpecial).length;
    return FilmGrid(
      model: model,
      films: films,
      onOpenFilm: onOpenFilm,
      onRefresh: onRefresh,
      storageKey: 'catalog',
      header: (c) => Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${plural(films.length, 'película', 'películas')} · '
                '${plural(model.visible.length, 'pase', 'pases')}'
                '${special > 0 ? ' · $special con especiales' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.55),
              child: SortButton(model: model),
            ),
          ],
        ),
      ),
    );
  }
}

/// Favoritas: las películas guardadas que siguen en cartel, por próximo pase, sin filtros.
class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key, required this.model, required this.onOpenFilm, required this.onRefresh});

  final AppModel model;
  final OpenFilm onOpenFilm;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final films = model.favoriteFilms;
    return FilmGrid(
      model: model,
      films: films,
      onOpenFilm: onOpenFilm,
      onRefresh: onRefresh,
      storageKey: 'favorites',
      header: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          '${plural(films.length, 'película guardada', 'películas guardadas')} · por próximo pase, sin filtros',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ),
      empty: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, size: 44, color: AppColors.muted),
                    SizedBox(height: 16),
                    Text(
                      'Aún no has guardado ninguna película',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Toca el corazón en la ficha de una película, o mantén pulsado su póster en el catálogo. '
                      'Cuando una película deja de estar en cartel, desaparece de aquí sola.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
