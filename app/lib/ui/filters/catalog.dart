// Filtrado, agrupado y ordenación de pases. Código puro (sin Flutter): se
// prueba en test/catalog_test.dart.

import '../../data/model.dart';
import '../format.dart';
import 'filter_state.dart';

/// Un pase deja de mostrarse cuando empezó hace más de esto.
const startedGrace = Duration(minutes: 15);

/// Orden de importancia de las etiquetas especiales (para la marca del póster).
const tagPriority = [
  '70 mm',
  '35 mm',
  'coloquio',
  'presentación',
  'música en directo',
  'preestreno',
  'festival',
  'ciclo',
  'clásico',
  'reestreno',
  'restaurada',
  'pase especial',
];

int _tagRank(String t) {
  final i = tagPriority.indexOf(t);
  return i < 0 ? tagPriority.length : i;
}

List<String> sortTags(Iterable<String> tags) => tags.toList()
  ..sort((a, b) {
    final r = _tagRank(a).compareTo(_tagRank(b));
    return r != 0 ? r : a.compareTo(b);
  });

/// Pases que aún no han empezado (o empezaron hace menos de 15 min), por hora.
List<Session> upcomingSessions(Iterable<Session> all, DateTime now) {
  final limit = now.subtract(startedGrace);
  return all.where((s) => !s.start.isBefore(limit)).toList()
    ..sort((a, b) {
      final r = a.start.compareTo(b.start);
      return r != 0 ? r : a.cinema.compareTo(b.cinema);
    });
}

TimeBand bandOf(DateTime start) {
  final h = start.hour;
  if (h < 6) return TimeBand.night; // madrugada: sesión golfa
  if (h < 15) return TimeBand.morning;
  if (h < 20) return TimeBand.afternoon;
  return TimeBand.night;
}

VersionFilter versionOf(Session s) => switch (s.version) {
      'VOSE' || 'VO' => VersionFilter.original,
      'ES' => VersionFilter.spanish,
      'DOBLADA' => VersionFilter.dubbed,
      _ => VersionFilter.unknown,
    };

/// Rango de días [desde, hasta) que cubre el filtro «Cuándo»; null = todo.
(DateTime, DateTime)? whenRange(FilterState f, DateTime now) {
  final today = dayOf(now);
  switch (f.when) {
    case WhenFilter.all:
      return null;
    case WhenFilter.today:
      return (today, addDays(today, 1));
    case WhenFilter.tomorrow:
      return (addDays(today, 1), addDays(today, 2));
    case WhenFilter.weekend:
      // De viernes a domingo; si ya estamos en él, desde hoy.
      final wd = today.weekday;
      final from = wd >= DateTime.friday ? today : addDays(today, DateTime.friday - wd);
      return (from, addDays(today, DateTime.sunday - wd + 1));
    case WhenFilter.next7:
      return (today, addDays(today, 7));
    case WhenFilter.date:
      final d = f.date;
      return d == null ? null : (dayOf(d), addDays(d, 1));
  }
}

final _haystack = Expando<String>('haystack');

String _searchText(Session s) =>
    _haystack[s] ??= normTitle('${s.title} ${s.director ?? ''} ${s.cycle ?? ''} ${s.cinema} ${s.section ?? ''}');

/// Aplica todos los filtros a una lista de pases (ya sin los pasados).
List<Session> applyFilters(List<Session> sessions, FilterState f, DateTime now) {
  final range = whenRange(f, now);
  final words = normTitle(f.query).split(' ').where((w) => w.isNotEmpty).toList();
  bool ok(Session s) {
    if (!f.showAcademics && s.academicsOnly) return false;
    if (f.excludedCinemas.contains(s.cinema)) return false;
    if (range != null && (s.start.isBefore(range.$1) || !s.start.isBefore(range.$2))) return false;
    if (f.bands.isNotEmpty && !f.bands.contains(bandOf(s.start))) return false;
    if (f.versions.isNotEmpty && !f.versions.contains(versionOf(s))) return false;
    if (f.onlySpecial && !s.isSpecial) return false;
    if (f.tags.isNotEmpty && !s.tags.any(f.tags.contains)) return false;
    final max = f.maxPrice;
    // Un pase sin precio publicado no se descarta: no sabemos lo que cuesta.
    if (max != null && s.priceEur != null && s.priceEur! > max + 0.001) return false;
    if (words.isNotEmpty) {
      final text = _searchText(s);
      if (!words.every(text.contains)) return false;
    }
    return true;
  }

  return sessions.where(ok).toList();
}

/// Una película con todos sus pases (agrupados por `filmKey`).
class Film {
  Film(this.key, List<Session> all)
      : sessions = all.toList()..sort((a, b) => a.start.compareTo(b.start)) {
    final titles = <String, int>{};
    final cin = <String>{}, ver = <String>{}, tags = <String>{}, cyc = <String>{};
    for (final s in sessions) {
      titles[s.title] = (titles[s.title] ?? 0) + 1;
      cin.add(s.cinema);
      if (s.version != null && s.version!.isNotEmpty) ver.add(s.version!);
      tags.addAll(s.tags.where(Session.specialTags.contains));
      final c = s.cycle?.trim();
      if (c != null && c.isNotEmpty) cyc.add(c);
      poster ??= (s.poster != null && s.poster!.isNotEmpty) ? s.poster : null;
      director ??= s.director;
      year ??= s.year;
      durationMin ??= s.durationMin;
    }
    title = (titles.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    cinemas = cin.toList();
    const order = ['VOSE', 'VO', 'ES', 'DOBLADA'];
    versions = ver.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    specialTags = sortTags(tags);
    cycles = cyc.toList();
    specialCount = sessions.where((s) => s.isSpecial).length;
  }

  final String key;
  final List<Session> sessions; // por hora de inicio
  late final String title;
  String? poster;
  String? director;
  int? year;
  int? durationMin;
  late final List<String> cinemas;
  late final List<String> versions;
  late final List<String> specialTags;
  late final List<String> cycles;
  late final int specialCount;

  Session get next => sessions.first;
  bool get hasSpecial => specialCount > 0;
}

List<Film> groupFilms(Iterable<Session> sessions, [CatalogSort sort = CatalogSort.specialFirst]) {
  final map = <String, List<Session>>{};
  for (final s in sessions) {
    (map[s.filmKey] ??= []).add(s);
  }
  final films = [for (final e in map.entries) Film(e.key, e.value)];
  int byNext(Film a, Film b) {
    final r = a.next.start.compareTo(b.next.start);
    return r != 0 ? r : a.key.compareTo(b.key);
  }

  switch (sort) {
    case CatalogSort.specialFirst:
      films.sort((a, b) {
        if (a.hasSpecial != b.hasSpecial) return a.hasSpecial ? -1 : 1;
        return byNext(a, b);
      });
    case CatalogSort.nextSession:
      films.sort(byNext);
    case CatalogSort.alphabetical:
      films.sort((a, b) => a.key.compareTo(b.key));
    case CatalogSort.mostSessions:
      films.sort((a, b) {
        final r = b.sessions.length.compareTo(a.sessions.length);
        return r != 0 ? r : a.key.compareTo(b.key);
      });
  }
  return films;
}

class DayGroup {
  DayGroup(this.day) : sessions = [];
  final DateTime day;
  final List<Session> sessions;
}

/// Agrupa por día pases ya ordenados por hora.
List<DayGroup> groupByDay(Iterable<Session> sessions) {
  final out = <DayGroup>[];
  for (final s in sessions) {
    final d = dayOf(s.start);
    if (out.isEmpty || out.last.day != d) out.add(DayGroup(d));
    out.last.sessions.add(s);
  }
  return out;
}

/// Un filtro activo, con su texto y el estado que queda al quitarlo.
class ActiveFilter {
  const ActiveFilter(this.label, this.without);
  final String label;
  final FilterState without;
}

Set<T> _minus<T>(Set<T> set, T v) => {...set}..remove(v);

/// Resumen de los filtros activos (para los chips quitables y el contador).
List<ActiveFilter> activeFilters(FilterState f, {Iterable<String> allCinemas = const []}) {
  final out = <ActiveFilter>[];
  if (f.query.trim().isNotEmpty) {
    out.add(ActiveFilter('«${f.query.trim()}»', f.copyWith(query: '')));
  }
  if (f.when != WhenFilter.all) {
    final label = switch (f.when) {
      WhenFilter.weekend => 'Este fin de semana',
      WhenFilter.date => f.date == null ? 'Un día' : capitalize(fmtDate(f.date!)),
      _ => whenLabel(f.when),
    };
    out.add(ActiveFilter(label, f.copyWith(when: WhenFilter.all, date: null)));
  }
  for (final b in TimeBand.values.where(f.bands.contains)) {
    out.add(ActiveFilter('Por la ${bandLabel(b).toLowerCase()}', f.copyWith(bands: _minus(f.bands, b))));
  }
  if (f.onlySpecial) out.add(ActiveFilter('Solo especiales', f.copyWith(onlySpecial: false)));
  for (final t in sortTags(f.tags)) {
    out.add(ActiveFilter(capitalize(t), f.copyWith(tags: _minus(f.tags, t))));
  }
  for (final v in VersionFilter.values.where(f.versions.contains)) {
    out.add(ActiveFilter(versionFilterLabel(v), f.copyWith(versions: _minus(f.versions, v))));
  }
  final all = allCinemas.toSet();
  final excluded = all.isEmpty ? f.excludedCinemas : f.excludedCinemas.intersection(all);
  if (excluded.isNotEmpty) {
    final kept = all.difference(excluded);
    final label = kept.length == 1
        ? kept.first
        : all.isEmpty
            ? '${excluded.length} cines ocultos'
            : 'Cines: ${kept.length} de ${all.length}';
    out.add(ActiveFilter(label, f.copyWith(excludedCinemas: const {})));
  }
  if (f.maxPrice != null) {
    final p = f.maxPrice!;
    out.add(ActiveFilter(p <= 0 ? 'Gratis' : 'Hasta ${fmtPrice(p)}', f.copyWith(maxPrice: null)));
  }
  if (f.showAcademics) {
    out.add(ActiveFilter('Con pases de académicos', f.copyWith(showAcademics: false)));
  }
  return out;
}
