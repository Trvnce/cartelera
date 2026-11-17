import '../../data/model.dart';

/// Grupos con los que se ordena la lista de cines en los filtros.
enum CinemaGroup { arthouse, original, chains, outside, other }

String cinemaGroupLabel(CinemaGroup g) => switch (g) {
      CinemaGroup.arthouse => 'Filmotecas y salas de autor',
      CinemaGroup.original => 'Cines de estreno en V.O.',
      CinemaGroup.chains => 'Cadenas y multisalas',
      CinemaGroup.outside => 'Fuera de Madrid',
      CinemaGroup.other => 'Otros',
    };

// Tabla simple: palabra clave (ya normalizada) → grupo. Gana la primera que aparezca.
const _table = <(String, CinemaGroup)>[
  ('toledo', CinemaGroup.outside),
  ('luz del tajo', CinemaGroup.outside),
  ('dore', CinemaGroup.arthouse),
  ('filmoteca', CinemaGroup.arthouse),
  ('cineteca', CinemaGroup.arthouse),
  ('circulo de bellas artes', CinemaGroup.arthouse),
  ('cine estudio', CinemaGroup.arthouse),
  ('academia', CinemaGroup.arthouse),
  ('berlanga', CinemaGroup.arthouse),
  ('equis', CinemaGroup.arthouse),
  ('casa de america', CinemaGroup.arthouse),
  ('artistic metropol', CinemaGroup.arthouse),
  ('renoir', CinemaGroup.original),
  ('princesa', CinemaGroup.original),
  ('golem', CinemaGroup.original),
  ('verdi', CinemaGroup.original),
  ('embajadores', CinemaGroup.original),
  ('cine paz', CinemaGroup.original),
  ('conde duque', CinemaGroup.original),
  ('yelmo', CinemaGroup.chains),
  ('cinesa', CinemaGroup.chains),
  ('mk2', CinemaGroup.chains),
  ('kinepolis', CinemaGroup.chains),
  ('ocine', CinemaGroup.chains),
  ('callao', CinemaGroup.chains),
  ('capitol', CinemaGroup.chains),
];

CinemaGroup cinemaGroupOf(String cinema) {
  final n = normTitle(cinema);
  for (final (key, group) in _table) {
    if (n.contains(key)) return group;
  }
  return CinemaGroup.other;
}

/// Cines agrupados y ordenados alfabéticamente; solo grupos con algún cine.
Map<CinemaGroup, List<String>> groupCinemas(Iterable<String> cinemas) {
  final out = <CinemaGroup, List<String>>{};
  for (final g in CinemaGroup.values) {
    final list = cinemas.where((c) => cinemaGroupOf(c) == g).toList()
      ..sort((a, b) => normTitle(a).compareTo(normTitle(b)));
    if (list.isNotEmpty) out[g] = list;
  }
  return out;
}
