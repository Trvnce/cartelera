import 'dart:convert';

import '../format.dart';

enum WhenFilter { all, today, tomorrow, weekend, next7, date }

enum TimeBand { morning, afternoon, night }

enum VersionFilter { original, spanish, dubbed, unknown }

enum CatalogSort { specialFirst, nextSession, alphabetical, mostSessions }

const _unset = Object();

/// Estado completo de los filtros. Inmutable; se copia con [copyWith].
class FilterState {
  const FilterState({
    this.query = '',
    this.when = WhenFilter.all,
    this.date,
    this.bands = const {},
    this.excludedCinemas = const {},
    this.versions = const {},
    this.onlySpecial = false,
    this.tags = const {},
    this.maxPrice,
    this.showAcademics = false,
    this.sort = CatalogSort.specialFirst,
  });

  /// Texto libre (título, director, ciclo, cine). No se guarda entre sesiones.
  final String query;
  final WhenFilter when;

  /// Día concreto cuando [when] es [WhenFilter.date].
  final DateTime? date;

  /// Franjas horarias; vacío = todas.
  final Set<TimeBand> bands;

  /// Cines desmarcados. Se guardan los excluidos para que un cine nuevo aparezca solo.
  final Set<String> excludedCinemas;

  /// Versiones; vacío = todas.
  final Set<VersionFilter> versions;
  final bool onlySpecial;

  /// Etiquetas concretas (coloquio, 35 mm…); vacío = cualquiera.
  final Set<String> tags;

  /// Precio máximo en euros; null = sin límite.
  final double? maxPrice;
  final bool showAcademics;
  final CatalogSort sort;

  FilterState copyWith({
    String? query,
    WhenFilter? when,
    Object? date = _unset,
    Set<TimeBand>? bands,
    Set<String>? excludedCinemas,
    Set<VersionFilter>? versions,
    bool? onlySpecial,
    Set<String>? tags,
    Object? maxPrice = _unset,
    bool? showAcademics,
    CatalogSort? sort,
  }) =>
      FilterState(
        query: query ?? this.query,
        when: when ?? this.when,
        date: identical(date, _unset) ? this.date : date as DateTime?,
        bands: bands ?? this.bands,
        excludedCinemas: excludedCinemas ?? this.excludedCinemas,
        versions: versions ?? this.versions,
        onlySpecial: onlySpecial ?? this.onlySpecial,
        tags: tags ?? this.tags,
        maxPrice: identical(maxPrice, _unset) ? this.maxPrice : maxPrice as double?,
        showAcademics: showAcademics ?? this.showAcademics,
        sort: sort ?? this.sort,
      );

  /// Quita todos los filtros pero respeta la ordenación.
  FilterState cleared() => FilterState(sort: sort);

  Map<String, dynamic> toJson() => {
        'when': when.name,
        'date': date?.toIso8601String(),
        'bands': bands.map((b) => b.name).toList(),
        'excludedCinemas': excludedCinemas.toList(),
        'versions': versions.map((v) => v.name).toList(),
        'onlySpecial': onlySpecial,
        'tags': tags.toList(),
        'maxPrice': maxPrice,
        'showAcademics': showAcademics,
        'sort': sort.name,
      };

  String encode() => jsonEncode(toJson());

  static T? _byName<T extends Enum>(List<T> values, Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static Set<T> _enumSet<T extends Enum>(List<T> values, Object? raw) =>
      {for (final n in (raw as List? ?? const [])) _byName(values, n)}.whereType<T>().toSet();

  factory FilterState.fromJson(Map<String, dynamic> j) {
    final date = j['date'] is String ? DateTime.tryParse(j['date'] as String) : null;
    var when = _byName(WhenFilter.values, j['when']) ?? WhenFilter.all;
    if (when == WhenFilter.date && date == null) when = WhenFilter.all;
    return FilterState(
      when: when,
      date: date == null ? null : dayOf(date),
      bands: _enumSet(TimeBand.values, j['bands']),
      excludedCinemas: {...(j['excludedCinemas'] as List? ?? const []).whereType<String>()},
      versions: _enumSet(VersionFilter.values, j['versions']),
      onlySpecial: j['onlySpecial'] == true,
      tags: {...(j['tags'] as List? ?? const []).whereType<String>()},
      maxPrice: (j['maxPrice'] as num?)?.toDouble(),
      showAcademics: j['showAcademics'] == true,
      sort: _byName(CatalogSort.values, j['sort']) ?? CatalogSort.specialFirst,
    );
  }

  /// Nunca lanza: ante un JSON roto devuelve los filtros por defecto.
  static FilterState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const FilterState();
    try {
      return FilterState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const FilterState();
    }
  }
}

String whenLabel(WhenFilter w) => switch (w) {
      WhenFilter.all => 'Todo',
      WhenFilter.today => 'Hoy',
      WhenFilter.tomorrow => 'Mañana',
      WhenFilter.weekend => 'Fin de semana',
      WhenFilter.next7 => 'Próximos 7 días',
      WhenFilter.date => 'Un día',
    };

String bandLabel(TimeBand b) => switch (b) {
      TimeBand.morning => 'Mañana',
      TimeBand.afternoon => 'Tarde',
      TimeBand.night => 'Noche',
    };

String bandHint(TimeBand b) => switch (b) {
      TimeBand.morning => 'antes de las 15 h',
      TimeBand.afternoon => 'de 15 a 20 h',
      TimeBand.night => 'desde las 20 h',
    };

String versionFilterLabel(VersionFilter v) => switch (v) {
      VersionFilter.original => 'VOSE / V.O.',
      VersionFilter.spanish => 'V.O. castellano',
      VersionFilter.dubbed => 'Doblada',
      VersionFilter.unknown => 'Sin indicar',
    };

String sortLabel(CatalogSort s) => switch (s) {
      CatalogSort.specialFirst => 'Especiales primero',
      CatalogSort.nextSession => 'Próximo pase',
      CatalogSort.alphabetical => 'A–Z',
      CatalogSort.mostSessions => 'Más pases',
    };
