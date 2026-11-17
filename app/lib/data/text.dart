// Utilidades de texto y fechas compartidas por los lectores (port de cartelera/text.py).

const months = {
  'ene': 1, 'enero': 1, 'feb': 2, 'febrero': 2, 'mar': 3, 'marzo': 3, 'abr': 4, 'abril': 4,
  'may': 5, 'mayo': 5, 'jun': 6, 'junio': 6, 'jul': 7, 'julio': 7, 'ago': 8, 'agosto': 8,
  'sep': 9, 'sept': 9, 'septiembre': 9, 'oct': 10, 'octubre': 10, 'nov': 11, 'noviembre': 11,
  'dic': 12, 'diciembre': 12,
};

int? monthOf(String s) {
  final k = s.toLowerCase().trim();
  return months[k] ?? months[k.length >= 3 ? k.substring(0, 3) : k];
}

String clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Las carteleras no dan el año: el de hoy, salvo que la fecha quede muy atrás.
int inferYear(int month, int day, [DateTime? ref]) {
  final t = ref ?? today();
  var y = t.year;
  if (DateTime(y, month, day).difference(t).inDays < -60) y += 1;
  return y;
}

/// Fecha + «20:15» / «20.15» / «20:15h».
DateTime at(DateTime d, String hhmm) {
  final m = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(hhmm);
  if (m == null) throw FormatException('Hora no válida: $hhmm');
  return DateTime(d.year, d.month, d.day, int.parse(m.group(1)!), int.parse(m.group(2)!));
}

final _versionPatterns = <(String, RegExp)>[
  ('VOSE', RegExp(r'v\.?\s?o\.?\s?s\.?\s?e|vose|subtitulad|sub\.?\s*castellano|v\.o\.\s*sub', caseSensitive: false)),
  ('DOBLADA', RegExp(r'doblad|\bv\.?\s?e\.?(?=\W|$)|\(cast\)', caseSensitive: false)),
  ('ES', RegExp(r'versi[oó]n original castellano|original en castellano', caseSensitive: false)),
  ('VO', RegExp(r'\bv\.?\s?o\.?(?!\s*s)(?=\W|$)|versi[oó]n original', caseSensitive: false)),
];

String? detectVersion(List<String?> texts) {
  final t = texts.whereType<String>().join(' ').toLowerCase();
  for (final (code, pat) in _versionPatterns) {
    if (pat.hasMatch(t)) return code;
  }
  return null;
}

/// Quita «(VOSE)», «(V.O.S.E.)», «(DOBLADA AL ESPAÑOL)», «(OCAP)»… del título.
String stripVersion(String title) => clean(title.replaceAll(
    RegExp(r'\s*[\(\[](v\.?\s?o\.?\s?s?\.?\s?e?\.?|vose|vos|vo|doblada[^)\]]*|ocap|cast|v\.e\.)[\)\]]\s*', caseSensitive: false),
    ' '));

/// «EL PRECIO DE LA RED» → «El precio de la red» (solo títulos enteros en mayúsculas).
String tidyTitle(String t) {
  final letters = t.runes.map(String.fromCharCode).where((c) => c.toLowerCase() != c.toUpperCase()).toList();
  if (letters.isEmpty || letters.any((c) => c != c.toUpperCase())) return t;
  final s = t.toLowerCase();
  return s.replaceAllMapped(RegExp(r'(^|[.:¿¡!?]\s+|\(\s*)(\p{L})', unicode: true),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}');
}

/// «festival rizoma» → «Festival Rizoma».
String capWords(String s) => s
    .toLowerCase()
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

final _cyclePrefix = RegExp(
    r'cl[aá]sicos|ciclo|festival|cinemad|muestra|semana|domingo|jueves|noche|retrospectiva|homenaje|especial|foro|filmoteca|documenta|rizoma|m[aá]rgenes',
    caseSensitive: false);

/// «Domingo de clásicos: Alien» → («Alien», «Domingo de clásicos»).
(String, String?) splitCycle(String title) {
  final i = title.indexOf(':');
  if (i < 0) return (title, null);
  final pre = clean(title.substring(0, i));
  final post = clean(title.substring(i + 1));
  if (post.isNotEmpty && pre.length <= 45 && _cyclePrefix.hasMatch(pre)) return (post, pre);
  return (title, null);
}

/// Resuelve rutas relativas.
String? absUrl(String base, String? href) {
  if (href == null || href.trim().isEmpty) return null;
  return Uri.parse(base).resolve(href.trim()).toString();
}

final _num = RegExp(r'\d+');
int? firstInt(String? s) {
  final m = _num.firstMatch(s ?? '');
  return m == null ? null : int.parse(m.group(0)!);
}
