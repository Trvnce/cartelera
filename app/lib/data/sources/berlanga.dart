import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Sala Berlanga: su API de WordPress lista las actividades de cine (categoría 11) y cada
/// ficha trae «18 de Noviembre - 18:15h», si están agotadas, ciclo y datos.
const _api =
    'https://salaberlanga.com/wp-json/wp/v2/actividad?categoria-ciclo=11&per_page=40&orderby=modified&_fields=id,link,title,modified';
const _tickets = 'https://cine.entradas.com/cine/madrid/sala-berlanga/sesiones?showAllDates=true';
final _when = RegExp(r'(\d{1,2})\s+de\s+(\p{L}+)\s*-\s*(\d{1,2}[:.]\d{2})', caseSensitive: false, unicode: true);

final berlanga = Source(
  id: 'berlanga',
  name: 'Sala Berlanga',
  url: 'https://salaberlanga.com/programacion/',
  fetch: (Net net) async {
    final t = today();
    final out = <Session>[];
    for (final act in (await net.getJson(_api) as List).cast<Map<String, dynamic>>()) {
      final title = tidyTitle(txt(parseHtml((act['title'] as Map)['rendered'] as String).body));
      final link = act['link'] as String;
      final doc = parseHtml(await net.getText(link));
      final bar = doc.querySelector('.barra-nar-ficha');
      if (bar == null) continue;
      final barText = txt(bar);
      final soldOut = barText.toLowerCase().contains('agotad');
      final buy = bar.querySelectorAll('a').where((a) => (a.attributes['href'] ?? '').contains('entradas.com')).firstOrNull;
      final dataEl = doc.querySelector('.ficha-actividad-date');
      final fields = (dataEl?.text ?? '').split('|').map(clean).where((x) => x.isNotEmpty).toList();
      final year = fields.where((x) => RegExp(r'^(19|20)\d{2}$').hasMatch(x)).map(int.parse).firstOrNull;
      final dur = fields.map((x) => RegExp(r"^(\d+)\s*['’]$").firstMatch(x)).whereType<RegExpMatch>().map((m) => int.parse(m.group(1)!)).firstOrNull;
      final kind = fields.skip(1).where((x) =>
          RegExp(r'[a-z]').hasMatch(x) && !RegExp(r'^(V\.?O.*|VOSE|Castellano)$', caseSensitive: false).hasMatch(x)).firstOrNull;
      final cycle = txt(doc.querySelector('.ficha-actividad span a'));
      final og = doc.querySelector('meta[property="og:image"]')?.attributes['content'];
      for (final m in _when.allMatches(barText)) {
        final mon = monthOf(m.group(2)!);
        if (mon == null) continue;
        final day = int.parse(m.group(1)!);
        final d = DateTime(inferYear(mon, day), mon, day);
        if (d.isBefore(t)) continue;
        final note = [kind, if (soldOut) 'Entradas agotadas en web'].whereType<String>().join(' · ');
        out.add(Session(
          source: 'berlanga',
          cinema: 'Sala Berlanga',
          title: title,
          start: at(d, m.group(3)!),
          room: 'Sala única',
          version: detectVersion([fields.join(' ')]),
          year: year,
          durationMin: dur,
          cycle: cycle.isEmpty ? null : cycle,
          note: note.isEmpty ? null : note,
          ticketUrl: buy?.attributes['href'] ?? _tickets,
          infoUrl: link,
          poster: og,
        ));
      }
    }
    return out;
  },
);
