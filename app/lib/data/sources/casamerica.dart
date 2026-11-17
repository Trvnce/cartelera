import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Casa de América — Sala Iberia: /cine y la ficha («Fecha y hora: Miércoles 25 de
/// noviembre de 2026. ⌚ 18:00.»), ciclo, director, año, duración, entrada libre.
const _base = 'https://www.casamerica.es';
final _date = RegExp(r'(\d{1,2})\s+de\s+(\p{L}+)(?:\s+de\s+(\d{4}))?', caseSensitive: false, unicode: true);

DateTime? _firstDate(String text) {
  for (final m in _date.allMatches(text)) {
    final mon = monthOf(m.group(2)!);
    if (mon == null) continue;
    final day = int.parse(m.group(1)!);
    final year = m.group(3) != null ? int.parse(m.group(3)!) : inferYear(mon, day);
    return DateTime(year, mon, day);
  }
  return null;
}

final casamerica = Source(
  id: 'casamerica',
  name: 'Casa de América (Sala Iberia)',
  url: '$_base/cine',
  fetch: (Net net) async {
    final t = today();
    final doc = parseHtml(await net.getText('$_base/cine'));
    final out = <Session>[];
    final seen = <String>{};
    for (final card in doc.querySelectorAll('article.card')) {
      final a = card.querySelector('.card-title a') ?? card.querySelector('h3 a');
      final href = a?.attributes['href'];
      if (a == null || href == null || !seen.add(href)) continue;
      final summary = txt(card);
      final d0 = _firstDate(summary);
      if (d0 != null && d0.isBefore(t) && !summary.toLowerCase().contains('del ')) continue;
      final url = absUrl(_base, href)!;
      final page = parseHtml(await net.getText(url));
      final text = txt(page.querySelector('main') ?? page.body);
      final fm = RegExp(r'Fecha y hora:?(.{0,160})').firstMatch(text);
      if (fm == null) continue;
      final d = _firstDate(fm.group(1)!);
      final tm = RegExp(r'(\d{1,2}[:.]\d{2})').firstMatch(fm.group(1)!);
      if (d == null || tm == null || d.isBefore(t)) continue;
      final title = txt(a);
      final cm = RegExp('${RegExp.escape(title)}\\s+(.{3,90}?)\\s+Proyecci').firstMatch(text);
      final meta = RegExp(r"([\p{L} ,]+),\s*((?:19|20)\d{2})\s*/\s*(\d+)\s*['’]", unicode: true).firstMatch(text);
      final dm = RegExp(r'Director(?:a|es)?:\s*([^:]{3,80}?)\s+(?:Guion|Int[eé]rpretes|Sinopsis|Reparto)').firstMatch(text);
      final free = RegExp(r'entrada (libre|gratuita)', caseSensitive: false).hasMatch(text);
      out.add(Session(
        source: 'casamerica',
        cinema: 'Casa de América (Sala Iberia)',
        title: title,
        start: at(d, tm.group(1)!),
        room: 'Sala Iberia',
        year: meta != null ? int.parse(meta.group(2)!) : null,
        durationMin: meta != null ? int.parse(meta.group(3)!) : null,
        director: dm != null ? clean(dm.group(1)).replaceAll(RegExp(r'\.$'), '') : null,
        cycle: cm != null ? clean(cm.group(1)) : null,
        note: free ? 'Entrada libre hasta completar aforo; se reparte en taquilla una hora antes' : null,
        priceEur: free ? 0.0 : null,
        priceNote: free ? 'Gratis' : null,
        ticketUrl: url,
        infoUrl: url,
        poster: absUrl(_base, card.querySelector('img')?.attributes['src']),
      ));
    }
    return out;
  },
);
