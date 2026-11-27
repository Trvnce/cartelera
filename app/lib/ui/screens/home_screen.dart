import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../adaptive.dart';
import '../app_model.dart';
import '../filters/filter_state.dart';
import '../filters/filters_screen.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/status_strip.dart';
import 'agenda_view.dart';
import 'catalog_view.dart';
import 'film_screen.dart';
import 'sources_screen.dart';

/// Pantalla principal: Películas (catálogo) y Agenda (por día), con la barra
/// de filtros común encima.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.model});
  final AppModel model;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _searching = false;
  late final _search = TextEditingController(text: widget.model.filters.query);
  final _searchFocus = FocusNode();

  AppModel get model => widget.model;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    _search.text = model.filters.query;
    _searchFocus.requestFocus();
  }

  void _closeSearch({bool clear = false}) {
    if (clear) {
      _search.clear();
      model.setFilters(model.filters.copyWith(query: ''));
    }
    _searchFocus.unfocus();
    setState(() => _searching = false);
  }

  void _openFilm(String filmKey) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FilmScreen(model: model, filmKey: filmKey)),
      );

  void _openSources() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SourcesScreen(model: model)),
      );

  Future<void> _refresh() => model.refresh();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final repo = model.repo;
        final snap = repo.snapshot;
        return PopScope(
          canPop: !_searching,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _searching) _closeSearch();
          },
          child: Scaffold(
            extendBody: useNativeIos,
            appBar: _searching ? _searchBar() : _mainBar(),
            body: Column(
              children: [
                StatusStrip(model: model, onOpenSources: _openSources),
                // En Favoritas no se aplican filtros: se ven todas las guardadas.
                if (model.tab != 2) _FilterBar(model: model, onOpenFilters: () => FiltersScreen.open(context, model)),
                Expanded(
                  child: !model.ready
                      ? const Center(child: CircularProgressIndicator.adaptive())
                      : snap == null
                          ? _NoData(error: repo.lastError, refreshing: repo.refreshing, onRefresh: _refresh)
                          : IndexedStack(
                              index: model.tab,
                              children: [
                                CatalogView(model: model, onOpenFilm: _openFilm, onRefresh: _refresh),
                                AgendaView(model: model, onOpenFilm: _openFilm, onRefresh: _refresh),
                                FavoritesView(model: model, onOpenFilm: _openFilm, onRefresh: _refresh),
                              ],
                            ),
                ),
              ],
            ),
            bottomNavigationBar: adaptiveTabBar(
              context,
              index: model.tab,
              onTap: model.setTab,
              items: [
                const TabItem(
                  label: 'Películas',
                  icon: Icons.grid_view_outlined,
                  selectedIcon: Icons.grid_view_rounded,
                  cupertinoIcon: CupertinoIcons.film,
                  cupertinoSelectedIcon: CupertinoIcons.film_fill,
                  sfSymbol: 'film',
                  sfSymbolSelected: 'film.fill',
                ),
                const TabItem(
                  label: 'Agenda',
                  icon: Icons.calendar_today_outlined,
                  selectedIcon: Icons.calendar_today,
                  cupertinoIcon: CupertinoIcons.calendar,
                  cupertinoSelectedIcon: CupertinoIcons.calendar_today,
                  sfSymbol: 'calendar',
                  sfSymbolSelected: 'calendar',
                ),
                TabItem(
                  label: 'Favoritas',
                  icon: Icons.favorite_border,
                  selectedIcon: Icons.favorite,
                  cupertinoIcon: CupertinoIcons.heart,
                  cupertinoSelectedIcon: CupertinoIcons.heart_fill,
                  sfSymbol: 'heart',
                  sfSymbolSelected: 'heart.fill',
                  badge: model.favoriteFilms.isEmpty ? null : '${model.favoriteFilms.length}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _mainBar() {
    final repo = model.repo;
    final snap = repo.snapshot;
    return adaptiveBar(
      context,
      title: 'Cartelera',
      subtitle: repo.refreshing
          ? 'Actualizando…'
          : snap == null
              ? 'Madrid'
              : 'Madrid · actualizada ${fmtUpdated(snap.generatedAt, model.now)}',
      // En iOS la barra centra el título: las acciones van a la derecha y una a la izquierda.
      leading: isCupertino(context)
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              onPressed: _openSources,
              child: const Icon(CupertinoIcons.antenna_radiowaves_left_right, size: 22),
            )
          : null,
      actions: [
        BarAction(icon: Icons.search, cupertinoIcon: CupertinoIcons.search, sfSymbol: 'magnifyingglass', tooltip: 'Buscar', onPressed: _openSearch),
        BarAction(
          icon: Icons.refresh,
          cupertinoIcon: CupertinoIcons.arrow_clockwise,
          sfSymbol: 'arrow.clockwise',
          tooltip: 'Actualizar la cartelera',
          busy: repo.refreshing,
          onPressed: repo.refreshing ? null : _refresh,
        ),
        if (!isCupertino(context))
          BarAction(icon: Icons.dns_outlined, cupertinoIcon: CupertinoIcons.antenna_radiowaves_left_right, tooltip: 'Fuentes', onPressed: _openSources),
      ],
    );
  }

  PreferredSizeWidget _searchBar() {
    if (isCupertino(context)) {
      return CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: CupertinoSearchTextField(
          controller: _search,
          focusNode: _searchFocus,
          placeholder: 'Título, director, ciclo o cine',
          style: const TextStyle(color: AppColors.cream),
          onChanged: (v) => model.setFilters(model.filters.copyWith(query: v)),
          onSubmitted: (_) => _closeSearch(),
        ),
        trailing: CupertinoButton(
          padding: const EdgeInsets.only(left: 8),
          minimumSize: const Size(44, 44),
          onPressed: () => _closeSearch(clear: true),
          child: const Text('Cancelar'),
        ),
      );
    }
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Cerrar la búsqueda',
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _search,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.none,
        style: const TextStyle(fontSize: 17),
        decoration: const InputDecoration(
          hintText: 'Título, director, ciclo o cine',
          border: InputBorder.none,
        ),
        onChanged: (v) => model.setFilters(model.filters.copyWith(query: v)),
        onSubmitted: (_) => _closeSearch(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Borrar la búsqueda',
          onPressed: () => _search.text.isEmpty ? _closeSearch() : _closeSearch(clear: true),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Un único punto de entrada a los filtros + resumen quitable de los activos.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.model, required this.onOpenFilters});
  final AppModel model;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final active = model.active;
    final f = model.filters;
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          Center(
            child: FilledButton.tonalIcon(
              onPressed: onOpenFilters,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: active.isEmpty ? AppColors.surfaceHigh : AppColors.amber,
                foregroundColor: active.isEmpty ? AppColors.cream : AppColors.onAmber,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.tune, size: 20),
              label: Text(active.isEmpty ? 'Filtros' : 'Filtros · ${active.length}'),
            ),
          ),
          if (active.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  f.showAcademics ? 'Todos los pases' : 'Todos los pases, todos los cines',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ),
          for (final a in active)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: InputChip(
                  label: Text(a.label),
                  onPressed: onOpenFilters,
                  onDeleted: () => model.setFilters(a.without),
                  deleteButtonTooltipMessage: 'Quitar',
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
            ),
          if (active.length > 1)
            Center(
              child: TextButton(
                onPressed: () => model.setFilters(f.cleared()),
                child: const Text('Quitar todos'),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.error, required this.refreshing, required this.onRefresh});
  final String? error;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_movies_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              refreshing ? 'Leyendo la cartelera por primera vez…' : 'Todavía no hay cartelera',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ],
            const SizedBox(height: 20),
            if (!refreshing)
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío compartido por catálogo y agenda (desplazable, para poder
/// tirar hacia abajo y actualizar).
class EmptyResults extends StatelessWidget {
  const EmptyResults({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final filtered = model.active.isNotEmpty;
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 44, color: AppColors.muted),
                  const SizedBox(height: 16),
                  Text(
                    filtered ? 'Ningún pase con estos filtros' : 'No quedan pases por delante',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filtered
                        ? 'Prueba a quitar alguno o a ampliar las fechas.'
                        : 'Tira hacia abajo para actualizar la cartelera.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (filtered) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonal(
                      onPressed: () => model.setFilters(model.filters.cleared()),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text('Quitar los filtros'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menú de ordenación del catálogo (también está en la pantalla de filtros).
class SortButton extends StatelessWidget {
  const SortButton({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final f = model.filters;
    if (useNativeIos) {
      // iPhone: menú nativo de UIKit con la opción actual marcada.
      return Padding(
        padding: const EdgeInsets.only(left: 12),
        child: CNPopupMenuButton(
          buttonLabel: sortLabel(f.sort),
          buttonIcon: const CNSymbol('arrow.up.arrow.down', size: 13),
          buttonStyle: CNButtonStyle.glass,
          shrinkWrap: true,
          labelFontSize: 13,
          semanticLabel: 'Ordenar',
          items: [
            for (final s in CatalogSort.values) CNPopupMenuItem(label: sortLabel(s), checked: s == f.sort),
          ],
          onSelected: (i) => model.setFilters(f.copyWith(sort: CatalogSort.values[i])),
        ),
      );
    }
    if (isCupertino(context)) {
      // Aspecto iOS dibujado por Flutter: hoja de acción.
      return CupertinoButton(
        padding: const EdgeInsets.only(left: 12),
        minimumSize: const Size(44, 44),
        onPressed: () async {
          final s = await showAdaptiveChoice<CatalogSort>(
            context,
            title: 'Ordenar las películas',
            values: CatalogSort.values,
            label: sortLabel,
            selected: f.sort,
          );
          if (s != null) model.setFilters(f.copyWith(sort: s));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.arrow_up_arrow_down, size: 15, color: AppColors.cream),
            const SizedBox(width: 5),
            Flexible(
              child: Text(sortLabel(f.sort), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.cream)),
            ),
          ],
        ),
      );
    }
    return PopupMenuButton<CatalogSort>(
      tooltip: 'Ordenar',
      initialValue: f.sort,
      onSelected: (s) => model.setFilters(f.copyWith(sort: s)),
      itemBuilder: (_) => [
        for (final s in CatalogSort.values) PopupMenuItem(value: s, height: 48, child: Text(sortLabel(s))),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.swap_vert, size: 18, color: AppColors.cream),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  sortLabel(f.sort),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
