import 'package:html/dom.dart';

import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Golem Madrid: /golem/golem-madrid (hoy) y /AAAAMMDD. No publica sala.
const _base = 'https://www.golem.es';
const _url = '$_base/golem/golem-madrid';

(double, String) _price(DateTime s) {
  final wd = s.weekday;
  if (wd == 1 || wd == 3) return (5.90, 'Día del espectador');
  if (wd >= 6) {
    if (wd == 7 && s.hour >= 22) return (6.90, 'Última sesión del domingo');
    return (9.50, 'Fin de semana');
  }
  if (s.hour < 17) return (6.90, 'Primera sesión laborable');
  return (8.30, 'Laborable');
}

List<Session> _parseDay(Document doc, DateTime d) {
  final out = <Session>[];
  for (final a in doc.querySelectorAll('a.txtNegXXL')) {
    Element? box = a.parent;
    while (box != null && !(box.localName == 'table' && box.attributes['background'] == '#AEAEAE')) {
      box = box.parent;
    }
    if (box == null) continue;
    final raw = txt(a);
    final (title, cycle) = splitCycle(stripVersion(raw));
    final img = box.querySelector('img.bordeCartel');
    final fmt = box.querySelectorAll('img').map((i) => i.attributes['alt'] ?? '').where((x) => x == '35mm' || x == '70mm').toList();
    for (final t in box.querySelectorAll('a.horaXXXL')) {
      final start = at(d, txt(t));
      final (price, pnote) = _price(start);
      out.add(Session(
        source: 'golem',
        cinema: 'Golem Madrid',
        title: title,
        rawTitle: raw,
        start: start,
        version: detectVersion([raw]),
        cycle: cycle,
        tags: fmt.map((f) => f.replaceAll('mm', ' mm')).toList(),
        priceEur: price,
        priceNote: pnote,
        ticketUrl: absUrl(_base, t.attributes['href']),
        infoUrl: absUrl(_base, a.attributes['href']),
        poster: absUrl(_base, img?.attributes['src']),
      ));
    }
  }
  return out;
}

final golem = Source(
  id: 'golem',
  name: 'Golem Madrid',
  url: _url,
  fetch: (Net net) async {
    final first = await net.getText(_url);
    final t = today();
    final out = _parseDay(parseHtml(first), t);
    final days = RegExp(r'golem-madrid/(\d{8})').allMatches(first).map((m) => m.group(1)!).toSet().toList()..sort();
    for (final ds in days) {
      final d = DateTime(int.parse(ds.substring(0, 4)), int.parse(ds.substring(4, 6)), int.parse(ds.substring(6)));
      if (d != t) out.addAll(_parseDay(parseHtml(await net.getText('$_url/$ds')), d));
    }
    return out;
  },
);
