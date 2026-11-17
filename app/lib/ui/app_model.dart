import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/model.dart';
import '../data/repository.dart';
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
    } catch (_) {
      // Sin preferencias se arranca con los filtros por defecto.
    }
    repo.addListener(_onRepo);
    await repo.load();
    ready = true;
    _recompute();
    // Los pases que van empezando desaparecen solos.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => _recompute());
    if (repo.isStale) unawaited(repo.refresh());
  }

  void _onRepo() {
    final snap = repo.snapshot;
    if (!identical(snap, _lastSnapshot)) {
      // Cartelera nueva salida de una actualización (no la cargada del disco al abrir).
      if (_wasRefreshing && snap != null) _pruneFavoritesAfterRefresh(snap);
      _wasRefreshing = repo.refreshing;
      _recompute();
    } else {
      _wasRefreshing = repo.refreshing;
      notifyListeners(); // progreso de la actualización
    }
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
    upcoming = upcomingSessions(snap?.sessions ?? const <Session>[], n);
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
    repo.removeListener(_onRepo);
    super.dispose();
  }
}
