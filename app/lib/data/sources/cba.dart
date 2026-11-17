import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Cine Estudio del Círculo de Bellas Artes: dos semanas de cartelera en HTML.
const _url = 'https://www.circulobellasartes.com/cine-estudio/';
const _tickets = 'https://entradas.circulobellasartes.reservaentradas.com/';

final cba = Source(
  id: 'cba',
  name: 'Cine Estudio (Círculo de Bellas Artes)',
  url: _url,
  fetch: (Net net) async {
    final doc = parseHtml(await net.getText(_url));
    final t = today();
    final out = <Session>[];
    final seen = <String>{};
    for (final day in doc.querySelectorAll('.cba_cine_table_container')) {
      final m = RegExp(r'(\d{1,2})\s+(\p{L}+)', unicode: true).firstMatch(txt(day.querySelector('.cba_cine_table_dia')));
      final mm = m == null ? null : monthOf(m.group(2)!);
      if (m == null || mm == null) continue;
      final dd = int.parse(m.group(1)!);
      final d = DateTime(inferYear(mm, dd), mm, dd);
      if (d.isBefore(t)) continue;
      final cont = day.querySelector('.cba_cine_sesiones_container');
      if (cont == null) continue;
      final rows = <Map<String, String?>>[];
      Map<String, String?>? cur;
      for (final c in cont.children) {
        final cls = c.className;
        if (cls.contains('table_hora')) {
          cur = {'hora': txt(c)};
          rows.add(cur);
        } else if (cur == null) {
          continue;
        } else if (cls.contains('table_titulo')) {
          final a = c.querySelector('a');
          cur['title'] = a != null ? txt(a) : txt(c);
          cur['url'] = a?.attributes['href'];
          cur['director'] = a != null ? clean(txt(c).replaceFirst(txt(a), '')) : null;
        } else if (cls.contains('table_tipo')) {
          cur['tipo'] = txt(c);
        } else if (cls.contains('table_info')) {
          cur['info'] = txt(c);
        }
      }
      for (final r in rows) {
        if (r['title'] == null || !RegExp(r'^\d').hasMatch(r['hora'] ?? '')) continue;
        final tipo = r['tipo'] ?? '', info = r['info'] ?? '';
        final estreno = tipo.toLowerCase().startsWith('estreno');
        var pnote = estreno ? 'Estreno' : 'Ciclo';
        if (info.toLowerCase().contains('reducido')) pnote += ' · precio reducido en este pase (importe sin publicar)';
        final (title, namedCycle) = splitCycle(r['title']!);
        final s = Session(
          source: 'cba',
          cinema: 'Cine Estudio (Círculo de Bellas Artes)',
          title: title,
          rawTitle: r['title'],
          start: at(d, r['hora']!),
          room: 'Sala única',
          director: (r['director'] ?? '').isEmpty ? null : r['director'],
          cycle: namedCycle ?? (estreno ? null : 'Ciclo'),
          tags: estreno ? ['estreno'] : [],
          note: info.isEmpty ? null : info,
          priceEur: estreno ? 8.0 : 5.5,
          priceNote: pnote,
          ticketUrl: _tickets,
          infoUrl: r['url'],
        );
        if (seen.add(s.key)) out.add(s);
      }
    }
    return out;
  },
);
