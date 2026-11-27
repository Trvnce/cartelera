import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../adaptive.dart';
import '../../data/model.dart';
import '../app_model.dart';
import '../filters/catalog.dart';
import '../format.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/badges.dart';
import '../widgets/open_url.dart';
import '../widgets/poster.dart';
import '../widgets/poster_backdrop.dart';
import 'agenda_view.dart' show DayHeader;
import 'alerts_screen.dart' show showPermissionDenied;
import 'catalog_view.dart' show toggleFavoriteWithFeedback;

/// Ficha de una película: datos y TODOS sus pases, por día y por cine.
class FilmScreen extends StatefulWidget {
  const FilmScreen({super.key, required this.model, required this.filmKey, this.heroTag});

  final AppModel model;
  final String filmKey;

  /// Póster de la pantalla anterior que vuela hasta la cabecera (Android).
  final String? heroTag;

  @override
  State<FilmScreen> createState() => _FilmScreenState();
}

class _FilmScreenState extends State<FilmScreen> {
  /// Enseñar solo los pases que cumplen los filtros de la pantalla principal.
  bool _onlyFiltered = false;

  /// Android: la barra, su título y el fondo de la cabecera siguen al scroll en continuo
  /// (sin umbrales ni animaciones disparadas), así no hay saltos al subir o bajar.
  final _scroll = ScrollController();

  /// 0 → 1 según el scroll pasa de [from] a [to] píxeles.
  double _progress(double from, double to) {
    if (!_scroll.hasClients) return 0;
    return ((_scroll.offset - from) / (to - from)).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggleAlert(AppModel model, Film film) async {
    HapticFeedback.lightImpact();
    final watching = model.isFilmWatched(widget.filmKey);
    final granted = await model.toggleFilmAlert(widget.filmKey, film.title);
    if (!mounted) return;
    if (!granted) return showPermissionDenied(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            watching
                ? 'Ya no te avisaremos de ${film.title}'
                : 'Te avisaremos de cada pase nuevo de ${film.title}, en cualquier cine',
          ),
          // Con «Deshacer», Flutter la deja fija salvo persist: false.
          persist: false,
          action: SnackBarAction(label: 'Deshacer', onPressed: () => model.toggleFilmAlert(widget.filmKey, film.title)),
        ),
      );
  }

  void _toggleFavorite(AppModel model, Film film) {
    if (useMaterialMotion(context)) HapticFeedback.lightImpact();
    toggleFavoriteWithFeedback(context, model, widget.filmKey, film.title);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final all = model.sessionsOfFilm(widget.filmKey);
        if (all.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Ya no quedan pases de esta película.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          );
        }
        final film = Film(widget.filmKey, all);
        final matching = model.visible.where((s) => s.filmKey == widget.filmKey).toList();
        final canNarrow = matching.isNotEmpty && matching.length < all.length;
        final shown = _onlyFiltered && canNarrow ? matching : all;
        final days = groupByDay(shown);
        final now = model.now;
        final material = useMaterialMotion(context);
        final fav = model.isFavorite(widget.filmKey);
        return Scaffold(
          appBar: material
              ? null
              : adaptiveBar(
                  context,
                  title: film.title,
                  leading: isCupertino(context)
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Atrás',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                  actions: [
                    BarAction(
                      icon: model.isFavorite(widget.filmKey) ? Icons.favorite : Icons.favorite_border,
                      cupertinoIcon: model.isFavorite(widget.filmKey)
                          ? CupertinoIcons.heart_fill
                          : CupertinoIcons.heart,
                      sfSymbol: model.isFavorite(widget.filmKey) ? 'heart.fill' : 'heart',
                      color: model.isFavorite(widget.filmKey) ? AppColors.amber : null,
                      tooltip: model.isFavorite(widget.filmKey) ? 'Quitar de favoritas' : 'Guardar en favoritas',
                      onPressed: () => _toggleFavorite(model, film),
                    ),
                  ],
                ),
          body: _body(
            material: material,
            backdrop: film.poster,
            slivers: [
              if (material) _materialBar(film, fav, model),
              SliverToBoxAdapter(
                child: _Header(film: film, heroTag: widget.heroTag),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${plural(shown.length, 'pase', 'pases')} · '
                          '${plural({for (final s in shown) s.cinema}.length, 'cine', 'cines')}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted),
                        ),
                      ),
                      if (canNarrow)
                        FilterChip(
                          label: Text('Solo los filtrados (${matching.length})'),
                          selected: _onlyFiltered,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          onSelected: (v) => setState(() => _onlyFiltered = v),
                        ),
                    ],
                  ),
                ),
              ),
              for (final g in days)
                SliverMainAxisGroup(
                  slivers: [
                    PinnedHeaderSliver(
                      child: DayHeader(day: g.day, now: now),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      sliver: SliverList.list(children: _cinemaCards(context, g.sessions)),
                    ),
                  ],
                ),
              SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        );
      },
    );
  }

  /// Android: el fondo difuminado va detrás de todo y sube a media velocidad (parallax).
  Widget _body({required bool material, required String? backdrop, required List<Widget> slivers}) {
    final list = CustomScrollView(controller: _scroll, slivers: slivers);
    if (!material) return list;
    final h = 340 + MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _scroll,
          builder: (context, child) => Positioned(
            top: _scroll.hasClients ? -_scroll.offset.clamp(0.0, h) * 0.5 : 0,
            left: 0,
            right: 0,
            height: h,
            // Se apaga del todo antes de que la primera cabecera de día se quede fija: así
            // las cabeceras (de fondo liso) nunca quedan como bandas sobre el color.
            child: Opacity(opacity: 1 - Curves.easeIn.transform(_progress(0, h * 0.6)), child: child),
          ),
          child: RepaintBoundary(child: PosterBackdrop(url: backdrop)),
        ),
        list,
      ],
    );
  }

  /// Barra de Android: transparente sobre el fondo de la cabecera; al bajar, se vuelve
  /// opaca y recibe el título.
  Widget _materialBar(Film film, bool fav, AppModel model) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: AnimatedBuilder(
        animation: _scroll,
        builder: (context, _) => ColoredBox(
          color: AppColors.bg.withValues(alpha: Curves.easeOut.transform(_progress(24, 170))),
          child: const SizedBox.expand(),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Atrás',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      titleSpacing: 0,
      // El título entra a la vez que el grande de la cabecera se va por arriba.
      title: AnimatedBuilder(
        animation: _scroll,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_progress(90, 170));
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
          );
        },
        child: Text(
          film.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      actions: [
        if (AppModel.alertsSupported)
          Builder(
            builder: (context) {
              final on = model.isFilmWatched(widget.filmKey);
              return IconButton(
                tooltip: on ? 'Dejar de avisarme' : 'Avisarme de pases nuevos',
                onPressed: () => _toggleAlert(model, film),
                icon: SwapIcon(
                  child: Icon(
                    on ? Icons.notifications_active : Icons.notifications_none,
                    key: ValueKey(on),
                    color: on ? AppColors.amber : null,
                  ),
                ),
              );
            },
          ),
        IconButton(
          tooltip: fav ? 'Quitar de favoritas' : 'Guardar en favoritas',
          onPressed: () => _toggleFavorite(model, film),
          icon: SwapIcon(
            child: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              key: ValueKey(fav),
              color: fav ? AppColors.amber : null,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  List<Widget> _cinemaCards(BuildContext context, List<Session> sessions) {
    final byCinema = <String, List<Session>>{};
    for (final s in sessions) {
      (byCinema[s.cinema] ??= []).add(s);
    }
    return [
      for (final e in byCinema.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(e.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                for (var i = 0; i < e.value.length; i++) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  _SessionRow(session: e.value[i]),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.film, this.heroTag});
  final Film film;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final f = film;
    final facts = [if (f.year != null) '${f.year}', if (f.durationMin != null) fmtDuration(f.durationMin!)].join(' · ');
    final versions = f.versions.map(versionLabel).whereType<String>().toList();
    final notes = <String>{
      for (final s in f.sessions)
        if (s.note != null && s.note!.trim().isNotEmpty) s.note!.trim(),
    };
    // Una nota común a todos los pases se cuenta una vez arriba.
    final commonNote = notes.length == 1 && f.sessions.every((s) => s.note?.trim() == notes.first) ? notes.first : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterHero(
                tag: heroTag,
                radius: 12,
                child: SizedBox(
                  width: 132,
                  height: 198,
                  child: Poster(url: f.poster, title: f.title, cacheWidth: 400),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.title,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (f.director != null && f.director!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(f.director!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(facts, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                    ],
                    if (versions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 4, children: [for (final v in versions) Pill(v)]),
                    ],
                    if (f.specialTags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [for (final t in f.specialTags) Pill(capitalize(t), kind: PillKind.special)],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (f.cycles.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final c in f.cycles)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.star_rounded, size: 16, color: AppColors.amber),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.amber),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (commonNote != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Text(commonNote, style: const TextStyle(fontSize: 14, height: 1.35)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final price = fmtPrice(s.priceEur);
    final line = [if (s.room != null && s.room!.isNotEmpty) s.room!, ?versionLabel(s.version), ?price].join(' · ');
    final note = s.note?.trim();
    final cycle = s.cycle?.trim();
    final url = (s.ticketUrl != null && s.ticketUrl!.isNotEmpty) ? s.ticketUrl : null;
    final info = (s.infoUrl != null && s.infoUrl!.isNotEmpty) ? s.infoUrl : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              fmtTime(s.start),
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: s.isSpecial ? AppColors.amber : AppColors.cream,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.isNotEmpty) Text(line, style: const TextStyle(fontSize: 14, height: 1.3)),
                if (cycle != null && cycle.isNotEmpty)
                  Text(cycle, style: const TextStyle(fontSize: 13, height: 1.3, color: AppColors.amber)),
                Padding(padding: const EdgeInsets.only(top: 4), child: SessionBadges(s, showVersion: false)),
                if (note != null && note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(note, style: const TextStyle(fontSize: 13, height: 1.3, color: AppColors.muted)),
                  ),
                if (s.priceNote != null && s.priceNote!.trim().isNotEmpty && price != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      s.priceNote!.trim(),
                      style: const TextStyle(fontSize: 12, height: 1.3, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (url != null)
            FilledButton.tonal(
              onPressed: () => openUrl(context, url),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: AppColors.amberContainer,
                foregroundColor: const Color(0xFFFFE2A6),
              ),
              child: const Text('Entradas'),
            )
          else if (info != null)
            OutlinedButton(
              onPressed: () => openUrl(context, info),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Más info'),
            ),
        ],
      ),
    );
  }
}
