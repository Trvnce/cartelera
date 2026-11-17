import 'package:html/dom.dart';

import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Cines sin lector propio, desde eCartelera (su robots.txt permite /cines/): una página
/// por cine y día con película, cartel, director, país y pases (hora, formato, compra).
/// `vo`: sala de versión original; si el pase no trae formato, VOSE para películas no
/// españolas y «ES» para españolas.
///
/// Medido el 17-11-2026: eCartelera NO tiene sesiones de Pequeño Cine Estudio, Berlanga,
/// Equis, Casa de América, Casa de México, Artistic, Arapiles, Palacio de la Prensa,
/// Callao, Capitol ni Zoco Majadahonda.
const _base = 'https://www.ecartelera.com/cines/';
const _daysAhead = 10;
const _cinemas = <String, (String, bool)>{
  '40,0,1.html': ('mk2 Cine Paz', true),
  '54,0,1.html': ('Yelmo Cines Ideal', true),
  '53,0,1.html': ('Cinesa Príncipe Pío', false),
  'dreams-cinema-palacio-hielo/': ('mk2 Palacio de Hielo', false),
  '471,0,1.html': ('mk2 Cinesur Luz del Tajo (Toledo)', false),
};
const _weekdays = {'lunes': 1, 'martes': 2, 'miercoles': 3, 'miércoles': 3, 'jueves': 4, 'viernes': 5, 'sabado': 6, 'sábado': 6, 'domingo': 7};

DateTime? _dateFromLabel(String label, DateTime t) {
  final m = RegExp(r'(\d{1,2})\s*$').firstMatch(label.trim());
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  for (var i = 0; i < 45; i++) {
    final d = t.add(Duration(days: i));
    if (d.day == day) return d;
  }
  return null;
}

(double?, Map<int, double>) _prices(Document doc) {
  double? general;
  final reduced = <int, double>{};
  for (final p in doc.querySelectorAll('p.crow')) {
    final s = txt(p).toLowerCase();
    final nums = RegExp(r'(\d+[,.]\d{1,2})\s*(?:euros|€)').allMatches(s).map((m) => double.parse(m.group(1)!.replaceAll(',', '.'))).toList();
    if (nums.isEmpty) continue;
    if (s.startsWith('precios') && general == null) {
      general = nums.first;
    } else if (s.startsWith('reducidos')) {
      _weekdays.forEach((k, v) {
        if (s.contains(k)) reduced[v] = nums.first;
      });
    }
  }
  return (general, reduced);
}

List<Session> _parse(Document doc, String name, bool vo, DateTime d, (double?, Map<int, double>) prices) {
  final (general, reduced) = prices;
  final out = <Session>[];
  for (final it in doc.querySelectorAll('div.titem')) {
    final a = it.querySelector('.tit a');
    if (a == null) continue;
    final raw = txt(a);
    final (title, cycle) = splitCycle(stripVersion(raw));
    final data = it.querySelectorAll('p.data span').map(txt).toList();
    final dur = data.where((x) => RegExp(r'^\d+ min').hasMatch(x)).map(firstInt).firstOrNull;
    final country = data.where((x) => !RegExp(r'^\d').hasMatch(x)).firstOrNull;
    final director = it.querySelectorAll('p.dir a').map(txt).join(', ');
    final img = it.querySelector('.tposter img')?.attributes['src'];
    for (final s in it.querySelectorAll('.sessions a')) {
      final time = s.attributes['data-session-time'];
      if (time == null) continue;
      final fmt = clean(s.attributes['data-session-format']);
      var version = detectVersion([fmt, raw]);
      if (version == null && vo && country != null) version = country.toLowerCase() == 'españa' ? 'ES' : 'VOSE';
      final start = at(d, time);
      final price = reduced[start.weekday] ?? general;
      out.add(Session(
        source: 'ecartelera',
        cinema: name,
        title: title,
        rawTitle: raw,
        start: start,
        version: version,
        director: director.isEmpty ? null : director,
        durationMin: dur,
        cycle: cycle,
        tags: fmt.isNotEmpty && detectVersion([fmt]) == null && !const ['2d', 'digital'].contains(fmt.toLowerCase()) ? [fmt] : [],
        priceEur: price,
        priceNote: price == null ? null : 'Tarifa publicada en eCartelera${reduced.containsKey(start.weekday) ? ' (día reducido)' : ''}',
        ticketUrl: s.attributes['href'],
        infoUrl: a.attributes['href'],
        poster: img,
      ));
    }
  }
  return out;
}

final ecartelera = Source(
  id: 'ecartelera',
  name: 'vía eCartelera: Paz, Yelmo Ideal, Príncipe Pío, Palacio de Hielo, Toledo',
  url: '${_base}0,30,1.html',
  fetch: (Net net) async {
    final t = today();
    final out = <Session>[];
    final errors = <String>[];
    for (final e in _cinemas.entries) {
      final url = _base + e.key;
      final (name, vo) = e.value;
      try {
        final doc = parseHtml(await net.getText(url));
        final prices = _prices(doc);
        final days = <(DateTime, String)>[];
        for (final a in doc.querySelectorAll('ul.days a')) {
          final d = _dateFromLabel(a.attributes['title'] ?? a.text, t);
          final href = a.attributes['href'];
          if (d != null && href != null && !d.isAfter(t.add(const Duration(days: _daysAhead)))) days.add((d, href));
        }
        if (days.isEmpty) days.add((t, url));
        for (final (d, href) in days) {
          final page = href.replaceAll(RegExp(r'/$'), '') == url.replaceAll(RegExp(r'/$'), '') ? doc : parseHtml(await net.getText(href));
          out.addAll(_parse(page, name, vo, d, prices));
        }
      } catch (err) {
        errors.add('$name: $err');
      }
    }
    if (out.isEmpty && errors.isNotEmpty) throw Exception(errors.join('; '));
    return out;
  },
);
