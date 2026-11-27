import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/alerts.dart';
import '../data/engine.dart' show allSources;
import '../data/model.dart';
import '../data/repository.dart';
import '../data/sources/source.dart';
import 'filters/catalog.dart';
import 'filters/filter_state.dart';

export 'filters/catalog.dart' show Film;

/// Estado de la interfaz: une el repositorio con los filtros y guarda ya
/// calculado lo que pintan las pantallas (pases visibles, películas, días).
class AppModel extends ChangeNotifier {
  AppModel(this.repo);

  static const _kFilters = 'ui.filters.v1';
  static const _kTab = 'ui.tab';
  static const _kFavorites = 'favorites.v1';
  static const _kDisabledSources = 'sources.disabled.v1';

  /// Pestañas: 0 Películas · 1 Agenda · 2 Favoritas.
  static const tabCount = 3;

  final CarteleraRepository repo;

  FilterState _filters = const FilterState();
  FilterState get filters => _filters;

  int _tab = 0;
  int get tab => _tab;

  bool ready = false;

  /// Pases aún por empezar, sin filtrar.
  List<Session> upcoming = const [];

  /// Pases que cumplen los filtros, por hora.
  List<Session> visible = const [];
  List<Film> films = const [];
  List<DayGroup> days = const [];

  /// Cines con algún pase por delante.
  List<String> cinemas = const [];
  List<ActiveFilter> active = const [];

  /// Pases que vienen de una lectura anterior porque su fuente ha fallado.
  int staleCount = 0;

  /// Películas guardadas (por `filmKey`). Solo se guardan las claves: cuando una
  /// película deja de tener pases en una cartelera recién leída, su clave se borra
  /// y, si no queda ninguna, también la entrada de preferencias.
  Set<String> favorites = {};

  /// Las favoritas con pases por delante (sin aplicar filtros), por próximo pase.
  List<Film> favoriteFilms = const [];

  bool isFavorite(String filmKey) => favorites.contains(filmKey);

  void toggleFavorite(String filmKey) {
    favorites = {...favorites};
    if (!favorites.remove(filmKey)) favorites.add(filmKey);
    _saveFavorites();
    _recompute();
  }

  void _saveFavorites() {
    if (favorites.isEmpty) {
      _prefs?.remove(_kFavorites); // sin residuos
    } else {
      _prefs?.setStringList(_kFavorites, favorites.toList()..sort());
    }
  }

  /// Fuentes que el usuario ha desactivado (por `Source.id`): no se leen al actualizar y
  /// sus pases no se enseñan.
  Set<String> disabledSources = {};

  bool isSourceEnabled(String id) => !disabledSources.contains(id);

  List<Source> get enabledSources => [for (final s in allSources) if (!disabledSources.contains(s.id)) s];

  /// Fuentes activadas mientras había otra actualización en marcha: se leen al acabar.
  final Set<String> _pendingEnable = {};

  /// Actualiza todas las fuentes activadas.
  Future<void> refresh() => repo.refresh(sources: enabledSources);

  /// Activa o desactiva una fuente. Al desactivarla, sus pases desaparecen ya; al activarla,
  /// se lee solo esa web y se añade a lo que había. No deja desactivar la última.
  void setSourceEnabled(String id, bool enabled) {
    if (enabled == isSourceEnabled(id)) return;
    if (!enabled && enabledSources.length <= 1) return;
    disabledSources = {...disabledSources};
    if (enabled) {
      disabledSources.remove(id);
    } else {
      disabledSources.add(id);
      _pendingEnable.remove(id);
    }
    if (disabledSources.isEmpty) {
      _prefs?.remove(_kDisabledSources);
    } else {
      _prefs?.setStringList(_kDisabledSources, disabledSources.toList()..sort());
    }
    _recompute();
    if (enabled) {
      _pendingEnable.add(id);
      _readPendingSources();
    } else {
      unawaited(repo.dropSources({id}));
    }
  }

  void _readPendingSources() {
    if (repo.refreshing || _pendingEnable.isEmpty) return;
    final list = [for (final s in allSources) if (_pendingEnable.contains(s.id)) s];
    _pendingEnable.clear();
    if (list.isNotEmpty) unawaited(repo.refresh(sources: list, partial: true));
  }

  // ── Avisos de pases nuevos (solo Android) ──────────────────────────────────────────

  /// Los avisos dependen de WorkManager y de las notificaciones de Android.
  static final bool alertsSupported = !kIsWeb && Platform.isAndroid;

  AlertPrefs alerts = AlertPrefs();

  bool isFilmWatched(String filmKey) => alerts.films.containsKey(filmKey);
  bool isSourceWatched(String id) => alerts.sources.contains(id);

  /// Activa o quita el aviso de una película. Al activar el primero pide el permiso de
  /// notificaciones; devuelve false si se ha denegado (el aviso se guarda igualmente).
  Future<bool> toggleFilmAlert(String filmKey, String title) async {
    final films = {...alerts.films};
    final adding = !films.containsKey(filmKey);
    if (adding) {
      films[filmKey] = title;
    } else {
      films.remove(filmKey);
    }
    return _setAlerts(alerts.copyWith(films: films), asking: adding);
  }

  Future<bool> toggleSourceAlert(String id) async {
    final sources = {...alerts.sources};
    final adding = sources.add(id);
    if (!adding) sources.remove(id);
    return _setAlerts(alerts.copyWith(sources: sources), asking: adding);
  }

  Future<void> setAlertInterval(Duration d) => _setAlerts(alerts.copyWith(interval: d));

  Future<bool> _setAlerts(AlertPrefs a, {bool asking = false}) async {
    alerts = a;
    repo.alerts = a;
    notifyListeners();
    final p = _prefs;
    if (p != null) await a.write(p);
    if (!alertsSupported) return true;
    final granted = asking ? await AlertNotifier.requestPermission() : true;
    await AlertScheduler.sync(a);
    return granted;
  }

  /// Última comprobación en segundo plano: cuándo y qué encontró.
  Future<({DateTime? at, String? result})> lastAlertRun() async {
    final p = _prefs;
    if (p == null) return (at: null, result: null);
    await p.reload();
    return (at: DateTime.tryParse(p.getString(AlertPrefs.kLastRun) ?? ''), result: p.getString(AlertPrefs.kLastResult));
  }

  AppLifecycleListener? _lifecycle;

  SharedPreferences? _prefs;
  Timer? _minute;
  Timer? _saveDebounce;
  Snapshot? _lastSnapshot;
  bool _wasRefreshing = false;

  DateTime get now => DateTime.now();

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _filters = FilterState.decode(_prefs!.getString(_kFilters));
      _tab = (_prefs!.getInt(_kTab) ?? 0).clamp(0, tabCount - 1);
      favorites = {...?_prefs!.getStringList(_kFavorites)};
      final known = {for (final s in allSources) s.id};
      disabledSources = {...?_prefs!.getStringList(_kDisabledSources)}.intersection(known);
      alerts = AlertPrefs.read(_prefs!);
      repo.alerts = alerts;
    } catch (_) {
      // Sin preferencias se arranca con los filtros por defecto.
    }
    repo.addListener(_onRepo);
    await repo.load();
    ready = true;
    _recompute();
    // Los pases que van empezando desaparecen solos.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
    if (repo.isStale) unawaited(refresh());
    if (alertsSupported) {
      // Al volver a la app, lo que haya guardado la comprobación en segundo plano.
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(repo.reloadIfChanged()));
      // Reprograma la tarea (p. ej., tras instalar una versión nueva).
      if (!alerts.isEmpty) unawaited(AlertScheduler.sync(alerts));
    }
  }

  void _onRepo() {
    final snap = repo.snapshot;
    if (!identical(snap, _lastSnapshot)) {
      // Cartelera nueva salida de una actualización (no la cargada del disco al abrir).
      if (_wasRefreshing && snap != null) _pruneFavoritesAfterRefresh(snap);
      _wasRefreshing = repo.refreshing;
      _recompute();
      if (!repo.refreshing) _afterRefresh();
    } else {
      final finishedNow = _wasRefreshing && !repo.refreshing;
      _wasRefreshing = repo.refreshing;
      notifyListeners(); // progreso de la actualización
      if (finishedNow) _afterRefresh();
    }
  }

  /// Al acabar una actualización: lo que se activó mientras tanto se lee ahora, y lo que se
  /// desactivó mientras tanto (y la lectura ya traía) se quita de la cartelera guardada.
  void _afterRefresh() {
    final drop = {
      for (final s in repo.snapshot?.sources ?? const <SourceStatus>[])
        if (disabledSources.contains(s.id)) s.id,
    };
    if (drop.isNotEmpty) unawaited(repo.dropSources(drop));
    _readPendingSources();
  }

  void setFilters(FilterState f) {
    _filters = f;
    _recompute();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      _prefs?.setString(_kFilters, _filters.encode());
    });
  }

  void setTab(int t) {
    if (t == _tab) return;
    _tab = t;
    _prefs?.setInt(_kTab, t);
    notifyListeners();
  }

  void _recompute() {
    final snap = repo.snapshot;
    _lastSnapshot = snap;
    final n = now;
    upcoming = upcomingSessions(
      [for (final s in snap?.sessions ?? const <Session>[]) if (!disabledSources.contains(s.source)) s],
      n,
    );
    visible = applyFilters(upcoming, _filters, n);
    films = groupFilms(visible, _filters.sort);
    days = groupByDay(visible);
    cinemas = {for (final s in upcoming) s.cinema}.toList();
    active = activeFilters(_filters, allCinemas: cinemas);
    staleCount = upcoming.where((s) => s.stale).length;
    favoriteFilms = groupFilms(
      upcoming.where((s) => favorites.contains(s.filmKey) && (_filters.showAcademics || !s.academicsOnly)),
      CatalogSort.nextSession,
    );
    notifyListeners();
  }

  /// Tras cada actualización: una favorita sigue guardada mientras la película aparezca
  /// en lo que se acaba de leer (cualquier cine, cualquier día). Si la lectura ya no la
  /// encuentra, se borra su clave. Ni el paso de las horas, ni la búsqueda, ni los
  /// filtros borran nunca una favorita: solo una lectura nueva de las webs.
  void _pruneFavoritesAfterRefresh(Snapshot fresh) {
    if (favorites.isEmpty) return;
    final present = {for (final s in fresh.sessions) s.filmKey};
    final gone = favorites.difference(present);
    if (gone.isEmpty) return;
    favorites = favorites.difference(gone);
    _saveFavorites();
  }

  /// Todos los pases por delante de una película, cumplan o no los filtros.
  List<Session> sessionsOfFilm(String filmKey) => [
        for (final s in upcoming)
          if (s.filmKey == filmKey && (_filters.showAcademics || !s.academicsOnly)) s,
      ];

  /// Cuántos pases quedarían con otros filtros (para el botón de la hoja de filtros).
  int countFor(FilterState f) => applyFilters(upcoming, f, now).length;

  @override
  void dispose() {
    _minute?.cancel();
    _saveDebounce?.cancel();
    _lifecycle?.dispose();
    repo.removeListener(_onRepo);
    super.dispose();
  }
}
