import 'model.dart';

// Etiqueta cada pase con lo que le importa a un cinéfilo (port de cartelera/classify.py).
final _rules = <(String, RegExp)>[
  ('coloquio', RegExp(r'coloquio|encuentro con|q ?& ?a|debate')),
  ('presentación', RegExp(r'presentaci[oó]n|presentad[ao] por|con la presencia')),
  ('preestreno', RegExp(r'pre-?estreno|avant-?premi')),
  ('música en directo', RegExp(r'm[uú]sica en directo|en vivo|live score|cine-?concierto')),
  ('35 mm', RegExp(r'\b35 ?mm\b')),
  ('70 mm', RegExp(r'\b70 ?mm\b')),
  ('restaurada', RegExp(r'restaurad|remaster|\b4k\b|nueva copia')),
  ('festival', RegExp(
      r'festival|queercinemad|rizoma|m[aá]rgenes|documenta|animario|alcine|semana de cine|muestra|cine por mujeres|another way')),
  ('pase especial', RegExp(r'pase especial|pases especiales|sesi[oó]n especial|evento|proyecci[oó]n especial')),
  ('clásico', RegExp(r'siempre cl[aá]sicos|cl[aá]sicos|domingo de cl[aá]sicos|retrospectiva|imprescindibles')),
];

const classicAge = 15; // una película de 2011 proyectada en 2026 cuenta como reestreno

Session classify(Session s) {
  final hay = [s.rawTitle, s.title, s.note, s.cycle, s.section].whereType<String>().join(' ').toLowerCase();
  final tags = <String>{...s.tags};
  for (final (tag, pat) in _rules) {
    if (pat.hasMatch(hay)) tags.add(tag);
  }
  if (s.year != null && DateTime.now().year - s.year! >= classicAge) tags.add('reestreno');
  if (s.cycle != null && s.cycle!.trim().isNotEmpty) tags.add('ciclo');
  s.tags = tags.toList();
  return s;
}
