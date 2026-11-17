import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Filmoteca Española — Cine Doré. Tienda sacatuentrada: pases a la venta (~3 días vista)
/// con fecha, hora, sala y ciclo.
const _url = 'https://entradasfilmoteca.sacatuentrada.es/es';

final filmoteca = Source(
  id: 'filmoteca',
  name: 'Cine Doré (Filmoteca)',
  url: 'https://www.cultura.gob.es/cultura/areas/cine/mc/fe/programacion-actividades/proyecciones.html',
  fetch: (Net net) async {
    final doc = parseHtml(await net.getText(_url));
    final out = <Session>[];
    for (final card in doc.querySelectorAll('div[data-fecha]')) {
      final titleEl = card.querySelector('h2.titulo');
      final desc = txt(card.querySelector('.descripcion'));
      final m = RegExp(r'a las (\d{1,2}[:.]\d{2})\s*h\s*\((Sala\s*\d+)?\.?\s*([^)]*)\)', caseSensitive: false)
          .firstMatch(desc);
      if (titleEl == null || m == null) continue;
      final raw = txt(titleEl);
      final ym = RegExp(r'\((\d{4})\)\s*$').firstMatch(raw);
      final title = ym != null ? clean(raw.substring(0, ym.start)) : raw;
      final d = DateTime.parse(card.attributes['data-fecha']!);
      final cat = txt(card.querySelector('.categoria p'));
      final cycle = cat.isNotEmpty ? cat : clean(m.group(3));
      final links = card.querySelectorAll('.enlaces a');
      final buy = links.where((a) => !(a.classes.contains('mas-info'))).firstOrNull;
      final info = card.querySelector('a.mas-info');
      final img = card.querySelector('.imagen img');
      var poster = img?.attributes['data-src'] ?? img?.attributes['src'];
      if (poster != null && poster.contains('no_image')) poster = null;
      out.add(Session(
        source: 'filmoteca',
        cinema: 'Cine Doré (Filmoteca)',
        title: title,
        rawTitle: raw,
        start: at(d, m.group(1)!),
        room: m.group(2) != null ? clean(m.group(2)) : null,
        year: ym != null ? int.parse(ym.group(1)!) : null,
        director: txt(card.querySelector('h3.subtitulo')).isEmpty ? null : txt(card.querySelector('h3.subtitulo')),
        cycle: cycle.isEmpty ? null : tidyTitle(cycle.toUpperCase()),
        priceEur: 3.0,
        priceNote: 'Tarifa general del Doré (hay reducida y bonos)',
        ticketUrl: clean(buy?.attributes['href']),
        infoUrl: clean(info?.attributes['href']),
        note: 'Si sale agotado en web, quedan entradas del día en taquilla (17–20 h)',
        poster: poster,
      ));
    }
    return out;
  },
);
