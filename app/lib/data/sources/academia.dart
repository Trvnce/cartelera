import '../model.dart';
import '../net.dart';
import '../text.dart';
import 'source.dart';

/// Academia de Cine: actividades del mes; muchas «solo para académicos» (se marcan).
const _url = 'https://www.academiadecine.com/actividades/';

final academia = Source(
  id: 'academia',
  name: 'Academia de Cine',
  url: _url,
  fetch: (Net net) async {
    final doc = parseHtml(await net.getText(_url));
    final t = today();
    final out = <Session>[];
    for (final act in doc.querySelectorAll('.listadoActividades-actividad')) {
      final f = txt(act.querySelector('.listadoActividades-actividad-fecha'));
      final name = txt(act.querySelector('.listadoActividades-actividad-nombre'));
      final m = RegExp(r'(\d{1,2})/(\p{L}+)\D+(\d{1,2}:\d{2})', unicode: true).firstMatch(f);
      final mm = m == null ? null : monthOf(m.group(2)!);
      if (name.isEmpty || m == null || mm == null) continue;
      final dd = int.parse(m.group(1)!);
      final d = DateTime(inferYear(mm, dd), mm, dd);
      if (d.isBefore(t)) continue;
      final sub = txt(act.querySelector('.listadoActividades-actividad-subtitulo'));
      final exclusive = sub.toLowerCase().contains('exclusiv');
      final link = act.querySelector('a.listadoActividades-actividad-enlace')?.attributes['href'];
      out.add(Session(
        source: 'academia',
        cinema: 'Academia de Cine',
        title: name,
        start: at(d, m.group(3)!),
        room: 'Sala de proyecciones',
        tags: exclusive ? ['solo académicos'] : [],
        note: exclusive || sub.isEmpty ? null : sub,
        ticketUrl: exclusive ? null : link,
        infoUrl: link,
        poster: act.querySelector('.listadoActividades-actividad-imagen img')?.attributes['src'],
      ));
    }
    return out;
  },
);
