import 'dart:convert';

import 'package:cartelera/data/model.dart';
import 'package:cartelera/data/repository.dart';
import 'package:cartelera/data/sources/source.dart';
import 'package:cartelera/ui/app_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repositorio falso: «actualizar» sustituye la cartelera por la que digamos.
class _FakeRepo extends CarteleraRepository {
  _FakeRepo(this._first);
  final Snapshot _first;
  Snapshot? next;
  bool failNext = false;

  @override
  bool get isStale => false;

  @override
  Future<void> load() async {
    snapshot = _first;
    notifyListeners();
  }

  @override
  Future<void> refresh({List<Source>? sources, bool partial = false}) async {
    progress = RefreshProgress(total: 1, done: 0, running: const [], finished: const []);
    notifyListeners();
    if (!failNext) snapshot = next;
    progress = null;
    notifyListeners();
  }
}

Session _s(String title, Duration from) => Session(
      source: 'test', cinema: 'Cine', title: title, start: DateTime.now().add(from));

Snapshot _snap(List<Session> s) => Snapshot(generatedAt: DateTime.now(), sources: const [], sessions: s);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('una favorita se mantiene mientras sigue en cartel y se borra sin residuos cuando desaparece', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeRepo(_snap([_s('Alien', const Duration(hours: 2)), _s('Ordet', const Duration(hours: 3))]));
    final m = AppModel(repo);
    await m.init();

    m.toggleFavorite(normTitle('Alien'));
    m.toggleFavorite(normTitle('Ordet'));
    expect(m.favoriteFilms.map((f) => f.title), ['Alien', 'Ordet']);

    // Una actualización que FALLA no borra nada.
    repo.failNext = true;
    await repo.refresh();
    expect(m.favorites, {'alien', 'ordet'});

    // Una actualización que sigue trayendo Alien (otro día) pero ya no Ordet.
    repo.failNext = false;
    repo.next = _snap([_s('Alien', const Duration(days: 4))]);
    await repo.refresh();
    expect(m.favorites, {'alien'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favorites.v1'), ['alien']);

    // Cuando tampoco está Alien, no queda ni la entrada en preferencias.
    repo.next = _snap([_s('Vertigo', const Duration(hours: 1))]);
    await repo.refresh();
    expect(m.favorites, isEmpty);
    expect(prefs.containsKey('favorites.v1'), isFalse);
    expect(jsonEncode(prefs.getKeys().toList()).contains('favorites'), isFalse);
  });

  test('ni la búsqueda ni los filtros borran favoritas', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _FakeRepo(_snap([_s('Alien', const Duration(hours: 2))]));
    final m = AppModel(repo);
    await m.init();
    m.toggleFavorite('alien');
    m.setFilters(m.filters.copyWith(query: 'nada que coincida'));
    expect(m.films, isEmpty);
    expect(m.favoriteFilms.single.title, 'Alien'); // Favoritas no aplica filtros
    expect(m.favorites, {'alien'});
  });
}
