import 'package:html/dom.dart';

import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Renoir Madrid (Princesa, Retiro, Plaza de España): /cine/{cine}/cartelera/?fecha=…,
/// con sala, versión y etiquetas. Precio según su tarifa online publicada.
const _base = 'https://www.cinesrenoir.com';
const _cinemas = {
  'cines-princesa': 'Cines Princesa (Renoir)',
  'renoir-retiro': 'Renoir Retiro',
  'renoir-plaza-de-espana': 'Renoir Plaza de España',
};

(double, String) _price(DateTime s) {
  final wd = s.weekday; // 1 = lunes
  if (wd == 1 || wd == 3) return (5.40, 'Día del espectador (tarifa online)');
  if (wd == 2 || wd == 4) return (8.40, 'Laborable (tarifa online)');
  return (9.70, 'Fin de semana (tarifa online)');
}

List<Session> _parseDay(Document doc, String slug, DateTime d) {
  final out = <Session>[];
  for (final block in doc.querySelectorAll('div.my-account-content.d-lg-block')) {
    final a = block.querySelectorAll('.col-4 a').where((x) => (x.attributes['href'] ?? '').startsWith('/pelicula/')).firstOrNull;
    if (a == null) continue;
    final raw = txt(a);
    final cm = RegExp(r'\[([^\]]+)\]').firstMatch(raw);
    final title = tidyTitle(clean(raw.replaceAll(RegExp(r'\[[^\]]*\]'), '')));
    final smalls = block.querySelectorAll('.col-4 small').map(txt).toList();
    String? director = smalls.where((s) => s.toLowerCase().startsWith('de ')).map((s) => s.substring(3)).firstOrNull;
    if (director != null && director.contains(',')) {
      final p = director.split(',');
      director = '${clean(p.sublist(1).join(','))} ${clean(p[0])}';
    }
    final versionTxt = smalls.where((s) => s.toLowerCase().contains('versi')).firstOrNull;
    final dur = smalls.map((s) => RegExp(r'Duraci.n (\d+)').firstMatch(s)).whereType<RegExpMatch>().map((m) => int.parse(m.group(1)!)).firstOrNull;
    final img = block.querySelector('img');
    for (final pase in block.querySelectorAll('div.pase-cartelera')) {
      final t = pase.querySelectorAll('a').where((x) =>
          x.classes.contains('btn-evento') || x.classes.contains('btn-primary') || (x.attributes['href'] ?? '').contains('pillalas.com/pase')).firstOrNull;
      if (t == null) continue;
      final sala = txt(pase.querySelector('span'));
      final tags = pase.querySelectorAll('.pase-cartelera-tag').map(txt)
          .where((x) => cm == null || x.toLowerCase() != cm.group(1)!.toLowerCase()).toList();
      final start = at(d, txt(t));
      final (price, pnote) = _price(start);
      out.add(Session(
        source: 'renoir',
        cinema: _cinemas[slug]!,
        title: title,
        rawTitle: raw,
        start: start,
        room: sala.isEmpty ? null : sala[0].toUpperCase() + sala.substring(1),
        version: detectVersion([versionTxt]),
        director: director,
        durationMin: dur,
        cycle: cm != null ? capWords(cm.group(1)!) : null,
        note: tags.isEmpty ? null : tags.join(' · '),
        priceEur: price,
        priceNote: pnote,
        ticketUrl: t.attributes['href'],
        infoUrl: absUrl(_base, a.attributes['href']),
        poster: absUrl(_base, img?.attributes['src']),
      ));
    }
  }
  return out;
}

final renoir = Source(
  id: 'renoir',
  name: 'Renoir (Princesa, Retiro, Pza. España)',
  url: '$_base/',
  fetch: (Net net) async {
    final out = <Session>[];
    for (final slug in _cinemas.keys) {
      final firstHtml = await net.getText('$_base/cine/$slug/cartelera/');
      final dates = RegExp(r'cartelera/\?fecha=(\d{4}-\d{2}-\d{2})').allMatches(firstHtml).map((m) => m.group(1)!).toSet().toList()..sort();
      final t = today();
      if (dates.isEmpty) dates.add(t.toIso8601String().substring(0, 10));
      for (final ds in dates) {
        final d = DateTime.parse(ds);
        final html = d == t ? firstHtml : await net.getText('$_base/cine/$slug/cartelera/?fecha=$ds');
        out.addAll(_parseDay(parseHtml(html), slug, d));
      }
    }
    return out;
  },
);
