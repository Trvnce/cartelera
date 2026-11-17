import 'dart:convert';
import 'dart:io';

import 'package:cartelera/data/model.dart';
import 'package:cartelera/ui/filters/catalog.dart';
import 'package:cartelera/ui/filters/cinema_groups.dart';
import 'package:cartelera/ui/filters/filter_state.dart';
import 'package:cartelera/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';

Session pase(
  String title,
  DateTime start, {
  String cinema = 'Golem Madrid',
  String? version,
  List<String> tags = const [],
  double? price,
  String? director,
  String? cycle,
}) =>
    Session(
      source: 'test',
      cinema: cinema,
      title: title,
      start: start,
      version: version,
      tags: [...tags],
      priceEur: price,
      director: director,
      cycle: cycle,
    );

void main() {
  // Martes 17 de noviembre de 2026, 17:00.
  final now = DateTime(2026, 11, 17, 17);

  final all = [
    pase('Ya empezó', DateTime(2026, 11, 17, 16, 30), version: 'VOSE'),
    pase('Recién empezada', DateTime(2026, 11, 17, 16, 50), version: 'VOSE', price: 8.4),
    pase('El apartamento', DateTime(2026, 11, 17, 20), cinema: 'Cine Doré (Filmoteca)', version: 'VOSE',
        tags: ['clásico', 'ciclo'], price: 3, director: 'Billy Wilder', cycle: 'Domingo de clásicos'),
    pase('EL APARTAMENTO', DateTime(2026, 11, 21, 12), cinema: 'Renoir Retiro', version: 'DOBLADA', price: 9),
    pase('Los domingos', DateTime(2026, 11, 18, 18), version: 'ES', price: 7.5),
    pase('Estreno gordo', DateTime(2026, 11, 20, 22), cinema: 'Yelmo Cines Ideal', price: 9.9),
    pase('Pase privado', DateTime(2026, 11, 17, 19), cinema: 'Academia de Cine', tags: ['solo académicos']),
    pase('Coloquio gratis', DateTime(2026, 11, 22, 11), cinema: 'Cineteca Madrid', tags: ['coloquio'], price: 0),
    pase('Lejana', DateTime(2026, 12, 3, 19)),
  ];
  final upcoming = upcomingSessions(all, now);

  List<String> titles(FilterState f) => applyFilters(upcoming, f, now).map((s) => s.title).toList();

  test('los pases que empezaron hace más de 15 min desaparecen', () {
    expect(upcoming.map((s) => s.title), isNot(contains('Ya empezó')));
    expect(upcoming.first.title, 'Recién empezada');
  });

  test('por defecto se ocultan los pases solo para académicos', () {
    expect(titles(const FilterState()), isNot(contains('Pase privado')));
    expect(titles(const FilterState(showAcademics: true)), contains('Pase privado'));
  });

  test('cuándo: hoy, mañana, fin de semana, 7 días y día concreto', () {
    expect(titles(const FilterState(when: WhenFilter.today)), ['Recién empezada', 'El apartamento']);
    expect(titles(const FilterState(when: WhenFilter.tomorrow)), ['Los domingos']);
    expect(titles(const FilterState(when: WhenFilter.weekend)), ['Estreno gordo', 'EL APARTAMENTO', 'Coloquio gratis']);
    expect(titles(const FilterState(when: WhenFilter.next7)), isNot(contains('Lejana')));
    expect(titles(FilterState(when: WhenFilter.date, date: DateTime(2026, 12, 3))), ['Lejana']);
  });

  test('el fin de semana, si ya estamos en él, empieza hoy', () {
    final sabado = DateTime(2026, 11, 21, 10);
    final r = whenRange(const FilterState(when: WhenFilter.weekend), sabado)!;
    expect(r.$1, DateTime(2026, 11, 21));
    expect(r.$2, DateTime(2026, 11, 23));
  });

  test('franja, versión, especiales, etiquetas, precio y cines', () {
    expect(titles(const FilterState(bands: {TimeBand.morning})), ['EL APARTAMENTO', 'Coloquio gratis']);
    expect(titles(const FilterState(versions: {VersionFilter.spanish})), ['Los domingos']);
    expect(titles(const FilterState(versions: {VersionFilter.original})), ['Recién empezada', 'El apartamento']);
    expect(titles(const FilterState(onlySpecial: true)), ['El apartamento', 'Coloquio gratis']);
    expect(titles(const FilterState(tags: {'coloquio'})), ['Coloquio gratis']);
    // Sin precio publicado («Lejana») no se descarta.
    expect(titles(const FilterState(maxPrice: 3)), ['El apartamento', 'Coloquio gratis', 'Lejana']);
    expect(titles(const FilterState(maxPrice: 0)), ['Coloquio gratis', 'Lejana']);
    expect(
      titles(const FilterState(excludedCinemas: {'Golem Madrid', 'Renoir Retiro', 'Yelmo Cines Ideal'})),
      ['El apartamento', 'Coloquio gratis'],
    );
  });

  test('la búsqueda ignora tildes y mira director, ciclo y cine', () {
    expect(titles(const FilterState(query: 'wilder')), ['El apartamento']);
    expect(titles(const FilterState(query: 'CLASICOS domingo')), ['El apartamento']);
    expect(titles(const FilterState(query: 'dore')), ['El apartamento']);
    expect(titles(const FilterState(query: 'nada de nada')), isEmpty);
  });

  test('agrupa por película entre cines y ordena', () {
    final films = groupFilms(applyFilters(upcoming, const FilterState(), now));
    final apto = films.firstWhere((f) => f.key == 'el apartamento');
    expect(apto.sessions.length, 2);
    expect(apto.cinemas.length, 2);
    expect(apto.versions, ['VOSE', 'DOBLADA']);
    expect(apto.specialTags, ['ciclo', 'clásico']);
    expect(apto.director, 'Billy Wilder');
    expect(films.first.hasSpecial, isTrue); // especiales primero
    final az = groupFilms(upcoming, CatalogSort.alphabetical);
    expect(az.map((f) => f.key).toList(), [...az.map((f) => f.key)]..sort());
    expect(groupFilms(upcoming, CatalogSort.mostSessions).first.key, 'el apartamento');
  });

  test('agrupa por día en orden', () {
    final days = groupByDay(upcoming);
    expect(days.first.day, DateTime(2026, 11, 17));
    expect(days.map((d) => d.day).toList(), [...days.map((d) => d.day)]..sort());
  });

  test('filtros activos: resumen y quitar uno', () {
    const f = FilterState(
      when: WhenFilter.today,
      versions: {VersionFilter.original},
      tags: {'coloquio'},
      maxPrice: 8.5,
      excludedCinemas: {'Golem Madrid'},
    );
    final active = activeFilters(f, allCinemas: ['Golem Madrid', 'Renoir Retiro', 'Cineteca Madrid']);
    expect(active.map((a) => a.label), ['Hoy', 'Coloquio', 'VOSE / V.O.', 'Cines: 2 de 3', 'Hasta 8,50 €']);
    expect(active.first.without.when, WhenFilter.all);
    expect(active.first.without.versions, f.versions);
    expect(activeFilters(const FilterState()), isEmpty);
    // La ordenación no cuenta como filtro y sobrevive a «Restablecer».
    expect(activeFilters(const FilterState(sort: CatalogSort.alphabetical)), isEmpty);
    expect(f.copyWith(sort: CatalogSort.alphabetical).cleared().sort, CatalogSort.alphabetical);
  });

  test('los filtros se guardan y se recuperan', () {
    final f = FilterState(
      query: 'no se guarda',
      when: WhenFilter.date,
      date: DateTime(2026, 11, 20),
      bands: const {TimeBand.night},
      versions: const {VersionFilter.original, VersionFilter.spanish},
      onlySpecial: true,
      tags: const {'35 mm'},
      maxPrice: 6.5,
      showAcademics: true,
      excludedCinemas: const {'Verdi Madrid'},
      sort: CatalogSort.mostSessions,
    );
    final g = FilterState.decode(f.encode());
    expect(g.query, '');
    expect(g.when, WhenFilter.date);
    expect(g.date, DateTime(2026, 11, 20));
    expect(g.bands, f.bands);
    expect(g.versions, f.versions);
    expect(g.onlySpecial, isTrue);
    expect(g.tags, f.tags);
    expect(g.maxPrice, 6.5);
    expect(g.showAcademics, isTrue);
    expect(g.excludedCinemas, f.excludedCinemas);
    expect(g.sort, CatalogSort.mostSessions);
    expect(FilterState.decode('{roto').when, WhenFilter.all);
  });

  test('formato de precio, versión y fechas', () {
    expect(fmtPrice(8.4), '8,40 €');
    expect(fmtPrice(0), 'Gratis');
    expect(fmtPrice(null), isNull);
    expect(versionLabel('ES'), 'V.O. castellano');
    expect(fmtDayTitle(DateTime(2026, 11, 17, 22), now), 'Hoy');
    expect(fmtDayTitle(DateTime(2026, 11, 18, 1), now), 'Mañana');
    expect(fmtDayTitle(DateTime(2026, 11, 19), now), 'Jueves 19');
  });

  test('clasifica los cines reales del ejemplo y deja «Otros» para los nuevos', () {
    final raw = jsonDecode(File('assets/sample_snapshot.json').readAsStringSync()) as Map<String, dynamic>;
    final snap = Snapshot.fromJson(raw);
    final cinemas = {for (final s in snap.sessions) s.cinema};
    for (final c in cinemas) {
      expect(cinemaGroupOf(c), isNot(CinemaGroup.other), reason: c);
    }
    expect(cinemaGroupOf('mk2 Cinesur Luz del Tajo (Toledo)'), CinemaGroup.outside);
    expect(cinemaGroupOf('Cine Doré (Filmoteca)'), CinemaGroup.arthouse);
    expect(cinemaGroupOf('Yelmo Cines Ideal'), CinemaGroup.chains);
    expect(cinemaGroupOf('Cine Inventado'), CinemaGroup.other);
    // Y el ejemplo entero pasa por el filtrado y el agrupado sin romperse.
    final up = upcomingSessions(snap.sessions, DateTime(2026, 11, 17, 9));
    final films = groupFilms(applyFilters(up, const FilterState(), DateTime(2026, 11, 17, 9)));
    expect(films, isNotEmpty);
    expect(films.fold<int>(0, (n, f) => n + f.sessions.length), up.where((s) => !s.academicsOnly).length);
  });
}
